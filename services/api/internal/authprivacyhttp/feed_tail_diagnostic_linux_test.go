//go:build linux

package authprivacyhttp

import (
	"bytes"
	"context"
	"encoding/json"
	"fmt"
	"net/http"
	"net/http/httptrace"
	"os"
	"path/filepath"
	"runtime"
	"runtime/metrics"
	runtimetrace "runtime/trace"
	"strconv"
	"strings"
	"sync/atomic"
	"syscall"
	"testing"
	"time"

	"github.com/jackc/pgx/v5/pgxpool"
	"github.com/zhubaozhenshuai666-lang/HnuHole/services/api/internal/readtiming"
)

// This is a causal diagnostic, not an acceptance cohort. System counters are
// read outside the unchanged request interval. No request data, credentials,
// SQL arguments or per-request files are recorded.
var feedTailMetricNames = []string{
	"/gc/cycles/total:gc-cycles", "/gc/heap/allocs:bytes", "/gc/heap/live:bytes",
	"/cpu/classes/gc/mark/assist:cpu-seconds", "/cpu/classes/gc/pause:cpu-seconds",
	"/sched/goroutines:goroutines", "/sched/latencies:seconds", "/gc/pauses:seconds",
}

type feedTailHistogram struct {
	Counts  []uint64
	Buckets []float64
}
type feedTailSystem struct {
	Runtime                                                                            map[string]float64
	Histograms                                                                         map[string]feedTailHistogram
	Missing                                                                            []string
	UserUS, SystemUS, VoluntarySwitches, InvoluntarySwitches, MinorFaults, MajorFaults int64
	IO, Pressure, CgroupCPU                                                            map[string]uint64
	PoolAcquireCount, PoolAcquireNanoseconds, PoolEmptyCount                           int64
	PoolTotal, PoolIdle                                                                int32
}

func feedTailNumbers(path string, allowed map[string]bool) map[string]uint64 {
	raw, e := os.ReadFile(path)
	out := map[string]uint64{}
	if e != nil {
		return out
	}
	for _, line := range strings.Split(string(raw), "\n") {
		fields := strings.Fields(line)
		if len(fields) != 2 {
			continue
		}
		key := strings.TrimSuffix(fields[0], ":")
		if !allowed[key] {
			continue
		}
		if value, e := strconv.ParseUint(fields[1], 10, 64); e == nil {
			out[key] = value
		}
	}
	return out
}
func feedTailSystemSnapshot(pool *pgxpool.Pool) feedTailSystem {
	result := feedTailSystem{Runtime: map[string]float64{}, Histograms: map[string]feedTailHistogram{}, Pressure: map[string]uint64{}}
	samples := make([]metrics.Sample, len(feedTailMetricNames))
	for i, name := range feedTailMetricNames {
		samples[i].Name = name
	}
	metrics.Read(samples)
	for _, s := range samples {
		switch s.Value.Kind() {
		case metrics.KindUint64:
			result.Runtime[s.Name] = float64(s.Value.Uint64())
		case metrics.KindFloat64:
			result.Runtime[s.Name] = s.Value.Float64()
		case metrics.KindFloat64Histogram:
			h := s.Value.Float64Histogram()
			buckets := append([]float64(nil), h.Buckets...)
			// Infinite outer boundaries are represented explicitly as +/-MaxFloat64 so
			// the JSON remains valid; bucket counts retain their original indices.
			for i, b := range buckets {
				if b > 1e308 {
					buckets[i] = 1.7976931348623157e308
				}
				if b < -1e308 {
					buckets[i] = -1.7976931348623157e308
				}
			}
			result.Histograms[s.Name] = feedTailHistogram{append([]uint64(nil), h.Counts...), buckets}
		default:
			result.Missing = append(result.Missing, s.Name)
		}
	}
	var usage syscall.Rusage
	if syscall.Getrusage(syscall.RUSAGE_SELF, &usage) == nil {
		result.UserUS = usage.Utime.Sec*1e6 + usage.Utime.Usec
		result.SystemUS = usage.Stime.Sec*1e6 + usage.Stime.Usec
		result.VoluntarySwitches = usage.Nvcsw
		result.InvoluntarySwitches = usage.Nivcsw
		result.MinorFaults = usage.Minflt
		result.MajorFaults = usage.Majflt
	}
	result.IO = feedTailNumbers("/proc/self/io", map[string]bool{"rchar": true, "wchar": true, "syscr": true, "syscw": true, "read_bytes": true, "write_bytes": true, "cancelled_write_bytes": true})
	result.CgroupCPU = feedTailNumbers("/sys/fs/cgroup/cpu.stat", map[string]bool{"usage_usec": true, "user_usec": true, "system_usec": true, "nr_periods": true, "nr_throttled": true, "throttled_usec": true})
	for _, resource := range []string{"cpu", "io", "memory"} {
		raw, e := os.ReadFile("/proc/pressure/" + resource)
		if e != nil {
			continue
		}
		for _, line := range strings.Split(string(raw), "\n") {
			fields := strings.Fields(line)
			if len(fields) == 0 {
				continue
			}
			for _, field := range fields[1:] {
				if strings.HasPrefix(field, "total=") {
					value, e := strconv.ParseUint(strings.TrimPrefix(field, "total="), 10, 64)
					if e == nil {
						result.Pressure[resource+"."+fields[0]] = value
					}
				}
			}
		}
	}
	if pool != nil {
		s := pool.Stat()
		result.PoolAcquireCount = s.AcquireCount()
		result.PoolAcquireNanoseconds = s.AcquireDuration().Nanoseconds()
		result.PoolEmptyCount = s.EmptyAcquireCount()
		result.PoolTotal = s.TotalConns()
		result.PoolIdle = s.IdleConns()
	}
	return result
}

