// Package events is a tiny in-process pub/sub used for request lifecycle
// notifications. Delivery is synchronous so the demo is deterministic; a
// panicking subscriber is recovered so it cannot break the HTTP request or
// starve other subscribers.
package events

import (
	"context"
	"log"
	"sync"
)

const (
	RequestCreated   = "request.created"
	RequestAccepted  = "request.accepted"
	RequestFulfilled = "request.fulfilled"
)

// Event carries the lifecycle name and a typed payload (see the *Payload types
// below). Payloads must never contain JWTs, chat tokens or OTPs.
type Event struct {
	Name    string
	Payload any
}

// Handler consumes an event. The context comes from the originating request.
type Handler func(context.Context, Event)

type subscription struct {
	id      uint64
	handler Handler
}

// Bus dispatches events to subscribers registered for the same name.
type Bus struct {
	mu       sync.RWMutex
	nextID   uint64
	handlers map[string][]subscription
}

// New returns an empty bus.
func New() *Bus {
	return &Bus{handlers: make(map[string][]subscription)}
}

// Subscribe registers handler for name and returns an idempotent unsubscribe
// function. Order of delivery follows subscription order.
func (b *Bus) Subscribe(name string, handler Handler) func() {
	b.mu.Lock()
	b.nextID++
	id := b.nextID
	b.handlers[name] = append(b.handlers[name], subscription{id: id, handler: handler})
	b.mu.Unlock()

	var once sync.Once
	return func() {
		once.Do(func() {
			b.mu.Lock()
			defer b.mu.Unlock()
			subs := b.handlers[name]
			for i, sub := range subs {
				if sub.id == id {
					b.handlers[name] = append(subs[:i:i], subs[i+1:]...)
					return
				}
			}
		})
	}
}

// Publish delivers an event to every matching subscriber. Each handler is
// isolated: a panic is recovered and logged without its value (which might
// contain sensitive data), then delivery continues.
func (b *Bus) Publish(ctx context.Context, event Event) {
	if b == nil || event.Name == "" {
		return
	}
	if ctx == nil {
		ctx = context.Background()
	}
	b.mu.RLock()
	subs := append([]subscription(nil), b.handlers[event.Name]...)
	b.mu.RUnlock()

	for _, sub := range subs {
		func() {
			defer func() {
				if recovered := recover(); recovered != nil {
					log.Printf("events: subscriber panic handling %q (recovered)", event.Name)
				}
			}()
			sub.handler(ctx, event)
		}()
	}
}

// RequestCreatedPayload describes a newly opened request and its matched users.
type RequestCreatedPayload struct {
	RequestID     string
	BloodGroup    string
	Hospital      string
	Units         int
	RecipientIDs  []string
	RequesterName string
}

// RequestAcceptedPayload describes a donor or bank joining a request room.
type RequestAcceptedPayload struct {
	RequestID   string
	UserID      string
	UserName    string
	UserRole    string
	RequesterID string
}

// RequestFulfilledPayload describes a fulfilled request.
type RequestFulfilledPayload struct {
	RequestID    string
	RecipientIDs []string
	BloodGroup   string
	Hospital     string
}
