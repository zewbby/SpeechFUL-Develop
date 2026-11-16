package authprivacyhttp

import (
	"context"
	"encoding/json"
	"fmt"
	"io"
	"math"
	"net/http"
	"os"
	"reflect"
	"sort"
	"strconv"
	"testing"
	"time"

	"github.com/zhubaozhenshuai666-lang/HnuHole/services/api/internal/posts"
)

// Opt-in real TLS + PostgreSQL comparison. Never accepts a database or token
// from the caller: e2eNewServices owns and resets only the isolated authlab DB.
func TestRealHTTPSFeedBatchPerformancePostgres(t *testing.T) {
	if os.Getenv("REQ002_PERFORMANCE") != "1" {
		t.Skip("explicit frozen performance run required")
	}
	// This exact measurement file also compiles in the frozen pre-REQ002
	// checkout. Never compare both modes against an already optimized Gate.
	mode := os.Getenv("REQ002_PERFORMANCE_MODE")
	if mode != "legacy" && mode != "batch" {
		t.Fatal("explicit legacy/batch mode and separate frozen checkout required")
	}
	round, e := strconv.Atoi(os.Getenv("REQ002_PERFORMANCE_ROUND"))
	if e != nil || round < 1 || round > 3 {
		t.Fatal("explicit round 1..3 required")
	}
	output := os.Getenv("REQ002_PERFORMANCE_OUTPUT")
	if output == "" {
		t.Fatal("artifact required")
	}
	if _, e := os.Stat(output); !os.IsNotExist(e) {
		t.Fatal("refusing existing artifact")
	}
	type cohort struct {
		Round      int `json:"round"`
		Kind, Mode string
		Samples    []float64
		P95        float64
		Errors     []string
	}
	report := struct {
		Source                  string
		Warmup, Samples, Rounds int
		Cohorts                 []cohort
		Complete                bool
		Threshold               float64
	}{Source: os.Getenv("REQ002_SOURCE"), Warmup: 10, Samples: 80, Rounds: 1, Threshold: .40}
	defer func() {
		data, e := json.MarshalIndent(report, "", "  ")
		if e != nil {
			t.Error(e)
			return
		}
		if e = os.WriteFile(output, data, 0600); e != nil {
			t.Error(e)
		}
	}()
	s := e2eNewServices(t)
	owner, _ := e2ePrivacySignup(t, s, "batch_perf_owner")
	reader, _ := e2ePrivacySignup(t, s, "batch_perf_reader")
	channel := postHTTPSChannel(t, s, owner)
	identity := postHTTPSIdentity(t, s, owner, "性能作者", 151)
	for n := 0; n < 61; n++ {
		postHTTPSJSON(t, s, "PUT", fmt.Sprintf("/api/v1/post-commands/%s", httpTestEncoding(16, byte(n+10))), owner, "", posts.CreatePostInput{ChannelID: channel, IdentityID: identity, Title: fmt.Sprintf("Frozen %02d", n), Body: "Frozen chronological feed performance body."}, 202)
	}
	if _, e := s.c.PublishAcceptedPosts(context.Background(), 100); e != nil {
		t.Fatal(e)
	}
	cfg := s.postConfig
	cfg.PreparedFeedReads = true
	legacyFlag := reflect.ValueOf(&cfg).Elem().FieldByName("LegacyListReads")
	if legacyFlag.IsValid() {
		legacyFlag.SetBool(mode == "legacy")
	} else if mode != "legacy" {
		t.Fatal("batch mode unavailable in frozen baseline")
	}
	selected, e := s.c.WithPosts(context.Background(), cfg)
	if e != nil {
		t.Fatal(e)
	}
	*s.c = *selected
	first20 := postHTTPSJSON(t, s, "GET", "/api/v1/feed?limit=20", reader, "", nil, 200)
	first5 := postHTTPSJSON(t, s, "GET", "/api/v1/feed?limit=5", reader, "", nil, 200)
	routes := []struct {
		kind, path string
		size       int
	}{
		{"home20", "/api/v1/feed?limit=20", 20}, {"next20", "/api/v1/feed?limit=20&cursor=" + first20["nextCursor"].(string), 20},
		{"home10", "/api/v1/feed?limit=10", 10}, {"next5", "/api/v1/feed?limit=5&cursor=" + first5["nextCursor"].(string), 5},
	}
	for _, route := range routes {
		report.Cohorts = append(report.Cohorts, cohort{Round: round, Kind: route.kind, Mode: mode, Samples: []float64{}})
		c := &report.Cohorts[len(report.Cohorts)-1]
		for n := 0; n < report.Warmup+report.Samples; n++ {
			req, e := http.NewRequest(http.MethodGet, s.cPublic.URL+route.path, nil)
			if e != nil {
				t.Fatal(e)
			}
			req.Header.Set("Authorization", "Bearer "+reader)
			req.Header.Set("X-Post-Preview", "thumbnail-v1")
			started := time.Now()
			resp, e := s.client.Do(req)
			if e != nil {
				c.Errors = append(c.Errors, "transport")
				t.Fatal("measurement transport failed")
			}
			data, e := io.ReadAll(io.LimitReader(resp.Body, 262144))
			resp.Body.Close()
			elapsed := float64(time.Since(started)) / float64(time.Millisecond)
			if e != nil || resp.StatusCode != 200 {
				c.Errors = append(c.Errors, fmt.Sprintf("HTTP_%d", resp.StatusCode))
				t.Fatalf("measurement %s %s status %d", route.kind, mode, resp.StatusCode)
			}
			var page posts.CrossChannelFeedPage
			if json.Unmarshal(data, &page) != nil || len(page.Items) != route.size {
				c.Errors = append(c.Errors, "incomplete_page")
				t.Fatal("incomplete measured page")
			}
			if n >= report.Warmup {
				c.Samples = append(c.Samples, elapsed)
			}
		}
		sorted := append([]float64{}, c.Samples...)
		sort.Float64s(sorted)
		c.P95 = sorted[int(math.Ceil(.95*float64(len(sorted))))-1]
	}
	report.Complete = true
	for _, c := range report.Cohorts {
		t.Logf("round%d %s %s p95=%.3fms (cross-checkout hard gate runs in compare-feed-performance.py)", c.Round, c.Kind, c.Mode, c.P95)
	}
}
