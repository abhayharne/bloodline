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
)

// Server holds the dependencies used by the handlers.
type Server struct {
	svc *service.Service
	jwt *auth.Issuer
}

// New returns the API handler.
func New(svc *service.Service, jwt *auth.Issuer) http.Handler {
	s := &Server{svc: svc, jwt: jwt}

	mux := http.NewServeMux()
	mux.HandleFunc("GET /health", health)
	mux.HandleFunc("POST /auth/signup", s.signup)
	mux.HandleFunc("POST /auth/login", s.login)
	mux.Handle("GET /banks/me/stock", s.requireBank(s.getBankStock))
	mux.Handle("PUT /banks/me/stock", s.requireBank(s.putBankStock))
	return mux
}

type claimsContextKey struct{}

func (s *Server) requireBank(next http.HandlerFunc) http.Handler {
	return http.HandlerFunc(func(w http.ResponseWriter, r *http.Request) {
		claims, err := s.claimsFromRequest(r)
		if err != nil {
			writeError(w, http.StatusUnauthorized, "missing or invalid token")
			return
		}
		if claims.Role != "bank" {
			writeError(w, http.StatusForbidden, "bank role required")
			return
		}
		next(w, r.WithContext(context.WithValue(r.Context(), claimsContextKey{}, claims)))
	})
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
	if errors.As(err, &validation) {
		writeError(w, http.StatusBadRequest, validation.Message)
		return
	}
	log.Printf("internal error: %v", err)
	writeError(w, http.StatusInternalServerError, "internal server error")
}

func writeJSON(w http.ResponseWriter, status int, v any) {
	w.Header().Set("Content-Type", "application/json")
	w.WriteHeader(status)
	_ = json.NewEncoder(w).Encode(v)
}

func writeError(w http.ResponseWriter, status int, message string) {
	writeJSON(w, status, map[string]string{"error": message})
}
