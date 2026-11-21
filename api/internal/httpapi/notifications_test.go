package httpapi

import (
	"context"
	"encoding/json"
	"net/http"
	"testing"

	"bloodline/internal/events"
	"bloodline/internal/notify"
	"bloodline/internal/service"
	"bloodline/internal/store"
)

func TestNotificationsRequiresAuth(t *testing.T) {
	api := newTestAPI(t)
	if rec := api.do(t, http.MethodGet, "/notifications", ""); rec.Code != http.StatusUnauthorized {
		t.Errorf("no token: status = %d, want 401", rec.Code)
	}
	if rec := api.doWithToken(t, http.MethodGet, "/notifications", "", "bad-token"); rec.Code != http.StatusUnauthorized {
		t.Errorf("bad token: status = %d, want 401", rec.Code)
	}
}

func TestNotificationsEmptyForNewUser(t *testing.T) {
	api := newTestAPI(t)
	rec := api.do(t, http.MethodPost, "/auth/signup", donorSignupBody)
	token := decodeAuthResponse(t, rec).Token

	got := api.doWithToken(t, http.MethodGet, "/notifications", "", token)
	if got.Code != http.StatusOK {
		t.Fatalf("status = %d, want 200 (body %s)", got.Code, got.Body.String())
	}
	var body notificationsResponse
	if err := json.Unmarshal(got.Body.Bytes(), &body); err != nil {
		t.Fatalf("decode: %v", err)
	}
	if len(body.Notifications) != 0 {
		t.Errorf("notifications = %+v, want empty", body.Notifications)
	}
}

func TestNotificationsFromEventThroughAPI(t *testing.T) {
	bus := events.New()
	api := newTestAPI(t, service.WithBus(bus))
	notifier := notify.New(api.store)
	bus.Subscribe(events.RequestCreated, notifier.Handle)

	signup := api.do(t, http.MethodPost, "/auth/signup", donorSignupBody)
	user := decodeAuthResponse(t, signup)

	api.svc.Publish(context.Background(), events.RequestCreated, events.RequestCreatedPayload{
		RequestID:    "r1",
		BloodGroup:   "O+",
		Hospital:     "City Hospital",
		Units:        1,
		RecipientIDs: []string{user.User.ID},
	})

	got := api.doWithToken(t, http.MethodGet, "/notifications", "", user.Token)
	if got.Code != http.StatusOK {
		t.Fatalf("status = %d, want 200 (body %s)", got.Code, got.Body.String())
	}
	var body notificationsResponse
	if err := json.Unmarshal(got.Body.Bytes(), &body); err != nil {
		t.Fatalf("decode: %v", err)
	}
	if len(body.Notifications) != 1 || body.Notifications[0].Type != events.RequestCreated {
		t.Fatalf("notifications = %+v", body.Notifications)
	}
	if body.Notifications[0].UserID != user.User.ID || body.Notifications[0].RequestID == nil {
		t.Errorf("notification = %+v", body.Notifications[0])
	}
}

func TestNotificationsArePerUser(t *testing.T) {
	api := newTestAPI(t)
	_ = api.store.InsertNotification(context.Background(), store.Notification{
		ID: "n1", UserID: "u1", Type: events.RequestCreated, Title: "t", Body: "b",
	})
	_ = api.store.InsertNotification(context.Background(), store.Notification{
		ID: "n2", UserID: "u2", Type: events.RequestCreated, Title: "t", Body: "b",
	})

	items, err := api.store.Notifications(context.Background(), "u1")
	if err != nil {
		t.Fatal(err)
	}
	if len(items) != 1 || items[0].ID != "n1" {
		t.Errorf("u1 notifications = %+v", items)
	}
}