type feedTailTraceBuffer struct {
	bytes.Buffer
	Truncated bool
}

func (b *feedTailTraceBuffer) Write(p []byte) (int, error) {
	n := len(p)
	remaining := 32*1024*1024 - b.Len()
	if len(p) > remaining {
		p = p[:remaining]
		b.Truncated = true
	}
	_, _ = b.Buffer.Write(p)
	return n, nil
}

type feedTailSample struct {
	Kind                                                     string
	Index                                                    int
	Warmup                                                   bool
	RawMS, GoLowerMS, GoUpperMS                              float64
	ClockValid, Reused                                       bool
	ConnectionWaitNS, FirstByteNS                            int64
	StartedUnixNS                                            int64
	CaptureBeforeNS, CaptureAfterNS, ServerObservationWaitNS int64
	Before, After                                            feedTailSystem
	Server                                                   readtiming.Observation
}

func TestRealHTTPSFeedTailDiagnosticPostgres(t *testing.T) {
	output := os.Getenv("REQ002_TAIL_DIAGNOSTIC_DIRECTORY")
	if output == "" {
		t.Skip("explicit independent tail diagnostic required")
	}
	if _, e := os.Stat(output); !os.IsNotExist(e) {
		t.Fatal("refusing existing tail diagnostic")
	}
	if e := os.MkdirAll(output, 0700); e != nil {
		t.Fatal(e)
	}
	t.Setenv("REQ002_PERFORMANCE", "1")
	t.Setenv("REQ002_PERFORMANCE_MODE", "batch")
	t.Setenv("REQ002_PERFORMANCE_ROUND", "3")
	t.Setenv("REQ002_PERFORMANCE_OUTPUT", filepath.Join(output, "diagnostic-measurements.json"))
	report := struct {
		Source, GoVersion, GOARCH              string
		DiagnosticOnly                         bool
		Protocol                               string
		GOMAXPROCS, CPUs                       int
		Metrics                                []string
		TraceEnabled, TraceTruncated, Complete bool
		TraceStartupNS                         int64
		Samples                                []feedTailSample
	}{Source: os.Getenv("REQ002_SOURCE"), GoVersion: runtime.Version(), GOARCH: runtime.GOARCH, DiagnosticOnly: true,
		Protocol:   "Same frozen 49+12 fixture; same seven routes in order; each 10 warmup + 80 samples; unchanged RAW/Go guard; system counters outside interval; counter deltas enclose capture overhead; correlate with execution trace; instrumentation is not acceptance",
		GOMAXPROCS: runtime.GOMAXPROCS(0), CPUs: runtime.NumCPU(), Metrics: feedTailMetricNames}
	var active atomic.Bool
	observations := make(chan readtiming.Observation, 1)
	var pool *pgxpool.Pool
	var current *feedTailSample
	var requestStart, connectionStart time.Time
	var traceBuffer feedTailTraceBuffer
	tracing := false
	defer func() {
		active.Store(false)
		if tracing {
			runtimetrace.Stop()
			report.TraceTruncated = traceBuffer.Truncated
			if e := os.WriteFile(filepath.Join(output, "runtime.trace"), traceBuffer.Bytes(), 0600); e != nil {
				t.Error(e)
			}
		}
		raw, e := json.MarshalIndent(report, "", "  ")
		if e == nil {
			e = os.WriteFile(filepath.Join(output, "tail-observations.json"), raw, 0600)
		}
		if e != nil {
			t.Error(e)
		}
	}()
	observer := &feedBatchPerformanceObserver{
		Configure: func(s *e2eServices) {
			pool = s.cp
			handler := s.cPublic.Config.Handler
			s.cPublic.Config.Handler = http.HandlerFunc(func(w http.ResponseWriter, r *http.Request) {
				if !active.Load() || r.URL.Path != "/api/v1/feed" {
					handler.ServeHTTP(w, r)
					return
				}
				ctx, trace := readtiming.Start(r.Context())
				runtimetrace.Log(ctx, "feed-server", fmt.Sprintf("%s/%d", current.Kind, current.Index))
				handler.ServeHTTP(w, r.WithContext(ctx))
				observations <- trace.Snapshot()
			})
		},
		BeforeRequest: func(req *http.Request, kind string, index int) *http.Request {
			if len(report.Samples) == 0 && os.Getenv("REQ002_TAIL_GO_TRACE") == "1" {
				start := time.Now()
				if e := runtimetrace.Start(&traceBuffer); e != nil {
					t.Fatal(e)
				}
				tracing = true
				report.TraceEnabled = true
				report.TraceStartupNS = time.Since(start).Nanoseconds()
			}
			current = &feedTailSample{Kind: kind, Index: index, Warmup: index < 10}
			start := time.Now()
			current.Before = feedTailSystemSnapshot(pool)
			current.CaptureBeforeNS = time.Since(start).Nanoseconds()
			requestStart = time.Now()
			current.StartedUnixNS = requestStart.UnixNano()
			active.Store(true)
			runtimetrace.Log(req.Context(), "feed-client-start", fmt.Sprintf("%s/%d", kind, index))
			trace := &httptrace.ClientTrace{GetConn: func(string) { connectionStart = time.Now() }, GotConn: func(info httptrace.GotConnInfo) {
				current.Reused = info.Reused
				current.ConnectionWaitNS = time.Since(connectionStart).Nanoseconds()
			}, GotFirstResponseByte: func() { current.FirstByteNS = time.Since(requestStart).Nanoseconds() }}
			return req.WithContext(httptrace.WithClientTrace(req.Context(), trace))
		},
		AfterRequest: func(kind string, index int, raw, lower, upper float64, valid bool) {
			start := time.Now()
			select {
			case current.Server = <-observations:
			case <-time.After(time.Second):
				t.Fatal("missing same-request server observation")
			}
			current.ServerObservationWaitNS = time.Since(start).Nanoseconds()
			runtimetrace.Log(context.Background(), "feed-client-end", fmt.Sprintf("%s/%d", kind, index))
			active.Store(false)
			start = time.Now()
			current.After = feedTailSystemSnapshot(pool)
			current.CaptureAfterNS = time.Since(start).Nanoseconds()
			current.RawMS, current.GoLowerMS, current.GoUpperMS, current.ClockValid = raw, lower, upper, valid
			if current.Kind != kind || current.Index != index {
				t.Fatal("diagnostic association lost")
			}
			report.Samples = append(report.Samples, *current)
			if current.Server.Stages["feed.list_proof"].Calls != 2 || current.Server.Stages["feed.anchor_write"].Calls != 1 {
				t.Fatal("diagnostic authority/proof path changed")
			}
		},
	}
	runRealHTTPSFeedBatchPerformance(t, observer)
	if len(report.Samples) != 630 {
		t.Fatal("missing diagnostic requests", len(report.Samples))
	}
	report.Complete = true
	valid, slow := 0, 0
	for _, sample := range report.Samples {
		if sample.ClockValid {
			valid++
		}
		if sample.RawMS > 5 {
			slow++
		}
		if len(sample.Before.Missing) != 0 || len(sample.After.Missing) != 0 {
			t.Fatal("runtime metrics unavailable")
		}
	}
	t.Logf("diagnostic only: 630 requests; clock valid %d; raw >5ms %d; no exclusions or acceptance result", valid, slow)
}
func TestFeedTailSystemCounters(t *testing.T) {
	before := feedTailSystemSnapshot(nil)
	after := feedTailSystemSnapshot(nil)
	if len(before.Missing) > 0 || len(before.IO) == 0 || len(before.Histograms) != 2 || after.Runtime["/gc/cycles/total:gc-cycles"] < before.Runtime["/gc/cycles/total:gc-cycles"] {
		t.Fatal("missing or nonmonotonic diagnostic counters")
	}
	b, e := json.Marshal(after)
	if e != nil || len(b) == 0 {
		t.Fatal("invalid diagnostic JSON", e)
	}
}
