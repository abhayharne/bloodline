package store

import (
	"context"
	"testing"
)

func TestRequestFeedOrdersByUrgencyThenRecent(t *testing.T) {
	st := newTestStore(t)
	ctx := context.Background()
	group := "O+"
	if err := st.CreateUser(ctx, User{ID: "requester", Name: "Ravi", Role: "requester"}); err != nil {
		t.Fatalf("CreateUser: %v", err)
	}

	// Rows are inserted oldest-first so a plain created_at DESC sort would put
	// r3 first. Urgency must take precedence, then recency within a level.
	rows := []struct {
		id, urgency, createdAt string
	}{
		{"r1", "low", "2026-11-22T09:00:00Z"},
		{"r2", "critical", "2026-11-22T09:01:00Z"},
		{"r3", "medium", "2026-11-22T09:10:00Z"},
		{"r4", "high", "2026-11-22T09:02:00Z"},
		{"r5", "critical", "2026-11-22T09:03:00Z"},
	}
	for _, row := range rows {
		if err := st.CreateRequest(ctx, Request{
			ID: row.id, RequesterID: "requester", BloodGroup: group, Units: 1,
			Hospital: "H", Urgency: row.urgency, CreatedAt: row.createdAt,
			ChannelID: "req" + row.id,
		}); err != nil {
			t.Fatalf("CreateRequest(%s): %v", row.id, err)
		}
	}

	got, err := st.Requests(ctx, "all")
	if err != nil {
		t.Fatalf("Requests: %v", err)
	}
	want := []string{"r5", "r2", "r4", "r3", "r1"}
	if len(got) != len(want) {
		t.Fatalf("Requests count = %d, want %d (%+v)", len(got), len(want), got)
	}
	for i, id := range want {
		if got[i].ID != id {
			t.Errorf("Requests[%d].ID = %q, want %q", i, got[i].ID, id)
		}
	}
}

func TestCreateRequestWritesRFC3339CreatedAt(t *testing.T) {
	st := newTestStore(t)
	ctx := context.Background()
	group := "O+"
	if err := st.CreateUser(ctx, User{ID: "requester", Name: "Ravi", Role: "requester"}); err != nil {
		t.Fatalf("CreateUser: %v", err)
	}
	if err := st.CreateRequest(ctx, Request{
		ID: "r1", RequesterID: "requester", BloodGroup: group, Units: 1,
		Hospital: "H", Urgency: "critical", ChannelID: "reqr1",
	}); err != nil {
		t.Fatal(err)
	}

	got, err := st.RequestByID(ctx, "r1")
	if err != nil {
		t.Fatal(err)
	}
	if !rfc3339UTC.MatchString(got.CreatedAt) {
		t.Fatalf("CreatedAt = %q, want RFC3339 UTC with Z", got.CreatedAt)
	}
}
