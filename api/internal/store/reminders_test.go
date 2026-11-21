package store

import (
	"context"
	"path/filepath"
	"testing"
)

func TestDonorsAndDonorsByGroupAll(t *testing.T) {
	st, err := Open(filepath.Join(t.TempDir(), "test.db"))
	if err != nil {
		t.Fatal(err)
	}
	defer st.Close()
	ctx := context.Background()
	group := "O-"

	users := []User{
		{ID: "u1", Name: "Asha", Role: "donor", BloodGroup: &group, Available: true},
		{ID: "u2", Name: "Imran", Role: "donor", BloodGroup: &group, Available: false},
		{ID: "u3", Name: "Priya", Role: "donor", BloodGroup: &group, Available: true},
		{ID: "u4", Name: "Ravi", Role: "requester", BloodGroup: &group, Available: true},
	}
	for _, u := range users {
		if err := st.CreateUser(ctx, u); err != nil {
			t.Fatal(err)
		}
	}

	donors, err := st.Donors(ctx)
	if err != nil {
		t.Fatal(err)
	}
	if len(donors) != 3 {
		t.Fatalf("Donors = %+v, want 3 donors", donors)
	}
	for i, id := range []string{"u1", "u2", "u3"} {
		if donors[i].ID != id {
			t.Errorf("Donors[%d].ID = %q, want %q", i, donors[i].ID, id)
		}
	}

	all, err := st.DonorsByGroupAll(ctx, group)
	if err != nil {
		t.Fatal(err)
	}
	if len(all) != 3 {
		t.Fatalf("DonorsByGroupAll = %+v, want 3 donors (including unavailable)", all)
	}
	available, err := st.DonorsByGroup(ctx, group)
	if err != nil {
		t.Fatal(err)
	}
	if len(available) != 2 {
		t.Fatalf("DonorsByGroup = %+v, want 2 available donors", available)
	}
}

func TestHasNotificationForRequest(t *testing.T) {
	st, err := Open(filepath.Join(t.TempDir(), "test.db"))
	if err != nil {
		t.Fatal(err)
	}
	defer st.Close()
	ctx := context.Background()

	requestID := "r1"
	if err := st.InsertNotification(ctx, Notification{
		ID: "n1", UserID: "u1", Type: "match_nearby", Title: "t",
		Body: "b", RequestID: &requestID,
	}); err != nil {
		t.Fatal(err)
	}

	ok, err := st.HasNotificationForRequest(ctx, "u1", "match_nearby", "r1")
	if err != nil || !ok {
		t.Fatalf("same request ok=%v err=%v, want true", ok, err)
	}
	ok, err = st.HasNotificationForRequest(ctx, "u1", "match_nearby", "r2")
	if err != nil || ok {
		t.Fatalf("other request ok=%v err=%v, want false", ok, err)
	}
	ok, err = st.HasNotificationForRequest(ctx, "u2", "match_nearby", "r1")
	if err != nil || ok {
		t.Fatalf("other user ok=%v err=%v, want false", ok, err)
	}
	ok, err = st.HasNotificationForRequest(ctx, "u1", "eligible_again", "r1")
	if err != nil || ok {
		t.Fatalf("other type ok=%v err=%v, want false", ok, err)
	}
}

func TestHasNotificationSince(t *testing.T) {
	st, err := Open(filepath.Join(t.TempDir(), "test.db"))
	if err != nil {
		t.Fatal(err)
	}
	defer st.Close()
	ctx := context.Background()

	if err := st.InsertNotification(ctx, Notification{
		ID: "n1", UserID: "u1", Type: "eligible_again", Title: "t", Body: "b",
	}); err != nil {
		t.Fatal(err)
	}
	// Pin the row's created_at so the boundary is deterministic.
	if _, err := st.db.ExecContext(ctx,
		`UPDATE notifications SET created_at = ? WHERE id = ?`, "2026-06-01 12:00:00", "n1"); err != nil {
		t.Fatal(err)
	}

	for _, tc := range []struct {
		since string
		want  bool
	}{
		{"2026-05-31 12:00:00", true},  // reminder written after the cycle began
		{"2026-06-01 12:00:00", true},  // inclusive boundary
		{"2026-06-02 12:00:00", false}, // a newer donation cycle
	} {
		ok, err := st.HasNotificationSince(ctx, "u1", "eligible_again", tc.since)
		if err != nil || ok != tc.want {
			t.Errorf("since=%s ok=%v err=%v, want %v", tc.since, ok, err, tc.want)
		}
	}

	ok, err := st.HasNotificationSince(ctx, "u1", "rank_up", "2026-05-31 12:00:00")
	if err != nil || ok {
		t.Fatalf("other type ok=%v err=%v, want false", ok, err)
	}
	ok, err = st.HasNotificationSince(ctx, "u2", "eligible_again", "2026-05-31 12:00:00")
	if err != nil || ok {
		t.Fatalf("other user ok=%v err=%v, want false", ok, err)
	}
}
