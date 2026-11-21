// Package httpapi wires the HTTP routes to the service layer.
package httpapi

import (
	"context"
	"encoding/json"
	"errors"
	"log"
	"net/http"
	"strings"

	"bloodline/internal/auth"
	"bloodline/internal/service"
	"bloodline/internal/store"
)

// ReminderRunner is the feature slice the dev run-reminders route needs. The
// interface lives here so httpapi never imports the reminders feature package.
type ReminderRunner interface {
	RunEligibilityChecks(ctx context.Context) (int, error)
}

// Server holds the dependencies used by the handlers.
type Server struct {
	svc       *service.Service
	jwt       *auth.Issuer
	dev       bool
	reminders ReminderRunner
}

// ServerOption customises the HTTP handler without breaking existing callers.
type ServerOption func(*Server)

// WithDevRoutes registers dev-only endpoints (POST /dev/reset). Never use in
// production; main only passes it when DEV=1.
func WithDevRoutes() ServerOption {
	return func(s *Server) { s.dev = true }
}

// WithReminderRunner injects the eligibility scan used by POST /dev/run-reminders.
// It does not register the route; that still requires WithDevRoutes (DEV=1).
func WithReminderRunner(r ReminderRunner) ServerOption {
	return func(s *Server) { s.reminders = r }
}

// New returns the API handler.
func New(svc *service.Service, jwt *auth.Issuer, opts ...ServerOption) http.Handler {
	s := &Server{svc: svc, jwt: jwt}
	for _, opt := range opts {
		opt(s)
	}

	mux := http.NewServeMux()
	mux.HandleFunc("GET /health", health)
	mux.HandleFunc("GET /config", s.config)
	mux.HandleFunc("POST /auth/otp/send", s.otpSend)
	mux.HandleFunc("POST /auth/verify", s.verifyOTP)
	mux.HandleFunc("POST /auth/signup", s.signup)
	mux.HandleFunc("POST /auth/login", s.login)
	mux.Handle("GET /me", s.requireAuth(s.getMe))
	mux.Handle("PUT /me", s.requireAuth(s.putMe))
	mux.Handle("GET /banks/me/stock", s.requireBank(s.getBankStock))
	mux.Handle("PUT /banks/me/stock", s.requireBank(s.putBankStock))
	mux.Handle("GET /notifications", s.requireAuth(s.getNotifications))
	mux.Handle("POST /notifications/{id}/read", s.requireAuth(s.markNotificationRead))
	mux.Handle("POST /requests", s.requireRole("requester")(s.createRequest))
	mux.Handle("GET /requests", s.requireRole("requester", "donor", "bank")(s.listRequests))
	mux.Handle("POST /requests/{id}/accept", s.requireRole("donor", "bank")(s.acceptRequest))
	mux.Handle("POST /requests/{id}/donated", s.requireRole("donor")(s.recordDonation))
	mux.Handle("POST /requests/{id}/fulfill", s.requireRole("requester")(s.fulfillRequest))
	if s.dev {
		mux.HandleFunc("POST /dev/reset", s.devReset)
		mux.HandleFunc("POST /dev/run-reminders", s.devRunReminders)
	}
	return mux
}

type claimsContextKey struct{}

// requireAuth accepts any valid role and stores the claims in the context.
func (s *Server) requireAuth(next http.HandlerFunc) http.Handler {
	return http.HandlerFunc(func(w http.ResponseWriter, r *http.Request) {
		claims, err := s.claimsFromRequest(r)
		if err != nil {
			writeError(w, http.StatusUnauthorized, "missing or invalid token")
			return
		}
		next(w, r.WithContext(context.WithValue(r.Context(), claimsContextKey{}, claims)))
	})
}

// requireRole accepts only the listed roles.
func (s *Server) requireRole(roles ...string) func(http.HandlerFunc) http.Handler {
	allowed := make(map[string]bool, len(roles))
	for _, role := range roles {
		allowed[role] = true
	}
	return func(next http.HandlerFunc) http.Handler {
		return s.requireAuth(func(w http.ResponseWriter, r *http.Request) {
			claims, _ := claimsFromContext(r.Context())
			if !allowed[claims.Role] {
				writeError(w, http.StatusForbidden, "role not allowed")
				return
			}
			next(w, r)
		})
	}
}

func (s *Server) requireBank(next http.HandlerFunc) http.Handler {
	return s.requireRole("bank")(next)
}

func (s *Server) claimsFromRequest(r *http.Request) (auth.Claims, error) {
	header := strings.TrimSpace(r.Header.Get("Authorization"))
	const prefix = "Bearer "
	if len(header) <= len(prefix) || !strings.EqualFold(header[:len(prefix)], prefix) {
		return auth.Claims{}, auth.ErrInvalidToken
	}
	return s.jwt.Parse(strings.TrimSpace(header[len(prefix):]))
}

func claimsFromContext(ctx context.Context) (auth.Claims, bool) {
	claims, ok := ctx.Value(claimsContextKey{}).(auth.Claims)
	return claims, ok
}

func health(w http.ResponseWriter, _ *http.Request) {
	writeJSON(w, http.StatusOK, map[string]string{"status": "ok"})
}

func decodeJSON(w http.ResponseWriter, r *http.Request, dst any) bool {
	r.Body = http.MaxBytesReader(w, r.Body, 1<<20)
	if err := json.NewDecoder(r.Body).Decode(dst); err != nil {
		writeError(w, http.StatusBadRequest, "invalid JSON body")
		return false
	}
	return true
}

func writeServiceError(w http.ResponseWriter, err error) {
	var validation service.ValidationError
	switch {
	case errors.As(err, &validation):
		writeError(w, http.StatusBadRequest, validation.Message)
	case errors.Is(err, store.ErrNotFound):
		writeError(w, http.StatusNotFound, "not found")
	case errors.Is(err, store.ErrConflict), errors.Is(err, service.ErrNotOpen):
		writeError(w, http.StatusConflict, "conflict")
	case errors.Is(err, service.ErrForbidden):
		writeError(w, http.StatusForbidden, "forbidden")
	default:
		log.Printf("internal error: %v", err)
		writeError(w, http.StatusInternalServerError, "internal server error")
	}
}

func writeJSON(w http.ResponseWriter, status int, v any) {
	w.Header().Set("Content-Type", "application/json")
	w.WriteHeader(status)
	_ = json.NewEncoder(w).Encode(v)
}

func writeError(w http.ResponseWriter, status int, message string) {
	writeJSON(w, status, map[string]string{"error": message})
}
