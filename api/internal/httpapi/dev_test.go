package httpapi

import (
	"context"
	"encoding/json"
	"errors"
	"net/http"
	"net/http/httptest"
	"path/filepath"
	"testing"
	"time"

	"bloodline/internal/auth"
	"bloodline/internal/service"
	"bloodline/internal/store"
)

func newDevTestAPI(t *testing.T, opts ...ServerOption) *testAPI {
	t.Helper()

	st, err := store.Open(filepath.Join(t.TempDir(), "dev.db"))
	if err != nil {
		t.Fatalf("store.Open: %v", err)
	}
	t.Cleanup(func() { st.Close() })

	chat := &fakeChat{token: "chat-token"}
	issuer, err := auth.NewIssuer("test-secret", time.Hour)
	if err != nil {
		t.Fatalf("auth.NewIssuer: %v", err)
	}
	svc := service.New(st, chat, issuer)
	return &testAPI{
		handler: New(svc, issuer, opts...),
		store:   st,
		chat:    chat,
		issuer:  issuer,
		svc:     svc,
	}
}

func TestDevResetRouteIsDevOnly(t *testing.T) {
	api := newDevTestAPI(t)
	rec := api.do(t, http.MethodPost, "/dev/reset", "")
	if rec.Code != http.StatusNotFound {
		t.Fatalf("status = %d, want 404 when dev routes are off", rec.Code)
	}
}

func TestDevResetLoadsSeedAndClearsPriorData(t *testing.T) {
	api := newDevTestAPI(t, WithDevRoutes(), WithDevKey("test-dev-key"))

	signup := api.do(t, http.MethodPost, "/auth/signup",
		`{"name":"Temp","role":"donor","blood_group":"O+","phone":"+919999900009"}`)
	if signup.Code != http.StatusCreated {
		t.Fatalf("signup status = %d, want 201 (body %s)", signup.Code, signup.Body.String())
	}

	// Reset twice to prove idempotence.
	for i := 0; i < 2; i++ {
		request := httptest.NewRequest(http.MethodPost, "/dev/reset", nil)
		request.Header.Set("X-Dev-Key", "test-dev-key")
		rec := httptest.NewRecorder()
		api.handler.ServeHTTP(rec, request)
		if rec.Code != http.StatusOK {
			t.Fatalf("reset #%d status = %d, want 200 (body %s)", i+1, rec.Code, rec.Body.String())
		}
	}

	ctx := context.Background()
	if _, err := api.store.UserByPhone(ctx, "+919999900002"); err != nil {
		t.Errorf("seeded Asha not found after reset: %v", err)
	}
	if _, err := api.store.UserByPhone(ctx, "+919999900009"); !errors.Is(err, store.ErrNotFound) {
		t.Errorf("temporary user survived reset: %v", err)
	}
	req, err := api.store.RequestByID(ctx, "rseed1")
	if err != nil {
		t.Fatalf("seeded request missing: %v", err)
	}
	if req.Status != "open" || req.ChannelID != "reqrseed1" {
		t.Errorf("seeded request = %+v", req)
	}
}

type stubRunner struct {
	calls int
	sent  int
	err   error
}

func (r *stubRunner) RunEligibilityChecks(context.Context) (int, error) {
	r.calls++
	return r.sent, r.err
}

func TestDevRunRemindersRouteIsDevOnly(t *testing.T) {
	api := newDevTestAPI(t, WithReminderRunner(&stubRunner{}))
	rec := api.do(t, http.MethodPost, "/dev/run-reminders", "")
	if rec.Code != http.StatusNotFound {
		t.Fatalf("status = %d, want 404 when dev routes are off", rec.Code)
	}
}

func TestDevRunRemindersRunsScanAndReportsCount(t *testing.T) {
	runner := &stubRunner{sent: 2}
	api := newDevTestAPI(t, WithDevRoutes(), WithReminderRunner(runner))
	rec := api.do(t, http.MethodPost, "/dev/run-reminders", "")
	if rec.Code != http.StatusOK {
		t.Fatalf("status = %d, want 200 (body %s)", rec.Code, rec.Body.String())
	}
	if runner.calls != 1 {
		t.Fatalf("scan calls = %d, want 1", runner.calls)
	}
	var body struct {
		Status string `json:"status"`
		Sent   int    `json:"sent"`
	}
	if err := json.Unmarshal(rec.Body.Bytes(), &body); err != nil {
		t.Fatal(err)
	}
	if body.Status != "ok" || body.Sent != 2 {
		t.Fatalf("body = %+v, want status ok and sent 2", body)
	}
}

func TestDevRunRemindersWithoutRunnerIsNotFound(t *testing.T) {
	api := newDevTestAPI(t, WithDevRoutes())
	rec := api.do(t, http.MethodPost, "/dev/run-reminders", "")
	if rec.Code != http.StatusNotFound {
		t.Fatalf("status = %d, want 404 without a reminders runner", rec.Code)
	}
}

func TestDevResetRejectsMissingWrongAndUnconfiguredKey(t *testing.T) {
	for _, tc := range []struct{ name, configured, supplied string }{
		{"missing", "private-test-key", ""}, {"wrong", "private-test-key", "wrong"},
		{"unconfigured", "", ""}, {"unconfigured supplied", "", "anything"},
	} {
		t.Run(tc.name, func(t *testing.T) {
			api := newDevTestAPI(t, WithDevRoutes(), WithDevKey(tc.configured))
			req := httptest.NewRequest(http.MethodPost, "/dev/reset", nil)
			req.Header.Set("X-Dev-Key", tc.supplied)
			rec := httptest.NewRecorder()
			api.handler.ServeHTTP(rec, req)
			if rec.Code != http.StatusForbidden {
				t.Fatalf("status=%d want 403", rec.Code)
			}
			if _, err := api.store.UserByPhone(context.Background(), "+919999900002"); !errors.Is(err, store.ErrNotFound) {
				t.Fatalf("rejected reset changed data: %v", err)
			}
		})
	}
}
