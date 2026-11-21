// Package notify turns request lifecycle events into rows in the
// notifications feed. It performs no network I/O: the app polls
// GET /notifications and shows an in-app banner.
package notify

import (
	"context"
	"fmt"
	"log"

	"bloodline/internal/events"
	"bloodline/internal/id"
	"bloodline/internal/store"
)

// Store is the persistence slice the Notifier needs.
type Store interface {
	InsertNotification(ctx context.Context, n store.Notification) error
}

// Notifier is an events.Handler backed by the notifications table.
type Notifier struct {
	store Store
}

// New returns a Notifier using st.
func New(st Store) *Notifier {
	return &Notifier{store: st}
}

// Handle writes one notification per recipient for the event. Errors are
// logged generically: payload values must never be logged.
func (n *Notifier) Handle(ctx context.Context, event events.Event) {
	for _, item := range n.notifications(event) {
		if err := n.store.InsertNotification(ctx, item); err != nil {
			log.Printf("notify: failed to write %s notification (recovered)", event.Name)
		}
	}
}

func (n *Notifier) notifications(event events.Event) []store.Notification {
	var (
		recipients []string
		title      string
		body       string
		requestID  string
	)
	switch payload := event.Payload.(type) {
	case events.RequestCreatedPayload:
		recipients, requestID = payload.RecipientIDs, payload.RequestID
		title = "New blood request"
		body = fmt.Sprintf("%s needed at %s (%d units)", payload.BloodGroup, payload.Hospital, payload.Units)
	case events.RequestAcceptedPayload:
		recipients, requestID = []string{payload.RequesterID}, payload.RequestID
		title = "Someone can help"
		body = fmt.Sprintf("%s (%s) joined the room", payload.UserName, payload.UserRole)
	case events.RequestFulfilledPayload:
		recipients, requestID = payload.RecipientIDs, payload.RequestID
		title = "Request fulfilled"
		body = fmt.Sprintf("The %s request at %s is fulfilled", payload.BloodGroup, payload.Hospital)
	default:
		return nil
	}

	result := make([]store.Notification, 0, len(recipients))
	for _, userID := range recipients {
		if userID == "" {
			continue
		}
		notificationID, err := id.New("n")
		if err != nil {
			// ID generation uses crypto/rand; if it fails, skip rather than
			// risk a duplicate key. The primary mutation is unaffected.
			log.Printf("notify: could not generate notification id (recovered)")
			return result
		}
		request := requestID
		result = append(result, store.Notification{
			ID:        notificationID,
			UserID:    userID,
			Type:      event.Name,
			Title:     title,
			Body:      body,
			RequestID: &request,
		})
	}
	return result
}
