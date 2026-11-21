package reminders

import (
	"context"
	"fmt"
	"path/filepath"
	"strings"
	"testing"
	"time"

	"bloodline/internal/events"
	"bloodline/internal/matching"
	"bloodline/internal/store"
)

func newTestHandler(t *testing.T) (*Handler, *store.Store) {
	t.Helper()
	st, err := store.Open(filepath.Join(t.TempDir(), "test.db"))
	if err != nil {
		t.Fatal(err)
	}
	t.Cleanup(func() { st.Close() })
	return New(st), st
}

func TestMatchNearbyNotifiesDonorsOnlyAndIsIdempotent(t *testing.T) {
	h, st := newTestHandler(t)
	ctx := context.Background()
	group := "O-"

	if err := st.CreateRequest(ctx, store.Request{
		ID: "r1", RequesterID: "uReq", BloodGroup: group, Units: 1,
		Hospital: "City Hospital", Urgency: "critical", Status: "open",
		ChannelID: "reqr1", Lat: 21.10, Lng: 79.00,
	}); err != nil {
		t.Fatal(err)
	}
	createUser(t, st, store.User{ID: "uReq", Name: "Ravi", Role: "requester", BloodGroup: &group, Lat: 21.10, Lng: 79.00, Available: true})
	createUser(t, st, store.User{ID: "uDonor", Name: "Asha", Role: "donor", BloodGroup: &group, Lat: 21.11, Lng: 79.00, Available: true})
	createUser(t, st, store.User{ID: "uBank", Name: "City Bank", Role: "bank", Lat: 21.10, Lng: 79.00, Available: true})

	event := events.Event{Name: events.RequestCreated, Payload: events.RequestCreatedPayload{
		RequestID: "r1", BloodGroup: group, Hospital: "City Hospital", Units: 1,
		RecipientIDs: []string{"uBank", "uDonor", "uReq"}, RequesterName: "Ravi",
	}}
	h.Handle(ctx, event)
	h.Handle(ctx, event) // duplicate delivery must not create a second row

	items, err := st.Notifications(ctx, "uDonor")
	if err != nil {
		t.Fatal(err)
	}
	if len(items) != 1 {
		t.Fatalf("donor notifications = %+v, want 1", items)
	}
	km := matching.DistanceKM(21.10, 79.00, 21.11, 79.00)
	wantBody := fmt.Sprintf("%s, someone %.1f km away needs %s. That's your type. Got 10 minutes?", "Asha", km, group)
	if items[0].Type != "match_nearby" || items[0].Body != wantBody {
		t.Fatalf("notification = %+v, want match_nearby with body %q", items[0], wantBody)
	}
	if items[0].RequestID == nil || *items[0].RequestID != "r1" {
		t.Fatalf("RequestID = %v, want r1", items[0].RequestID)
	}
	for _, id := range []string{"uBank", "uReq"} {
		other, err := st.Notifications(ctx, id)
		if err != nil {
			t.Fatal(err)
		}
		if len(other) != 0 {
			t.Errorf("%s notifications = %+v, want none", id, other)
		}
	}
}

func TestRunEligibilityChecksOncePerCycle(t *testing.T) {
	h, st := newTestHandler(t)
	ctx := context.Background()
	group := "O-"
	old := time.Now().AddDate(0, 0, -200).UTC().Format("2006-01-02")
	recent := time.Now().AddDate(0, 0, -10).UTC().Format("2006-01-02")

	createUser(t, st, store.User{ID: "uOld", Name: "Imran", Role: "donor", BloodGroup: &group,
		Sex: strPtr("male"), Age: intPtr(35), WeightKG: floatPtr(70), LastDonatedAt: &old, Available: true})
	createUser(t, st, store.User{ID: "uRecent", Name: "Meera", Role: "donor", BloodGroup: &group,
		Sex: strPtr("female"), Age: intPtr(26), WeightKG: floatPtr(52), LastDonatedAt: &recent, Available: true})
	createUser(t, st, store.User{ID: "uNever", Name: "Asha", Role: "donor", BloodGroup: &group,
		Sex: strPtr("female"), Age: intPtr(28), WeightKG: floatPtr(58), Available: true})
	createUser(t, st, store.User{ID: "uRequester", Name: "Ravi", Role: "requester", BloodGroup: &group,
		LastDonatedAt: &old, Available: true})

	first, err := h.RunEligibilityChecks(ctx)
	if err != nil {
		t.Fatal(err)
	}
	if first != 1 {
		t.Fatalf("first run sent = %d, want 1", first)
	}
	second, err := h.RunEligibilityChecks(ctx)
	if err != nil {
		t.Fatal(err)
	}
	if second != 0 {
		t.Fatalf("repeat run sent = %d, want 0", second)
	}

	items, err := st.Notifications(ctx, "uOld")
	if err != nil {
		t.Fatal(err)
	}
	if len(items) != 1 {
		t.Fatalf("eligible_again notifications = %+v, want 1", items)
	}
	got := items[0]
	if got.Type != "eligible_again" || got.Title == "" ||
		!strings.Contains(got.Body, "days to recharge") ||
		!strings.Contains(got.Body, "Ready to be somebody's hero again?") {
		t.Fatalf("notification = %+v, want eligible_again copy", got)
	}
	for _, id := range []string{"uRecent", "uNever", "uRequester"} {
		other, err := st.Notifications(ctx, id)
		if err != nil {
			t.Fatal(err)
		}
		if len(other) != 0 {
			t.Errorf("%s notifications = %+v, want none", id, other)
		}
	}
}

func TestHandleIgnoresOtherPayloads(t *testing.T) {
	h, st := newTestHandler(t)
	h.Handle(context.Background(), events.Event{Name: events.RequestCreated, Payload: "bad"})
	items, _ := st.Notifications(context.Background(), "u1")
	if len(items) != 0 {
		t.Fatalf("items = %+v, want none", items)
	}
}

func createUser(t *testing.T, st *store.Store, user store.User) {
	t.Helper()
	if err := st.CreateUser(context.Background(), user); err != nil {
		t.Fatal(err)
	}
}

func strPtr(value string) *string { return &value }
func intPtr(value int) *int       { return &value }
func floatPtr(value float64) *float64 { return &value }
