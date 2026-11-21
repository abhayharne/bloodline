package httpapi

import (
	"context"
	"encoding/json"
	"fmt"
	"net/http"
	"net/http/httptest"
	"strings"
	"testing"

	"bloodline/internal/events"
	"bloodline/internal/notify"
	"bloodline/internal/service"
)

const (
	requesterSignup = `{"phone":"+911111111111","name":"Ravi","role":"requester","blood_group":"O-","lat":21.1458,"lng":79.0882,"consent":true}`
	donorSignup     = `{"phone":"+922222222222","name":"Asha","role":"donor","blood_group":"O-","lat":21.15,"lng":79.09,"consent":true}`
	bankSignup      = `{"phone":"+933333333333","name":"City Bank","role":"bank","lat":21.148,"lng":79.085,"consent":true}`
	requestBody     = `{"blood_group":"O-","units":2,"hospital":"City Hospital","urgency":"critical","lat":21.16,"lng":79.10}`
)

type testUsers struct {
	requesterID, requesterToken string
	donorID, donorToken         string
	bankID, bankToken           string
}

func setupRequestAPI(t *testing.T) (*testAPI, testUsers) {
	t.Helper()
	bus := events.New()
	api := newTestAPI(t, service.WithBus(bus))
	notifier := notify.New(api.store)
	bus.Subscribe(events.RequestCreated, notifier.Handle)
	bus.Subscribe(events.RequestAccepted, notifier.Handle)
	bus.Subscribe(events.RequestFulfilled, notifier.Handle)

	signup := func(body string) (string, string) {
		rec := api.do(t, http.MethodPost, "/auth/signup", body)
		if rec.Code != http.StatusCreated {
			t.Fatalf("signup status = %d, want 201 (body %s)", rec.Code, rec.Body.String())
		}
		resp := decodeAuthResponse(t, rec)
		return resp.User.ID, resp.Token
	}
	users := testUsers{}
	users.requesterID, users.requesterToken = signup(requesterSignup)
	users.donorID, users.donorToken = signup(donorSignup)
	users.bankID, users.bankToken = signup(bankSignup)

	rec := api.doWithToken(t, http.MethodPut, "/banks/me/stock",
		`{"stock":[{"blood_group":"O-","units":2}]}`, users.bankToken)
	if rec.Code != http.StatusOK {
		t.Fatalf("bank stock status = %d, want 200 (body %s)", rec.Code, rec.Body.String())
	}
	return api, users
}

func createTestRequest(t *testing.T, api *testAPI, users testUsers) createRequestResponse {
	t.Helper()
	rec := api.doWithToken(t, http.MethodPost, "/requests", requestBody, users.requesterToken)
	if rec.Code != http.StatusCreated {
		t.Fatalf("create request status = %d, want 201 (body %s)", rec.Code, rec.Body.String())
	}
	var resp createRequestResponse
	if err := json.Unmarshal(rec.Body.Bytes(), &resp); err != nil {
		t.Fatalf("decode: %v (body %s)", err, rec.Body.String())
	}
	return resp
}

func decodeRequests(t *testing.T, rec *httptest.ResponseRecorder) requestsResponse {
	t.Helper()
	var resp requestsResponse
	if err := json.Unmarshal(rec.Body.Bytes(), &resp); err != nil {
		t.Fatalf("decode: %v (body %s)", err, rec.Body.String())
	}
	return resp
}

func TestCreateRequestCreatesRoomAndNotifiesMatches(t *testing.T) {
	api, users := setupRequestAPI(t)
	resp := createTestRequest(t, api, users)

	if !strings.HasPrefix(resp.Request.ID, "r") || resp.Request.ChannelID != "req"+resp.Request.ID {
		t.Errorf("ids = %q / %q", resp.Request.ID, resp.Request.ChannelID)
	}
	if resp.Request.Status != "open" || resp.Request.Hospital != "City Hospital" || resp.Request.Units != 2 {
		t.Errorf("request = %+v", resp.Request)
	}
	if resp.Matches.Banks != 1 || resp.Matches.Donors != 1 {
		t.Errorf("matches = %+v", resp.Matches)
	}
	if len(api.chat.created) != 1 || api.chat.created[0] != resp.Request.ChannelID {
		t.Errorf("created rooms = %v", api.chat.created)
	}

	items, err := api.store.Notifications(context.Background(), users.donorID)
	if err != nil {
		t.Fatal(err)
	}
	if len(items) != 1 || items[0].Type != events.RequestCreated {
		t.Fatalf("donor notifications = %+v", items)
	}
	bankItems, err := api.store.Notifications(context.Background(), users.bankID)
	if err != nil {
		t.Fatal(err)
	}
	if len(bankItems) != 1 || bankItems[0].Type != events.RequestCreated {
		t.Fatalf("bank notifications = %+v", bankItems)
	}

	joined, err := api.store.HasRequestMember(context.Background(), resp.Request.ID, users.requesterID)
	if err != nil || !joined {
		t.Errorf("requester joined = %v, err = %v", joined, err)
	}
}

