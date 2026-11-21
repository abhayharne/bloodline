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
	store *store.Store
	chat  nexconn.Client
	jwt   *auth.Issuer
}

// New wires the service dependencies.
func New(st *store.Store, chat nexconn.Client, jwt *auth.Issuer) *Service {
	return &Service{store: st, chat: chat, jwt: jwt}
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
