package service

import (
	"context"
	"errors"
	"path/filepath"
	"testing"
	"time"

	"bloodline/internal/auth"
	"bloodline/internal/events"
	"bloodline/internal/nexconn"
	"bloodline/internal/store"
)

type svcTest struct {
	svc *Service
	st  *store.Store
	bus *events.Bus
}

func newTestService(t *testing.T, opts ...Option) *svcTest {
	t.Helper()
	st, err := store.Open(filepath.Join(t.TempDir(), "test.db"))
	if err != nil {
		t.Fatal(err)
	}
	t.Cleanup(func() { st.Close() })
	issuer, err := auth.NewIssuer("test-secret", time.Hour)
	if err != nil {
		t.Fatal(err)
	}
	bus := events.New()
	opts = append([]Option{WithBus(bus)}, opts...)
	return &svcTest{svc: New(st, nexconn.NoopClient{}, issuer, opts...), st: st, bus: bus}
}

func createUser(t *testing.T, st *store.Store, user store.User) {
	t.Helper()
	if err := st.CreateUser(context.Background(), user); err != nil {
		t.Fatal(err)
	}
}

func createRequest(t *testing.T, st *store.Store, request store.Request) {
	t.Helper()
	if err := st.CreateRequest(context.Background(), request); err != nil {
		t.Fatal(err)
	}
}

func strPtr(value string) *string     { return &value }
func floatPtr(value float64) *float64 { return &value }
func boolPtr(value bool) *bool        { return &value }

func TestProfileDerivedEligibilityAndCount(t *testing.T) {
	env := newTestService(t)
	ctx := context.Background()
	group, sex := "O+", "male"
	age, weight := 28, 58.0
	createUser(t, env.st, store.User{
		ID: "u1", Name: "Asha", Role: "donor", BloodGroup: &group,
		Sex: &sex, Age: &age, WeightKG: &weight, Available: true,
	})

	view, err := env.svc.Profile(ctx, "u1")
	if err != nil {
		t.Fatal(err)
	}
	if view.User.ID != "u1" || !view.Derived.Eligible || view.Derived.NextEligibleAt != nil ||
		view.Derived.DonationCount != 0 || view.Derived.Rank != nil {
		t.Fatalf("fresh donor profile = %+v", view.Derived)
	}

	// A donation count comes from the donations table, not from last_donated_at.
	createUser(t, env.st, store.User{ID: "u9", Name: "Requester Nine", Role: "requester", BloodGroup: &group})
	createRequest(t, env.st, store.Request{
		ID: "r9", RequesterID: "u9", BloodGroup: group, Units: 1,
		Hospital: "H", Urgency: "urgent", Status: "open",
	})
	if err := env.st.CreateDonation(ctx, store.Donation{ID: "d1", RequestID: "r9", DonorID: "u1", Units: 1}); err != nil {
		t.Fatal(err)
	}
	view, err = env.svc.Profile(ctx, "u1")
	if err != nil || view.Derived.DonationCount != 1 {
		t.Fatalf("donation_count = %d, %v; want 1", view.Derived.DonationCount, err)
	}

	// Recent donation makes the donor ineligible and exposes the next date.
	recent := time.Now().AddDate(0, 0, -10).UTC().Format("2006-01-02")
	if err := env.st.UpdateProfile(ctx, "u1", store.ProfileUpdate{LastDonatedAt: &recent}); err != nil {
		t.Fatal(err)
	}
	view, err = env.svc.Profile(ctx, "u1")
	if err != nil {
		t.Fatal(err)
	}
	if view.Derived.Eligible || view.Derived.NextEligibleAt == nil {
		t.Fatalf("recent donation profile = %+v", view.Derived)
	}

	// Explicit unavailability always wins.
	empty := ""
	unavailable := false
	if err := env.st.UpdateProfile(ctx, "u1", store.ProfileUpdate{
		LastDonatedAt: &empty, Available: &unavailable,
	}); err != nil {
		t.Fatal(err)
	}
	view, err = env.svc.Profile(ctx, "u1")
	if err != nil || view.Derived.Eligible || view.Derived.NextEligibleAt != nil {
		t.Fatalf("unavailable profile = %+v, %v", view.Derived, err)
	}

	// Unknown age/weight stay permissive per addendum v2.
	group2 := "O+"
	createUser(t, env.st, store.User{ID: "u2", Name: "Bare", Role: "donor", BloodGroup: &group2, Available: true})
	view, err = env.svc.Profile(ctx, "u2")
	if err != nil || !view.Derived.Eligible {
		t.Fatalf("permissive profile = %+v, %v", view.Derived, err)
	}

	// Non-donors are never donor-eligible.
	createUser(t, env.st, store.User{ID: "u3", Name: "Ravi", Role: "requester", BloodGroup: &group2})
	view, err = env.svc.Profile(ctx, "u3")
	if err != nil || view.Derived.Eligible || view.Derived.NextEligibleAt != nil {
		t.Fatalf("requester profile = %+v, %v", view.Derived, err)
	}
}

