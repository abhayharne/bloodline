// Package service holds the business logic between the HTTP handlers and the
// store / Nexconn client.
package service

import (
	"bloodline/internal/auth"
	"bloodline/internal/nexconn"
	"bloodline/internal/store"
)

// Service is the application service layer.
type Service struct {
	store    *store.Store
	chat     nexconn.Client
	jwt      *auth.Issuer
	demoOTP  string
	features []string
}

// Option customises a Service without breaking existing callers.
type Option func(*Service)

// WithDemoOTP sets the fixed mock OTP accepted by POST /auth/verify.
func WithDemoOTP(code string) Option {
	return func(s *Service) { s.demoOTP = code }
}

// WithFeatures exposes the client-safe feature list from GET /config.
func WithFeatures(features []string) Option {
	return func(s *Service) { s.features = features }
}

// New wires the service dependencies.
func New(st *store.Store, chat nexconn.Client, jwt *auth.Issuer, opts ...Option) *Service {
	s := &Service{store: st, chat: chat, jwt: jwt, demoOTP: "123456", features: []string{}}
	for _, opt := range opts {
		opt(s)
	}
	return s
}

// Features returns a copy of the enabled feature flags.
func (s *Service) Features() []string {
	out := make([]string, len(s.features))
	copy(out, s.features)
	return out
}

// ValidationError is a client-caused error; handlers map it to HTTP 400.
type ValidationError struct {
	Message string
}

func (e ValidationError) Error() string {
	return e.Message
}

func invalid(message string) error {
	return ValidationError{Message: message}
}
