package events

import (
	"context"
	"sync"
	"sync/atomic"
	"testing"
)

func TestPublishDeliversToMatchingSubscribersInOrder(t *testing.T) {
	bus := New()
	var got []string
	unsubscribe := bus.Subscribe(RequestCreated, func(_ context.Context, e Event) {
		got = append(got, "first:"+e.Name)
	})
	bus.Subscribe(RequestCreated, func(_ context.Context, e Event) {
		got = append(got, "second:"+e.Name)
	})
	bus.Subscribe(RequestAccepted, func(_ context.Context, e Event) {
		got = append(got, "other:"+e.Name)
	})

	bus.Publish(context.Background(), Event{Name: RequestCreated})
	if len(got) != 2 || got[0] != "first:request.created" || got[1] != "second:request.created" {
		t.Fatalf("delivered = %v", got)
	}

	unsubscribe()
	unsubscribe() // idempotent
	got = nil
	bus.Publish(context.Background(), Event{Name: RequestCreated})
	if len(got) != 1 || got[0] != "second:request.created" {
		t.Fatalf("after unsubscribe delivered = %v", got)
	}
}

func TestPanickingSubscriberDoesNotBlockOthers(t *testing.T) {
	bus := New()
	called := false
	bus.Subscribe(RequestCreated, func(context.Context, Event) {
		panic("subscriber blew up")
	})
	bus.Subscribe(RequestCreated, func(context.Context, Event) {
		called = true
	})

	bus.Publish(context.Background(), Event{Name: RequestCreated, Payload: "secret-token"})
	if !called {
		t.Fatal("later subscriber was not called after a panic")
	}
}

func TestPublishNilBusAndUnknownEventAreNoOps(t *testing.T) {
	var bus *Bus
	bus.Publish(context.Background(), Event{Name: RequestCreated})

	bus = New()
	bus.Publish(context.Background(), Event{})
}

func TestConcurrentSubscribePublishUnsubscribeIsRaceFree(t *testing.T) {
	bus := New()
	var calls atomic.Int64
	var wg sync.WaitGroup

	for i := 0; i < 8; i++ {
		wg.Add(1)
		go func() {
			defer wg.Done()
			unsubscribe := bus.Subscribe(RequestCreated, func(context.Context, Event) {
				calls.Add(1)
			})
			bus.Publish(context.Background(), Event{Name: RequestCreated})
			unsubscribe()
		}()
	}
	wg.Wait()

	// Every publisher saw at least its own handler; no race, no deadlock.
	if calls.Load() == 0 {
		t.Fatal("no handlers were called")
	}
	// All subscriptions were removed again.
	var after atomic.Int64
	bus.Subscribe(RequestCreated, func(context.Context, Event) { after.Add(1) })
	bus.Publish(context.Background(), Event{Name: RequestCreated})
	if after.Load() != 1 {
		t.Fatalf("subscriber calls after cleanup = %d, want 1", after.Load())
	}
}
