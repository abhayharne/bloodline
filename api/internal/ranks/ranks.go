// Package ranks implements the optional "ranks" feature. It subscribes to
// donation.recorded and emits a rank_up notification when a donor crosses a
// threshold. The core service never imports this package.
package ranks

import (
	"context"
	"fmt"
	"log"

	"bloodline/internal/events"
	"bloodline/internal/id"
	"bloodline/internal/matching"
	"bloodline/internal/store"
)

// Store is the persistence slice the ranks handler needs.
type Store interface {
	InsertNotification(ctx context.Context, n store.Notification) error
	HasNotification(ctx context.Context, userID, typ, body string) (bool, error)
}

// Handler writes a rank_up notification when donation_count crosses a rank
// threshold. Repeated donation.recorded events for the same count are
// deduped by checking for an existing identical notification.
type Handler struct {
	store Store
}

// New returns a ranks Handler.
func New(st Store) *Handler { return &Handler{store: st} }

// Handle implements events.Handler.
func (h *Handler) Handle(ctx context.Context, event events.Event) {
	payload, ok := event.Payload.(events.DonationRecordedPayload)
	if !ok {
		return
	}
	_, label, ok := matching.RankForCount(payload.DonationCount)
	if !ok {
		return
	}
	prevKey, _, prevOK := matching.RankForCount(payload.DonationCount - 1)
	currKey, _, _ := matching.RankForCount(payload.DonationCount)
	if prevOK && prevKey == currKey {
		return
	}
	body := fmt.Sprintf("%d donations. You're now a %s.", payload.DonationCount, label)
	exists, err := h.store.HasNotification(ctx, payload.DonorID, "rank_up", body)
	if err != nil {
		log.Printf("ranks: failed to check rank_up notification (recovered)")
		return
	}
	if exists {
		return
	}
	nid, err := id.New("n")
	if err != nil {
		log.Printf("ranks: could not generate notification id (recovered)")
		return
	}
	reqID := payload.RequestID
	n := store.Notification{
		ID:        nid,
		UserID:    payload.DonorID,
		Type:      "rank_up",
		Title:     "Rank up",
		Body:      body,
		RequestID: &reqID,
	}
	if err := h.store.InsertNotification(ctx, n); err != nil {
		log.Printf("ranks: failed to write rank_up notification (recovered)")
	}
}