func TestRequestFeedIsRoleAware(t *testing.T) {
	api, users := setupRequestAPI(t)
	created := createTestRequest(t, api, users)

	donorFeed := decodeRequests(t, api.doWithToken(t, http.MethodGet, "/requests", "", users.donorToken))
	if len(donorFeed.Requests) != 1 {
		t.Fatalf("donor feed = %+v", donorFeed.Requests)
	}
	if donorFeed.Requests[0].ID != created.Request.ID || donorFeed.Requests[0].RequesterName != "Ravi" {
		t.Errorf("donor row = %+v", donorFeed.Requests[0])
	}
	if donorFeed.Requests[0].DistanceKM <= 0 || donorFeed.Requests[0].Joined {
		t.Errorf("donor distance/joined = %v / %v", donorFeed.Requests[0].DistanceKM, donorFeed.Requests[0].Joined)
	}

	bankFeed := decodeRequests(t, api.doWithToken(t, http.MethodGet, "/requests", "", users.bankToken))
	if len(bankFeed.Requests) != 1 {
		t.Fatalf("bank feed = %+v", bankFeed.Requests)
	}

	requesterFeed := decodeRequests(t, api.doWithToken(t, http.MethodGet, "/requests", "", users.requesterToken))
	if len(requesterFeed.Requests) != 1 || requesterFeed.Requests[0].RequesterID != users.requesterID {
		t.Errorf("requester feed = %+v", requesterFeed.Requests)
	}

	other := newTestAPI(t)
	otherID, otherToken := signupForTest(t, other,
		`{"phone":"+944444444444","name":"Other","role":"donor","blood_group":"A+","lat":21.15,"lng":79.09}`)
	_ = otherID
	otherFeed := decodeRequests(t, other.doWithToken(t, http.MethodGet, "/requests", "", otherToken))
	if len(otherFeed.Requests) != 0 {
		t.Errorf("non-matching donor feed = %+v", otherFeed.Requests)
	}
}

func signupForTest(t *testing.T, api *testAPI, body string) (string, string) {
	t.Helper()
	rec := api.do(t, http.MethodPost, "/auth/signup", body)
	if rec.Code != http.StatusCreated {
		t.Fatalf("signup status = %d (body %s)", rec.Code, rec.Body.String())
	}
	resp := decodeAuthResponse(t, rec)
	return resp.User.ID, resp.Token
}

