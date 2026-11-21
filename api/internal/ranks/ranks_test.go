package ranks

import (
	"context"
	"path/filepath"
	"testing"

	"bloodline/internal/events"
	"bloodline/internal/store"
)

func TestHandleEmitsRankUpOncePerThreshold(t *testing.T) {
	st, err := store.Open(filepath.Join(t.TempDir(), "test.db"))
	if err != nil {
		t.Fatal(err)
	}
	defer st.Close()
	h := New(st)
	ctx := context.Background()

	ev := func(count int) events.Event {
		return events.Event{Name: events.DonationRecorded, Payload: events.DonationRecordedPayload{
			DonationID: "d1", RequestID: "r1", DonorID: "u1", DonationCount: count,
		}}
	}

	h.Handle(ctx, ev(1))
	h.Handle(ctx, ev(1)) // duplicate publish, should dedupe
	h.Handle(ctx, ev(2)) // same rank as 1, no new notification
	h.Handle(ctx, ev(3)) // crosses to Helper

	items, err := st.Notifications(ctx, "u1")
	if err != nil {
		t.Fatal(err)
	}
	if len(items) != 2 {
		t.Fatalf("notifications = %+v, want 2 rank_up rows", items)
	}
	// newest first
	if items[0].Type != "rank_up" || items[0].Body != "3 donations. You're now a Helper." {
		t.Errorf("items[0]=%+v", items[0])
	}
	if items[1].Body != "1 donations. You're now a First Drop." {
		t.Errorf("items[1]=%+v", items[1])
	}
}

func TestHandleIgnoresNonRankPayload(t *testing.T) {
	st, err := store.Open(filepath.Join(t.TempDir(), "test.db"))
	if err != nil {
		t.Fatal(err)
	}
	defer st.Close()
	New(st).Handle(context.Background(), events.Event{Name: events.DonationRecorded, Payload: "bad"})
	items, _ := st.Notifications(context.Background(), "u1")
	if len(items) != 0 {
		t.Fatalf("items=%+v", items)
	}
}
