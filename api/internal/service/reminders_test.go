package service

import (
	"context"
	"testing"
	"time"

	"bloodline/internal/events"
	"bloodline/internal/store"
)

// TestRemindersFlagGatesDonorFilters checks that the isAvailable and isEligible
// pipeline is only applied when the reminders feature is on. The core path
// keeps using the store query, which already excludes unavailable donors.
func TestRemindersFlagGatesDonorFilters(t *testing.T) {
	group := "O-"
	recent := time.Now().AddDate(0, 0, -10).UTC().Format("2006-01-02")

	newEnv := func(t *testing.T, opts ...Option) *svcTest {
		env := newTestService(t, opts...)
		createUser(t, env.st, store.User{ID: "uReq", Name: "Ravi", Role: "requester", BloodGroup: &group, Lat: 21.14, Lng: 79.08})
		createUser(t, env.st, store.User{
			ID: "uReady", Name: "Ready", Role: "donor", BloodGroup: &group,
			Lat: 21.15, Lng: 79.09, Age: intPtr(30), WeightKG: floatPtr(60), Available: true,
		})
		createUser(t, env.st, store.User{
			ID: "uRecent", Name: "Recent", Role: "donor", BloodGroup: &group,
			Lat: 21.16, Lng: 79.10, Age: intPtr(30), WeightKG: floatPtr(60),
			Available: true, LastDonatedAt: &recent,
		})
		createUser(t, env.st, store.User{
			ID: "uOff", Name: "Offline", Role: "donor", BloodGroup: &group,
			Lat: 21.17, Lng: 79.11, Age: intPtr(30), WeightKG: floatPtr(60), Available: false,
		})
		return env
	}

	input := RequestInput{
		RequesterID: "uReq", RequesterName: "Ravi", BloodGroup: group,
		Units: 1, Hospital: "City Hospital", Urgency: "critical",
		Lat: 21.14, Lng: 79.08,
	}

	t.Run("flag off keeps core path", func(t *testing.T) {
		env := newEnv(t)
		var payloads []events.RequestCreatedPayload
		env.bus.Subscribe(events.RequestCreated, func(_ context.Context, e events.Event) {
			payloads = append(payloads, e.Payload.(events.RequestCreatedPayload))
		})
		result, err := env.svc.CreateRequest(context.Background(), input)
		if err != nil {
			t.Fatal(err)
		}
		if result.Donors != 2 {
			t.Fatalf("donors = %d, want 2 (available donors, eligibility unchecked)", result.Donors)
		}
		if len(payloads) != 1 || len(payloads[0].RecipientIDs) != 2 {
			t.Fatalf("request.created recipients = %+v, want 2 donors", payloads)
		}
		for _, id := range payloads[0].RecipientIDs {
			if id == "uOff" {
				t.Error("core path must not notify an unavailable donor")
			}
		}
	})

	t.Run("flag on applies availability and eligibility", func(t *testing.T) {
		env := newEnv(t, WithFeatures([]string{"reminders"}))
		var payloads []events.RequestCreatedPayload
		env.bus.Subscribe(events.RequestCreated, func(_ context.Context, e events.Event) {
			payloads = append(payloads, e.Payload.(events.RequestCreatedPayload))
		})
		result, err := env.svc.CreateRequest(context.Background(), input)
		if err != nil {
			t.Fatal(err)
		}
		if result.Donors != 1 {
			t.Fatalf("donors = %d, want 1 (only the eligible, available donor)", result.Donors)
		}
		if len(payloads) != 1 || len(payloads[0].RecipientIDs) != 1 || payloads[0].RecipientIDs[0] != "uReady" {
			t.Fatalf("request.created recipients = %+v, want [uReady]", payloads)
		}
	})
}

func intPtr(value int) *int { return &value }