func TestAcceptAndFulfillRequest(t *testing.T) {
	api, users := setupRequestAPI(t)
	created := createTestRequest(t, api, users)
	path := fmt.Sprintf("/requests/%s", created.Request.ID)

	accept := api.doWithToken(t, http.MethodPost, path+"/accept", "", users.donorToken)
	if accept.Code != http.StatusOK {
		t.Fatalf("accept status = %d, want 200 (body %s)", accept.Code, accept.Body.String())
	}
	var accepted acceptResponse
	if err := json.Unmarshal(accept.Body.Bytes(), &accepted); err != nil {
		t.Fatal(err)
	}
	if accepted.ChannelID != created.Request.ChannelID {
		t.Errorf("channel_id = %q, want %q", accepted.ChannelID, created.Request.ChannelID)
	}
	if len(api.chat.joined) != 1 {
		t.Errorf("joined rooms = %v", api.chat.joined)
	}
	joined, err := api.store.HasRequestMember(context.Background(), created.Request.ID, users.donorID)
	if err != nil || !joined {
		t.Errorf("donor member = %v, err = %v", joined, err)
	}
	requesterItems, err := api.store.Notifications(context.Background(), users.requesterID)
	if err != nil {
		t.Fatal(err)
	}
	if len(requesterItems) != 1 || requesterItems[0].Type != events.RequestAccepted {
		t.Fatalf("requester notifications = %+v", requesterItems)
	}

	// Repeat accept is idempotent: no second join, no second event.
	if rec := api.doWithToken(t, http.MethodPost, path+"/accept", "", users.donorToken); rec.Code != http.StatusOK {
		t.Fatalf("repeat accept status = %d", rec.Code)
	}
	if len(api.chat.joined) != 1 {
		t.Errorf("repeat accept joined again: %v", api.chat.joined)
	}

	fulfill := api.doWithToken(t, http.MethodPost, path+"/fulfill", "", users.requesterToken)
	if fulfill.Code != http.StatusOK {
		t.Fatalf("fulfill status = %d, want 200 (body %s)", fulfill.Code, fulfill.Body.String())
	}
	var fulfilled fulfillResponse
	if err := json.Unmarshal(fulfill.Body.Bytes(), &fulfilled); err != nil {
		t.Fatal(err)
	}
	if fulfilled.Request.Status != "fulfilled" {
		t.Errorf("status = %q, want fulfilled", fulfilled.Request.Status)
	}
	if len(api.chat.messages) != 1 || len(api.chat.frozen) != 1 {
		t.Errorf("chat messages = %v, frozen = %v", api.chat.messages, api.chat.frozen)
	}
	donorItems, err := api.store.Notifications(context.Background(), users.donorID)
	if err != nil {
		t.Fatal(err)
	}
	foundFulfilled := false
	for _, item := range donorItems {
		if item.Type == events.RequestFulfilled {
			foundFulfilled = true
		}
	}
	if !foundFulfilled {
		t.Errorf("donor notifications = %+v, want request.fulfilled", donorItems)
	}

	open := decodeRequests(t, api.doWithToken(t, http.MethodGet, "/requests?status=open", "", users.donorToken))
	if len(open.Requests) != 0 {
		t.Errorf("open feed after fulfill = %+v", open.Requests)
	}
	if rec := api.doWithToken(t, http.MethodPost, path+"/accept", "", users.donorToken); rec.Code != http.StatusConflict {
		t.Errorf("accept after fulfill status = %d, want 409", rec.Code)
	}
}

func TestRequestRoleAndValidationRules(t *testing.T) {
	api, users := setupRequestAPI(t)

	// Donor cannot create; requester cannot accept; donor cannot fulfill.
	if rec := api.doWithToken(t, http.MethodPost, "/requests", requestBody, users.donorToken); rec.Code != http.StatusForbidden {
		t.Errorf("donor create status = %d, want 403", rec.Code)
	}
	created := createTestRequest(t, api, users)
	path := fmt.Sprintf("/requests/%s", created.Request.ID)
	if rec := api.doWithToken(t, http.MethodPost, path+"/accept", "", users.requesterToken); rec.Code != http.StatusForbidden {
		t.Errorf("requester accept status = %d, want 403", rec.Code)
	}
	if rec := api.doWithToken(t, http.MethodPost, path+"/fulfill", "", users.donorToken); rec.Code != http.StatusForbidden {
		t.Errorf("donor fulfill status = %d, want 403", rec.Code)
	}

	for _, body := range []string{
		`{"blood_group":"Z+","units":1,"hospital":"H","urgency":"urgent"}`,
		`{"blood_group":"O-","units":0,"hospital":"H","urgency":"urgent"}`,
		`{"blood_group":"O-","units":1,"hospital":"","urgency":"urgent"}`,
		`{"blood_group":"O-","units":1,"hospital":"H","urgency":"whenever"}`,
		`{`,
	} {
		rec := api.doWithToken(t, http.MethodPost, "/requests", body, users.requesterToken)
		if rec.Code != http.StatusBadRequest {
			t.Errorf("body %s: status = %d, want 400", body, rec.Code)
		}
	}
	if rec := api.doWithToken(t, http.MethodGet, "/requests?status=bogus", "", users.requesterToken); rec.Code != http.StatusBadRequest {
		t.Errorf("bad status filter = %d, want 400", rec.Code)
	}
	if rec := api.doWithToken(t, http.MethodPost, "/requests/missing/accept", "", users.donorToken); rec.Code != http.StatusNotFound {
		t.Errorf("missing request accept = %d, want 404", rec.Code)
	}
}
