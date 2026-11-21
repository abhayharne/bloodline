package httpapi

import (
	"context"
	"errors"
	"net/http"
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
	api := newDevTestAPI(t, WithDevRoutes())

	signup := api.do(t, http.MethodPost, "/auth/signup",
		`{"name":"Temp","role":"donor","blood_group":"O+","phone":"+919999900009"}`)
	if signup.Code != http.StatusCreated {
		t.Fatalf("signup status = %d, want 201 (body %s)", signup.Code, signup.Body.String())
	}

	// Reset twice to prove idempotence.
	for i := 0; i < 2; i++ {
		rec := api.do(t, http.MethodPost, "/dev/reset", "")
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
