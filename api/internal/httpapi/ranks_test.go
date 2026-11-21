package httpapi

import (
	"context"
	"encoding/json"
	"net/http"
	"testing"

	"bloodline/internal/events"
	"bloodline/internal/ranks"
	"bloodline/internal/service"
)

func TestRanksFeatureFlagGatesMeAndNotification(t *testing.T) {
	// Without ranks flag, /me rank stays null and no rank_up notification.
	apiOff := newTestAPI(t)
	_, donorTokenOff := signupForTest(t, apiOff, donorSignup)
	_, reqTokenOff := signupForTest(t, apiOff, requesterSignup)
	createdOff := createTestRequest(t, apiOff, testUsers{requesterToken: reqTokenOff})
	pathOff := "/requests/" + createdOff.Request.ID + "/donated"
	if rec := apiOff.doWithToken(t, http.MethodPost, "/requests/"+createdOff.Request.ID+"/accept", "", donorTokenOff); rec.Code != 200 {
		t.Fatalf("accept off=%d", rec.Code)
	}
	if rec := apiOff.doWithToken(t, http.MethodPost, pathOff, "", donorTokenOff); rec.Code != 201 {
		t.Fatalf("donated off=%d body=%s", rec.Code, rec.Body.String())
	}
	meOff := apiOff.doWithToken(t, http.MethodGet, "/me", "", donorTokenOff)
	var viewOff service.ProfileView
	_ = json.Unmarshal(meOff.Body.Bytes(), &viewOff)
	if viewOff.Derived.Rank != nil {
		t.Fatalf("rank off = %+v, want nil", viewOff.Derived.Rank)
	}

	// With ranks flag on, rank computed and rank_up notification emitted.
	bus := events.New()
	apiOn := newTestAPI(t, service.WithBus(bus), service.WithFeatures([]string{"ranks"}))
	bus.Subscribe(events.DonationRecorded, ranks.New(apiOn.store).Handle)
	_, donorTokenOn := signupForTest(t, apiOn, donorSignup)
	_, reqTokenOn := signupForTest(t, apiOn, requesterSignup)
	createdOn := createTestRequest(t, apiOn, testUsers{requesterToken: reqTokenOn})
	if rec := apiOn.doWithToken(t, http.MethodPost, "/requests/"+createdOn.Request.ID+"/accept", "", donorTokenOn); rec.Code != 200 {
		t.Fatalf("accept on=%d", rec.Code)
	}
	if rec := apiOn.doWithToken(t, http.MethodPost, "/requests/"+createdOn.Request.ID+"/donated", "", donorTokenOn); rec.Code != 201 {
		t.Fatalf("donated on=%d body=%s", rec.Code, rec.Body.String())
	}
	meOn := apiOn.doWithToken(t, http.MethodGet, "/me", "", donorTokenOn)
	var viewOn service.ProfileView
	_ = json.Unmarshal(meOn.Body.Bytes(), &viewOn)
	if viewOn.Derived.Rank == nil || viewOn.Derived.Rank.Key != "first_drop" || viewOn.Derived.Rank.Label != "First Drop" {
		t.Fatalf("rank on = %+v", viewOn.Derived.Rank)
	}
	// Check notification feed for rank_up
	notifs, err := apiOn.store.Notifications(context.Background(), viewOn.User.ID)
	if err != nil {
		t.Fatal(err)
	}
	found := false
	for _, n := range notifs {
		if n.Type == "rank_up" && n.Body == "1 donations. You're now a First Drop." {
			found = true
		}
	}
	if !found {
		t.Fatalf("notifications=%+v, want rank_up", notifs)
	}
}
