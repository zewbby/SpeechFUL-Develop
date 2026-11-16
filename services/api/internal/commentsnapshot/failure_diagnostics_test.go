package commentsnapshot

import (
	"context"
	"errors"
	"fmt"
	"github.com/redis/go-redis/v9"
	"net"
	"strings"
	"sync"
	"testing"
	"time"
)

// Test-only diagnostics retain no command arguments, values, keys, credentials
// or raw error text. Observe the original bounded call without retrying it or
// changing a product timeout. The ring is emitted only if the owned test fails.
type redisFailureEvent struct {
	Command, ErrorType, Code string
	Elapsed                  time.Duration
	Timeout, Cancelled       bool
}

func redisFailureSummary(command string, elapsed time.Duration, err error) redisFailureEvent {
	event := redisFailureEvent{Command: command, Elapsed: elapsed}
	if err == nil {
		return event
	}
	event.ErrorType = fmt.Sprintf("%T", err)
	event.Timeout = errors.Is(err, context.DeadlineExceeded)
	event.Cancelled = errors.Is(err, context.Canceled)
	var network net.Error
	if errors.As(err, &network) {
		event.Timeout = event.Timeout || network.Timeout()
	}
	for _, code := range []string{"NOSCRIPT", "ERR", "OOM", "BUSY", "MISCONF", "READONLY", "LOADING", "WRONGTYPE"} {
		if strings.HasPrefix(err.Error(), code+" ") {
			event.Code = code
			break
		}
	}
	return event
}

type ownedRedisFailureObserver struct {
	mu     sync.Mutex
	events []redisFailureEvent
}

func (o *ownedRedisFailureObserver) DialHook(next redis.DialHook) redis.DialHook { return next }
func (o *ownedRedisFailureObserver) ProcessPipelineHook(next redis.ProcessPipelineHook) redis.ProcessPipelineHook {
	return next
}
func (o *ownedRedisFailureObserver) ProcessHook(next redis.ProcessHook) redis.ProcessHook {
	return func(ctx context.Context, cmd redis.Cmder) error {
		start := time.Now()
		err := next(ctx, cmd)
		event := redisFailureSummary(cmd.Name(), time.Since(start), err)
		o.mu.Lock()
		if len(o.events) == 128 {
			copy(o.events, o.events[1:])
			o.events = o.events[:127]
		}
		o.events = append(o.events, event)
		o.mu.Unlock()
		return err
	}
}
func observeOwnedRedisFailure(t *testing.T, s *Store) {
	t.Helper()
	observer := &ownedRedisFailureObserver{}
	s.client.AddHook(observer)
	t.Cleanup(func() {
		if !t.Failed() {
			return
		}
		observer.mu.Lock()
		events := append([]redisFailureEvent(nil), observer.events...)
		observer.mu.Unlock()
		t.Logf("owned Redis original bounded calls: %+v", events)
		ctx, cancel := context.WithTimeout(context.Background(), 500*time.Millisecond)
		defer cancel()
		info, err := s.client.Info(ctx, "persistence").Result()
		if err != nil {
			t.Logf("owned Redis post-failure diagnostic: %+v", redisFailureSummary("info", 0, err))
			return
		}
		for _, line := range strings.Split(info, "\r\n") {
			for _, field := range []string{"loading", "aof_enabled", "aof_rewrite_in_progress", "aof_rewrite_scheduled", "aof_last_bgrewrite_status", "aof_last_write_status", "aof_pending_bio_fsync", "aof_delayed_fsync"} {
				if strings.HasPrefix(line, field+":") {
					t.Log("owned Redis persistence:", line)
				}
			}
		}
	})
}
func TestRedisFailureSummaryDoesNotExposeArguments(t *testing.T) {
	for _, err := range []error{errors.New("ERR secret-payload private-key"), errors.New("NOSCRIPT private-script"), context.DeadlineExceeded, context.Canceled, &net.OpError{Op: "read", Net: "tcp", Err: context.DeadlineExceeded}} {
		event := redisFailureSummary("evalsha", time.Millisecond, err)
		output := fmt.Sprintf("%+v", event)
		if strings.Contains(output, "secret") || strings.Contains(output, "private") {
			t.Fatal("error content exposed")
		}
		if errors.Is(err, context.DeadlineExceeded) && !event.Timeout {
			t.Fatal("timeout cause lost")
		}
		if errors.Is(err, context.Canceled) && !event.Cancelled {
			t.Fatal("cancel cause lost")
		}
	}
}
