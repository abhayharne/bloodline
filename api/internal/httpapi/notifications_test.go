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

func TestNotificationsExposeReadBool(t *testing.T) {
	api := newTestAPI(t)
	signup := api.do(t, http.MethodPost, "/auth/signup", donorSignupBody)
	user := decodeAuthResponse(t, signup)

	if err := api.store.InsertNotification(context.Background(), store.Notification{
		ID: "n1", UserID: user.User.ID, Type: events.RequestCreated, Title: "t", Body: "b",
	}); err != nil {
		t.Fatal(err)
	}
	if err := api.store.InsertNotification(context.Background(), store.Notification{
		ID: "n2", UserID: user.User.ID, Type: events.RequestAccepted, Title: "t", Body: "b",
	}); err != nil {
		t.Fatal(err)
	}
	if err := api.store.MarkNotificationRead(context.Background(), "n2", user.User.ID); err != nil {
		t.Fatal(err)
	}

	got := api.doWithToken(t, http.MethodGet, "/notifications", "", user.Token)
	var body notificationsResponse
	if err := json.Unmarshal(got.Body.Bytes(), &body); err != nil {
		t.Fatal(err)
	}
	byID := make(map[string]bool, len(body.Notifications))
	for _, n := range body.Notifications {
		byID[n.ID] = n.Read
	}
	if byID["n1"] || !byID["n2"] {
		t.Errorf("read flags = %v, want n1=false n2=true", byID)
	}
}

func TestMarkNotificationReadEndpoint(t *testing.T) {
	api := newTestAPI(t)
	signup := api.do(t, http.MethodPost, "/auth/signup", donorSignupBody)
	user := decodeAuthResponse(t, signup)
	if err := api.store.InsertNotification(context.Background(), store.Notification{
		ID: "n1", UserID: user.User.ID, Type: events.RequestCreated, Title: "t", Body: "b",
	}); err != nil {
		t.Fatal(err)
	}

	rec := api.doWithToken(t, http.MethodPost, "/notifications/n1/read", "", user.Token)
	if rec.Code != http.StatusNoContent {
		t.Fatalf("status = %d, want 204 (body %s)", rec.Code, rec.Body.String())
	}
	// Idempotent: a second mark is still a 204.
	if rec := api.doWithToken(t, http.MethodPost, "/notifications/n1/read", "", user.Token); rec.Code != http.StatusNoContent {
		t.Fatalf("second mark status = %d, want 204", rec.Code)
	}

	items, err := api.store.Notifications(context.Background(), user.User.ID)
	if err != nil {
		t.Fatal(err)
	}
	if len(items) != 1 || !items[0].Read {
		t.Fatalf("notification = %+v, want read", items)
	}
}

func TestMarkNotificationReadRequiresAuth(t *testing.T) {
	api := newTestAPI(t)
	if rec := api.do(t, http.MethodPost, "/notifications/n1/read", ""); rec.Code != http.StatusUnauthorized {
		t.Errorf("no token: status = %d, want 401", rec.Code)
	}
	if rec := api.doWithToken(t, http.MethodPost, "/notifications/n1/read", "", "bad-token"); rec.Code != http.StatusUnauthorized {
		t.Errorf("bad token: status = %d, want 401", rec.Code)
	}
}

func TestMarkNotificationReadIsOwnerScopedOverHTTP(t *testing.T) {
	api := newTestAPI(t)
	signup := api.do(t, http.MethodPost, "/auth/signup", donorSignupBody)
	user := decodeAuthResponse(t, signup)
	if err := api.store.InsertNotification(context.Background(), store.Notification{
		ID: "n1", UserID: user.User.ID, Type: events.RequestCreated, Title: "t", Body: "b",
	}); err != nil {
		t.Fatal(err)
	}

	// A different valid user must not be able to mark someone else's row,
	// nor probe for it (missing and not-owned both look like 404).
	other := api.do(t, http.MethodPost, "/auth/signup",
		`{"phone":"+919999900002","name":"Other","role":"donor","blood_group":"O-","consent":true}`)
	otherToken := decodeAuthResponse(t, other).Token
	if rec := api.doWithToken(t, http.MethodPost, "/notifications/n1/read", "", otherToken); rec.Code != http.StatusNotFound {
		t.Errorf("not owned: status = %d, want 404", rec.Code)
	}
	if rec := api.doWithToken(t, http.MethodPost, "/notifications/does-not-exist/read", "", otherToken); rec.Code != http.StatusNotFound {
		t.Errorf("missing: status = %d, want 404", rec.Code)
	}

	items, err := api.store.Notifications(context.Background(), user.User.ID)
	if err != nil {
		t.Fatal(err)
	}
	if len(items) != 1 || items[0].Read {
		t.Fatalf("notification = %+v, want still unread", items)
	}
}
