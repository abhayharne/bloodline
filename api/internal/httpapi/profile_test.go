package httpapi

import (
	"context"
	"encoding/json"
	"net/http"
	"testing"

	"bloodline/internal/events"
	"bloodline/internal/service"
)

func TestMeGetPutAndValidation(t *testing.T) {
	api := newTestAPI(t)
	id, token := signupForTest(t, api,
		`{"phone":"+955555555555","name":"Me Donor","role":"donor","blood_group":"O+",`+
			`"sex":"male","age":30,"weight_kg":60,"lat":21.1,"lng":79.1,"available":true,"consent":true}`)

	rec := api.doWithToken(t, http.MethodGet, "/me", "", token)
	if rec.Code != http.StatusOK {
		t.Fatalf("GET /me status = %d (body %s)", rec.Code, rec.Body.String())
	}
	var view service.ProfileView
	if err := json.Unmarshal(rec.Body.Bytes(), &view); err != nil {
		t.Fatal(err)
	}
	if view.User.ID != id || !view.Derived.Eligible || view.Derived.DonationCount != 0 ||
		view.Derived.NextEligibleAt != nil || view.Derived.Rank != nil {
		t.Fatalf("GET /me = %+v", view)
	}

	// Missing token and malformed JSON are rejected before the service layer.
	if rec := api.do(t, http.MethodGet, "/me", ""); rec.Code != http.StatusUnauthorized {
		t.Fatalf("GET /me without token = %d, want 401", rec.Code)
	}
	if rec := api.doWithToken(t, http.MethodPut, "/me", "{", token); rec.Code != http.StatusBadRequest {
		t.Fatalf("PUT /me malformed = %d, want 400", rec.Code)
	}
	for _, body := range []string{
		`{"lat":91}`,
		`{"lng":-181}`,
		`{"weight_kg":-1}`,
		`{"height_cm":-1}`,
		`{"last_donated_at":"yesterday"}`,
	} {
		if rec := api.doWithToken(t, http.MethodPut, "/me", body, token); rec.Code != http.StatusBadRequest {
			t.Fatalf("PUT /me %s = %d, want 400", body, rec.Code)
		}
	}

	updated := api.doWithToken(t, http.MethodPut, "/me",
		`{"available":false,"lat":22.5,"weight_kg":61,"last_donated_at":"2026-10-01","apheresis_ok":true}`, token)
	if updated.Code != http.StatusOK {
		t.Fatalf("PUT /me status = %d (body %s)", updated.Code, updated.Body.String())
	}
	view = service.ProfileView{}
	if err := json.Unmarshal(updated.Body.Bytes(), &view); err != nil {
		t.Fatal(err)
	}
	if view.User.Available || view.User.Lat != 22.5 || view.User.Lng != 79.1 ||
		view.User.WeightKG == nil || *view.User.WeightKG != 61 ||
		view.User.LastDonatedAt == nil || *view.User.LastDonatedAt != "2026-10-01" ||
		!view.User.ApheresisOK {
		t.Fatalf("PUT /me user = %+v", view.User)
	}
	if view.Derived.Eligible || view.Derived.NextEligibleAt == nil {
		t.Fatalf("PUT /me derived = %+v", view.Derived)
	}

	// The change is durable and the same shape is returned by GET.
	again := api.doWithToken(t, http.MethodGet, "/me", "", token)
	var reread service.ProfileView
	if err := json.Unmarshal(again.Body.Bytes(), &reread); err != nil {
		t.Fatal(err)
	}
	if reread.User.Lat != 22.5 || reread.User.Available || reread.Derived.NextEligibleAt == nil ||
		!reread.User.ApheresisOK {
		t.Fatalf("GET /me after PUT = %+v", reread)
	}
}

func TestDonatedEndpointIdempotentAndScoped(t *testing.T) {
	bus := events.New()
	api := newTestAPI(t, service.WithBus(bus))
	var seen []events.DonationRecordedPayload
	bus.Subscribe(events.DonationRecorded, func(_ context.Context, event events.Event) {
		if payload, ok := event.Payload.(events.DonationRecordedPayload); ok {
			seen = append(seen, payload)
		}
	})

	_, requesterToken := signupForTest(t, api, requesterSignup)
	donorID, donorToken := signupForTest(t, api, donorSignup)
	_, otherToken := signupForTest(t, api,
		`{"phone":"+966666666666","name":"Other Donor","role":"donor","blood_group":"O-","lat":21.15,"lng":79.09}`)
	created := createTestRequest(t, api, testUsers{requesterToken: requesterToken})
	path := "/requests/" + created.Request.ID

	if rec := api.doWithToken(t, http.MethodPost, path+"/accept", "", donorToken); rec.Code != http.StatusOK {
		t.Fatalf("accept status = %d (body %s)", rec.Code, rec.Body.String())
	}

	donated := api.doWithToken(t, http.MethodPost, path+"/donated", "", donorToken)
	if donated.Code != http.StatusCreated {
		t.Fatalf("POST /donated status = %d (body %s)", donated.Code, donated.Body.String())
	}
	var result service.DonationResult
	if err := json.Unmarshal(donated.Body.Bytes(), &result); err != nil {
		t.Fatal(err)
	}
	if result.Donation.ID == "" || result.Donation.RequestID != created.Request.ID ||
		result.Donation.DonatedAt == "" || result.DonationCount != 1 {
		t.Fatalf("donated result = %+v", result)
	}

	repeat := api.doWithToken(t, http.MethodPost, path+"/donated", "", donorToken)
	if repeat.Code != http.StatusCreated {
		t.Fatalf("repeat /donated status = %d", repeat.Code)
	}
	var again service.DonationResult
	if err := json.Unmarshal(repeat.Body.Bytes(), &again); err != nil {
		t.Fatal(err)
	}
	if again.Donation.ID != result.Donation.ID || again.Donation.DonatedAt != result.Donation.DonatedAt ||
		again.DonationCount != 1 {
		t.Fatalf("repeat donated result = %+v, want %+v", again, result)
	}

	me := api.doWithToken(t, http.MethodGet, "/me", "", donorToken)
	var view service.ProfileView
	if err := json.Unmarshal(me.Body.Bytes(), &view); err != nil {
		t.Fatal(err)
	}
	if view.User.ID != donorID || view.Derived.DonationCount != 1 {
		t.Fatalf("donor /me = %+v", view)
	}
	if len(seen) != 2 || seen[0].DonationID != result.Donation.ID || seen[1].DonationCount != 1 {
		t.Fatalf("donation.recorded events = %+v", seen)
	}

	// Only a joined donor may record, and the request must exist.
	if rec := api.doWithToken(t, http.MethodPost, path+"/donated", "", otherToken); rec.Code != http.StatusForbidden {
		t.Fatalf("non-member /donated = %d, want 403", rec.Code)
	}
	if rec := api.doWithToken(t, http.MethodPost, path+"/donated", "", requesterToken); rec.Code != http.StatusForbidden {
		t.Fatalf("requester /donated = %d, want 403", rec.Code)
	}
	if rec := api.doWithToken(t, http.MethodPost, "/requests/missing/donated", "", donorToken); rec.Code != http.StatusNotFound {
		t.Fatalf("missing request /donated = %d, want 404", rec.Code)
	}
	if rec := api.do(t, http.MethodPost, path+"/donated", ""); rec.Code != http.StatusUnauthorized {
		t.Fatalf("/donated without token = %d, want 401", rec.Code)
	}
}
