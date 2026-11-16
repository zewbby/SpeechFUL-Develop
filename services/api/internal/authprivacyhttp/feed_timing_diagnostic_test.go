package authprivacyhttp

import (
	"context"
	"encoding/json"
	"fmt"
	"io"
	"math"
	"net/http"
	"net/http/httptrace"
	"os"
	"testing"
	"time"

	"github.com/zhubaozhenshuai666-lang/HnuHole/services/api/internal/posts"
	"github.com/zhubaozhenshuai666-lang/HnuHole/services/api/internal/readtiming"
)

// This bounded opt-in diagnostic closes client and server timings around the
// same real HTTPS request. It is not the three-round endpoint acceptance gate.
// It also compiles unchanged against the complete frozen baseline checkout.
func TestRealHTTPSFeedTimingDiagnosticPostgres(t *testing.T) {
	output := os.Getenv("REQ002_DIAGNOSTIC_OUTPUT")
	if output == "" {
		t.Skip("explicit diagnostic artifact required")
	}
	if _, err := os.Stat(output); !os.IsNotExist(err) {
		t.Fatal("refusing existing diagnostic artifact")
	}
	s := e2eNewServices(t)
	cfg := s.postConfig
	cfg.PreparedFeedReads = true
	selected, err := s.c.WithPosts(context.Background(), cfg)
	if err != nil {
		t.Fatal(err)
	}
	*s.c = *selected
	observations := make(chan readtiming.Observation, 1)
	handler := s.cPublic.Config.Handler
	s.cPublic.Config.Handler = http.HandlerFunc(func(w http.ResponseWriter, r *http.Request) {
		if r.URL.Path != "/api/v1/feed" {
			handler.ServeHTTP(w, r)
			return
		}
		ctx, trace := readtiming.Start(r.Context())
		handler.ServeHTTP(w, r.WithContext(ctx))
		observations <- trace.Snapshot()
	})
	owner, _ := e2ePrivacySignup(t, s, "feed_diag_owner")
	reader, _ := e2ePrivacySignup(t, s, "feed_diag_reader")
	channel := postHTTPSChannel(t, s, owner)
	identity := postHTTPSIdentity(t, s, owner, "诊断作者", 151)
	for n := 0; n < 21; n++ {
		postHTTPSJSON(t, s, "PUT", fmt.Sprintf("/api/v1/post-commands/%s", httpTestEncoding(16, byte(n+10))), owner, "", posts.CreatePostInput{ChannelID: channel, IdentityID: identity, Title: fmt.Sprintf("Diagnostic %02d", n), Body: "Frozen diagnostic feed body."}, 202)
	}
	if _, err = s.c.PublishAcceptedPosts(context.Background(), 100); err != nil {
		t.Fatal(err)
	}
	type sample struct {
		Limit, Index, Bytes                      int
		RawMS, GoLowerMS, GoUpperMS, FirstByteMS float64
		ClockValid, Reused                       bool
		Server                                   readtiming.Observation
	}
	report := struct {
		Source  string
		Samples []sample
	}{Source: os.Getenv("REQ002_SOURCE")}
	defer func() {
		raw, err := json.MarshalIndent(report, "", "  ")
		if err == nil {
			err = os.WriteFile(output, raw, 0600)
		}
		if err != nil {
			t.Error(err)
		}
	}()
	for _, limit := range []int{5, 10, 20} {
		for n := 0; n < 20; n++ {
			entry := sample{Limit: limit, Index: n}
			var firstByte time.Time
			trace := &httptrace.ClientTrace{GotConn: func(info httptrace.GotConnInfo) { entry.Reused = info.Reused }, GotFirstResponseByte: func() { firstByte = time.Now() }}
			req, err := http.NewRequestWithContext(httptrace.WithClientTrace(context.Background(), trace), "GET", fmt.Sprintf("%s/api/v1/feed?limit=%d", s.cPublic.URL, limit), nil)
			if err != nil {
				t.Fatal(err)
			}
			req.Header.Set("Authorization", "Bearer "+reader)
			req.Header.Set("X-Post-Preview", "thumbnail-v1")
			outerStart := time.Now()
			rawStart, startOK := feedPerformanceRawClock()
			innerStart := time.Now()
			resp, err := s.client.Do(req)
			if err != nil {
				t.Fatal("diagnostic transport failed")
			}
			body, err := io.ReadAll(io.LimitReader(resp.Body, 262144))
			resp.Body.Close()
			innerEnd := time.Now()
			rawEnd, endOK := feedPerformanceRawClock()
			outerEnd := time.Now()
			entry.RawMS = float64(rawEnd-rawStart) / 1e6
			entry.GoLowerMS = float64(innerEnd.Sub(innerStart)) / 1e6
			entry.GoUpperMS = float64(outerEnd.Sub(outerStart)) / 1e6
			entry.FirstByteMS = float64(firstByte.Sub(innerStart)) / 1e6
			tolerance := math.Max(.05, .01*entry.RawMS)
			entry.ClockValid = startOK && endOK && entry.RawMS > 0 && entry.GoLowerMS > 0 && entry.GoUpperMS-entry.GoLowerMS <= tolerance && entry.RawMS >= entry.GoLowerMS-tolerance && entry.RawMS <= entry.GoUpperMS+tolerance
			entry.Bytes, entry.Server = len(body), <-observations
			report.Samples = append(report.Samples, entry)
			var page posts.CrossChannelFeedPage
			if err != nil || resp.StatusCode != http.StatusOK || json.Unmarshal(body, &page) != nil || len(page.Items) != limit {
				t.Fatal("diagnostic request failed")
			}
		}
	}
}