func TestUpdateProfileValidationAndRoundTrip(t *testing.T) {
	env := newTestService(t)
	ctx := context.Background()
	group := "O+"
	createUser(t, env.st, store.User{
		ID: "u1", Name: "Asha", Role: "donor", BloodGroup: &group,
		Lat: 21.1, Lng: 79.1, WeightKG: floatPtr(58), Available: true,
	})

	for name, in := range map[string]ProfileInput{
		"lat":    {Lat: floatPtr(91)},
		"lng":    {Lng: floatPtr(-181)},
		"weight": {WeightKG: floatPtr(-1)},
		"height": {HeightCM: floatPtr(-1)},
		"date":   {LastDonatedAt: strPtr("yesterday")},
	} {
		t.Run(name, func(t *testing.T) {
			if _, err := env.svc.UpdateProfile(ctx, "u1", in); err == nil {
				t.Fatal("expected validation error")
			}
		})
	}

	last := "2026-01-01"
	view, err := env.svc.UpdateProfile(ctx, "u1", ProfileInput{
		Available: boolPtr(false), Lat: floatPtr(22), LastDonatedAt: &last,
	})
	if err != nil {
		t.Fatal(err)
	}
	if view.User.Available || view.User.Lat != 22 || view.User.Lng != 79.1 ||
		view.User.LastDonatedAt == nil || *view.User.LastDonatedAt != last ||
		view.User.WeightKG == nil || *view.User.WeightKG != 58 {
		t.Fatalf("updated user = %+v", view.User)
	}
	if view.Derived.Eligible {
		t.Error("unavailable donor must not be eligible")
	}

	cleared := ""
	view, err = env.svc.UpdateProfile(ctx, "u1", ProfileInput{LastDonatedAt: &cleared})
	if err != nil || view.User.LastDonatedAt != nil {
		t.Fatalf("cleared date = %+v, %v", view.User.LastDonatedAt, err)
	}
}

func TestRecordDonationIdempotentAndPublishes(t *testing.T) {
	env := newTestService(t)
	ctx := context.Background()
	group := "O+"
	createUser(t, env.st, store.User{ID: "u1", Name: "Asha", Role: "donor", BloodGroup: &group})
	createUser(t, env.st, store.User{ID: "u2", Name: "Ravi", Role: "requester", BloodGroup: &group})
	createRequest(t, env.st, store.Request{
		ID: "r1", RequesterID: "u2", BloodGroup: group, Units: 2,
		Hospital: "H", Urgency: "urgent", Status: "open", ChannelID: "reqr1",
	})

	var eventsSeen []events.DonationRecordedPayload
	env.bus.Subscribe(events.DonationRecorded, func(_ context.Context, event events.Event) {
		payload, ok := event.Payload.(events.DonationRecordedPayload)
		if ok {
			eventsSeen = append(eventsSeen, payload)
		}
	})

	// A joined donor without a row (legacy/seed path) gets one created.
	if err := env.st.AddRequestMember(ctx, "r1", "u1", "donor"); err != nil {
		t.Fatal(err)
	}
	first, err := env.svc.RecordDonation(ctx, "r1", "u1")
	if err != nil {
		t.Fatal(err)
	}
	if first.Donation.ID == "" || first.Donation.RequestID != "r1" || first.Donation.DonatedAt == "" ||
		first.DonationCount != 1 {
		t.Fatalf("first donation = %+v", first)
	}

	// A donor accept may already have written the row; a repeat must reuse it.
	second, err := env.svc.RecordDonation(ctx, "r1", "u1")
	if err != nil {
		t.Fatal(err)
	}
	if second.Donation.ID != first.Donation.ID || second.Donation.DonatedAt != first.Donation.DonatedAt ||
		second.DonationCount != 1 {
		t.Fatalf("repeat donation = %+v, want same row as %+v", second, first)
	}
	count, err := env.st.DonationCount(ctx, "u1")
	if err != nil || count != 1 {
		t.Fatalf("stored donations = %d, %v; want 1", count, err)
	}
	if len(eventsSeen) != 2 || eventsSeen[0].DonationID != first.Donation.ID ||
		eventsSeen[1].DonationCount != 1 {
		t.Fatalf("donation.recorded events = %+v", eventsSeen)
	}
}

func TestRecordDonationAuthorization(t *testing.T) {
	env := newTestService(t)
	ctx := context.Background()
	group := "O+"
	createUser(t, env.st, store.User{ID: "u1", Name: "Asha", Role: "donor", BloodGroup: &group})
	createUser(t, env.st, store.User{ID: "u2", Name: "Ravi", Role: "requester", BloodGroup: &group})
	createRequest(t, env.st, store.Request{
		ID: "r1", RequesterID: "u2", BloodGroup: group, Units: 2,
		Hospital: "H", Urgency: "urgent", Status: "open", ChannelID: "reqr1",
	})

	if _, err := env.svc.RecordDonation(ctx, "missing", "u1"); !errors.Is(err, store.ErrNotFound) {
		t.Fatalf("missing request error = %v, want ErrNotFound", err)
	}
	if _, err := env.svc.RecordDonation(ctx, "r1", "u1"); !errors.Is(err, ErrForbidden) {
		t.Fatalf("non-member error = %v, want ErrForbidden", err)
	}
	if err := env.st.AddRequestMember(ctx, "r1", "u2", "requester"); err != nil {
		t.Fatal(err)
	}
	if _, err := env.svc.RecordDonation(ctx, "r1", "u2"); !errors.Is(err, ErrForbidden) {
		t.Fatalf("requester error = %v, want ErrForbidden", err)
	}
}
