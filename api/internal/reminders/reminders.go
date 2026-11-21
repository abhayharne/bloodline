// Package reminders implements the optional "reminders" feature. It subscribes
// to request.created for match_nearby nudges and scans donors on a ticker (or
// via the dev endpoint) for eligible_again reminders. The core service never
// imports this package.
package reminders

import (
	"context"
	"fmt"
	"log"
	"time"

	"bloodline/internal/events"
	"bloodline/internal/id"
	"bloodline/internal/matching"
	"bloodline/internal/store"
)

// Store is the persistence slice the reminders handler needs.
type Store interface {
	Donors(ctx context.Context) ([]store.User, error)
	UserByID(ctx context.Context, id string) (store.User, error)
	RequestByID(ctx context.Context, id string) (store.Request, error)
	InsertNotification(ctx context.Context, n store.Notification) error
	HasNotificationForRequest(ctx context.Context, userID, typ, requestID string) (bool, error)
	HasNotificationSince(ctx context.Context, userID, typ, since string) (bool, error)
}

// Handler writes reminder notifications. Both entry points are safe to call
// more than once: match_nearby is deduped per request, eligible_again per
// donation/eligibility cycle.
type Handler struct {
	store Store
}

// New returns a reminders Handler.
func New(st Store) *Handler { return &Handler{store: st} }

// Handle implements events.Handler for request.created. Banks are recipients
// of that event too, so only donor accounts get the match_nearby copy.
func (h *Handler) Handle(ctx context.Context, event events.Event) {
	payload, ok := event.Payload.(events.RequestCreatedPayload)
	if !ok || payload.RequestID == "" {
		return
	}
	request, err := h.store.RequestByID(ctx, payload.RequestID)
	if err != nil {
		log.Printf("reminders: could not load request for match_nearby (recovered)")
		return
	}
	for _, recipientID := range payload.RecipientIDs {
		if recipientID == "" {
			continue
		}
		user, err := h.store.UserByID(ctx, recipientID)
		if err != nil {
			continue
		}
		if user.Role != "donor" {
			continue
		}
		km := matching.DistanceKM(request.Lat, request.Lng, user.Lat, user.Lng)
		body := fmt.Sprintf("%s, someone %.1f km away needs %s. That's your type. Got 10 minutes?",
			user.Name, km, payload.BloodGroup)

		exists, err := h.store.HasNotificationForRequest(ctx, user.ID, "match_nearby", request.ID)
		if err != nil {
			log.Printf("reminders: failed to check match_nearby notification (recovered)")
			continue
		}
		if exists {
			continue
		}
		nid, err := id.New("n")
		if err != nil {
			log.Printf("reminders: could not generate notification id (recovered)")
			continue
		}
		requestID := request.ID
		n := store.Notification{
			ID: nid, UserID: user.ID, Type: "match_nearby", Title: "Nearby match",
			Body: body, RequestID: &requestID,
		}
		if err := h.store.InsertNotification(ctx, n); err != nil {
			log.Printf("reminders: failed to write match_nearby notification (recovered)")
		}
	}
}

// RunEligibilityChecks writes an eligible_again notification for every donor
// whose waiting period has elapsed and who has not been reminded for that
// cycle. It returns the number of rows written; a repeated run writes none.
func (h *Handler) RunEligibilityChecks(ctx context.Context) (int, error) {
	donors, err := h.store.Donors(ctx)
	if err != nil {
		return 0, err
	}
	now := time.Now()
	sent := 0
	for _, user := range donors {
		profile := matching.FromUser(user)
		last := profile.LastDonatedAt
		if last == nil {
			continue // never donated (or unparseable date): "again" does not apply
		}
		// The addendum treats unknown age/weight as eligible, so use the same
		// known-eligible defaults as /me before applying the pure rule.
		if profile.Age == nil {
			age := 30
			profile.Age = &age
		}
		if profile.WeightKG == nil {
			weight := 60.0
			profile.WeightKG = &weight
		}
		if !matching.Eligible(profile, now) {
			continue
		}
		since := last.UTC().Format("2006-01-02 15:04:05")
		exists, err := h.store.HasNotificationSince(ctx, user.ID, "eligible_again", since)
		if err != nil {
			log.Printf("reminders: failed to check eligible_again notification (recovered)")
			continue
		}
		if exists {
			continue
		}
		days := int(now.Sub(*last).Hours() / 24)
		if days < 0 {
			continue
		}
		body := fmt.Sprintf("Your blood has had %d days to recharge. Ready to be somebody's hero again?", days)
		nid, err := id.New("n")
		if err != nil {
			log.Printf("reminders: could not generate notification id (recovered)")
			continue
		}
		n := store.Notification{
			ID: nid, UserID: user.ID, Type: "eligible_again", Title: "Ready again?", Body: body,
		}
		if err := h.store.InsertNotification(ctx, n); err != nil {
			log.Printf("reminders: failed to write eligible_again notification (recovered)")
			continue
		}
		sent++
	}
	return sent, nil
}

// RunTicker runs an eligibility check on every tick until ctx is cancelled.
// main starts it with a one-hour interval; tests can pass a shorter one.
func (h *Handler) RunTicker(ctx context.Context, interval time.Duration) {
	ticker := time.NewTicker(interval)
	defer ticker.Stop()
	for {
		select {
		case <-ctx.Done():
			return
		case <-ticker.C:
			if _, err := h.RunEligibilityChecks(ctx); err != nil {
				log.Printf("reminders: scheduled eligibility check failed (recovered)")
			}
		}
	}
}
