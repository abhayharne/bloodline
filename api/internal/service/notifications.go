package service

import (
	"context"

	"bloodline/internal/store"
)

// Notifications returns the authenticated user's in-app notification feed.
func (s *Service) Notifications(ctx context.Context, userID string) ([]store.Notification, error) {
	return s.store.Notifications(ctx, userID)
}

// MarkNotificationRead marks one of the user's notifications as read.
func (s *Service) MarkNotificationRead(ctx context.Context, id, userID string) error {
	return s.store.MarkNotificationRead(ctx, id, userID)
}
