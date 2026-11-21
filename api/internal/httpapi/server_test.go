package httpapi

import (
	"context"
	"encoding/json"
	"errors"
	"net/http"
	"net/http/httptest"
	"path/filepath"
	"regexp"
	"strings"
	"testing"
	"time"

	"bloodline/internal/auth"
	"bloodline/internal/service"
	"bloodline/internal/store"
)

type fakeChat struct {
	token  string
	err    error
	issued []string
}

func (f *fakeChat) IssueToken(_ context.Context, userID, name string) (string, error) {
	f.issued = append(f.issued, userID+"|"+name)
	if f.err != nil {
		return "", f.err
	}
	return f.token, nil
}

func (f *fakeChat) CreateGroupChannel(context.Context, string, string, string, []string) error {
	return nil
}

func (f *fakeChat) JoinGroupChannel(context.Context, string, []string) error {
	return nil
}

type testAPI struct {
	handler http.Handler
	store   *store.Store
	chat    *fakeChat
	issuer  *auth.Issuer
}

func newTestAPI(t *testing.T) *testAPI {
	t.Helper()

	st, err := store.Open(filepath.Join(t.TempDir(), "test.db"))
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
		handler: New(svc, issuer),
		store:   st,
		chat:    chat,
		issuer:  issuer,
	}
}

func (a *testAPI) do(t *testing.T, method, path, body string) *httptest.ResponseRecorder {
	t.Helper()
	return a.doWithToken(t, method, path, body, "")
}

func (a *testAPI) doWithToken(t *testing.T, method, path, body, token string) *httptest.ResponseRecorder {
	t.Helper()
	var req *http.Request
	if body == "" {
		req = httptest.NewRequest(method, path, nil)
	} else {
		req = httptest.NewRequest(method, path, strings.NewReader(body))
	}
	if token != "" {
		req.Header.Set("Authorization", "Bearer "+token)
	}
	rec := httptest.NewRecorder()
	a.handler.ServeHTTP(rec, req)
	return rec
}

func decodeAuthResponse(t *testing.T, rec *httptest.ResponseRecorder) authResponse {
	t.Helper()
	var resp authResponse
	if err := json.Unmarshal(rec.Body.Bytes(), &resp); err != nil {
		t.Fatalf("decode auth response: %v (body %s)", err, rec.Body.String())
	}
	return resp
}

func TestHealth(t *testing.T) {
	api := newTestAPI(t)
	rec := api.do(t, http.MethodGet, "/health", "")

	if rec.Code != http.StatusOK {
		t.Fatalf("status = %d, want 200", rec.Code)
	}
	if got := rec.Header().Get("Content-Type"); got != "application/json" {
		t.Errorf("Content-Type = %q, want application/json", got)
	}
	var body map[string]string
	if err := json.Unmarshal(rec.Body.Bytes(), &body); err != nil {
		t.Fatalf("decode body: %v", err)
	}
	if body["status"] != "ok" {
		t.Errorf("status = %q, want ok", body["status"])
	}
}

func TestSignupReturnsTokensAndAlphanumericID(t *testing.T) {
	api := newTestAPI(t)
	rec := api.do(t, http.MethodPost, "/auth/signup",
		`{"name":"Asha","role":"donor","blood_group":"O+","lat":21.1458,"lng":79.0882}`)

	if rec.Code != http.StatusCreated {
		t.Fatalf("status = %d, want 201 (body %s)", rec.Code, rec.Body.String())
	}
	resp := decodeAuthResponse(t, rec)
	if !regexp.MustCompile(`^[A-Za-z0-9]+$`).MatchString(resp.User.ID) {
		t.Errorf("user id %q is not alphanumeric", resp.User.ID)
	}
	if resp.User.Name != "Asha" || resp.User.Role != "donor" {
		t.Errorf("user = %+v", resp.User)
	}
	if resp.User.BloodGroup == nil || *resp.User.BloodGroup != "O+" {
		t.Errorf("blood_group = %v, want O+", resp.User.BloodGroup)
	}
	if resp.Token == "" {
		t.Error("token is empty")
	}
	if resp.NexconnToken != "chat-token" {
		t.Errorf("nexconn_token = %q, want chat-token", resp.NexconnToken)
	}
	if len(api.chat.issued) != 1 || api.chat.issued[0] != resp.User.ID+"|Asha" {
		t.Errorf("Nexconn token issued for %v, want %s|Asha", api.chat.issued, resp.User.ID)
	}

	claims, err := api.issuer.Parse(resp.Token)
	if err != nil {
		t.Fatalf("parse app token: %v", err)
	}
	if claims.Subject != resp.User.ID || claims.Role != "donor" {
		t.Errorf("claims = %+v", claims)
	}
}

