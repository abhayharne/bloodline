package store

import (
	"context"
	"database/sql"
	"errors"
)

// Notification is one row of the in-app notification feed.
type Notification struct {
	ID         string  `json:"id"`
	UserID     string  `json:"user_id"`
	Type       string  `json:"type"`
	Title      string  `json:"title"`
	Body       string  `json:"body"`
	RequestID  *string `json:"request_id"`
	ReadAt     *string `json:"read_at"`
	CreatedAt  string  `json:"created_at"`
}

// InsertNotification appends a notification. Duplicates are not expected
// (ids are generated), but a conflict is reported as ErrConflict.
func (s *Store) InsertNotification(ctx context.Context, n Notification) error {
	_, err := s.db.ExecContext(ctx, `
		INSERT INTO notifications (id, user_id, type, title, body, request_id)
		VALUES (?, ?, ?, ?, ?, ?)`,
		n.ID, n.UserID, n.Type, n.Title, n.Body, n.RequestID,
	)
	if err != nil {
		if isUniqueViolation(err) {
			return ErrConflict
		}
		return err
	}
	return nil
}

// Notifications returns a user's feed, newest first.
func (s *Store) Notifications(ctx context.Context, userID string) ([]Notification, error) {
	rows, err := s.db.QueryContext(ctx, `
		SELECT id, user_id, type, title, body, request_id, read_at, created_at
		FROM notifications WHERE user_id = ?
		ORDER BY created_at DESC, id DESC`, userID)
	if err != nil {
		return nil, err
	}
	defer rows.Close()

	items := make([]Notification, 0)
	for rows.Next() {
		var n Notification
		var requestID, readAt sql.NullString
		if err := rows.Scan(&n.ID, &n.UserID, &n.Type, &n.Title, &n.Body,
			&requestID, &readAt, &n.CreatedAt); err != nil {
			return nil, err
		}
		if requestID.Valid {
			n.RequestID = &requestID.String
		}
		if readAt.Valid {
			n.ReadAt = &readAt.String
		}
		items = append(items, n)
	}
	if err := rows.Err(); err != nil {
		if errors.Is(err, sql.ErrNoRows) {
			return items, nil
		}
		return nil, err
	}
	return items, nil
}