func TestSignupBankOmitsBloodGroup(t *testing.T) {
	api := newTestAPI(t)
	rec := api.do(t, http.MethodPost, "/auth/signup",
		`{"name":"City Blood Bank","role":"bank","lat":21.148,"lng":79.085}`)

	if rec.Code != http.StatusCreated {
		t.Fatalf("status = %d, want 201 (body %s)", rec.Code, rec.Body.String())
	}
	resp := decodeAuthResponse(t, rec)
	if resp.User.BloodGroup != nil {
		t.Errorf("bank blood_group = %v, want null", resp.User.BloodGroup)
	}
}

func TestSignupValidation(t *testing.T) {
	tests := []struct {
		name string
		body string
	}{
		{name: "missing name", body: `{"role":"donor","blood_group":"O+"}`},
		{name: "bad role", body: `{"name":"X","role":"admin"}`},
		{name: "donor missing group", body: `{"name":"X","role":"donor"}`},
		{name: "donor bad group", body: `{"name":"X","role":"donor","blood_group":"Z+"}`},
		{name: "bank with group", body: `{"name":"X","role":"bank","blood_group":"O+"}`},
		{name: "invalid json", body: `{`},
	}

	for _, tc := range tests {
		t.Run(tc.name, func(t *testing.T) {
			api := newTestAPI(t)
			rec := api.do(t, http.MethodPost, "/auth/signup", tc.body)
			if rec.Code != http.StatusBadRequest {
				t.Fatalf("status = %d, want 400 (body %s)", rec.Code, rec.Body.String())
			}
			var body map[string]string
			if err := json.Unmarshal(rec.Body.Bytes(), &body); err != nil {
				t.Fatalf("decode error body: %v", err)
			}
			if body["error"] == "" {
				t.Error("error message is empty")
			}
		})
	}
}

func TestSignupConflict(t *testing.T) {
	api := newTestAPI(t)
	body := `{"name":"Ravi","role":"requester","blood_group":"O-"}`

	if rec := api.do(t, http.MethodPost, "/auth/signup", body); rec.Code != http.StatusCreated {
		t.Fatalf("first signup status = %d, want 201", rec.Code)
	}
	rec := api.do(t, http.MethodPost, "/auth/signup", body)
	if rec.Code != http.StatusConflict {
		t.Fatalf("second signup status = %d, want 409 (body %s)", rec.Code, rec.Body.String())
	}
}

func TestLoginReturnsFreshTokens(t *testing.T) {
	api := newTestAPI(t)
	signup := api.do(t, http.MethodPost, "/auth/signup",
		`{"name":"Imran","role":"donor","blood_group":"O-","lat":21.13,"lng":79.07}`)
	if signup.Code != http.StatusCreated {
		t.Fatalf("signup status = %d", signup.Code)
	}
	signupResp := decodeAuthResponse(t, signup)

	rec := api.do(t, http.MethodPost, "/auth/login", `{"name":"Imran","role":"donor"}`)
	if rec.Code != http.StatusOK {
		t.Fatalf("login status = %d, want 200 (body %s)", rec.Code, rec.Body.String())
	}
	resp := decodeAuthResponse(t, rec)
	if resp.User.ID != signupResp.User.ID {
		t.Errorf("login user id = %q, want %q", resp.User.ID, signupResp.User.ID)
	}
	if resp.Token == "" || resp.NexconnToken != "chat-token" {
		t.Errorf("login tokens = %q / %q", resp.Token, resp.NexconnToken)
	}
	if len(api.chat.issued) != 2 {
		t.Errorf("Nexconn token issued %d times, want 2 (signup + login)", len(api.chat.issued))
	}
}

func TestLoginUnknownUser(t *testing.T) {
	api := newTestAPI(t)
	rec := api.do(t, http.MethodPost, "/auth/login", `{"name":"Nobody","role":"donor"}`)

	if rec.Code != http.StatusNotFound {
		t.Fatalf("status = %d, want 404 (body %s)", rec.Code, rec.Body.String())
	}
	var body map[string]string
	if err := json.Unmarshal(rec.Body.Bytes(), &body); err != nil {
		t.Fatalf("decode error body: %v", err)
	}
	if body["error"] == "" {
		t.Error("error message is empty")
	}
}

func TestSignupChatFailure(t *testing.T) {
	api := newTestAPI(t)
	api.chat.err = errors.New("nexconn down")

	rec := api.do(t, http.MethodPost, "/auth/signup",
		`{"name":"Priya","role":"donor","blood_group":"O+"}`)
	if rec.Code != http.StatusInternalServerError {
		t.Fatalf("status = %d, want 500 (body %s)", rec.Code, rec.Body.String())
	}
}
