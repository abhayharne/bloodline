package store

import (
	"context"
	"database/sql"
	"errors"
)

// Notification is one row of the in-app notification feed.
type Notification struct {
	ID        string  `json:"id"`
	UserID    string  `json:"user_id"`
	Type      string  `json:"type"`
	Title     string  `json:"title"`
	Body      string  `json:"body"`
	RequestID *string `json:"request_id"`
	ReadAt    *string `json:"read_at"`
	// Read is the client-facing boolean form of ReadAt (addendum v2 shape).
	Read      bool   `json:"read"`
	CreatedAt string `json:"created_at"`
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
			n.Read = true
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

// MarkNotificationRead marks a notification as read. It is owner-scoped (a
// user can only mark their own rows) and idempotent (marking an already-read
// row succeeds without changing its original read_at). A missing row or a row
// owned by someone else is reported as ErrNotFound so callers cannot use this
// method to probe another user's inbox.
func (s *Store) MarkNotificationRead(ctx context.Context, id, userID string) error {
	result, err := s.db.ExecContext(ctx, `
		UPDATE notifications SET read_at = datetime('now')
		WHERE id = ? AND user_id = ? AND read_at IS NULL`, id, userID)
	if err != nil {
		return err
	}
	changed, err := result.RowsAffected()
	if err != nil {
		return err
	}
	if changed > 0 {
		return nil
	}

	// Zero rows changed: either the row is already read (still a success) or
	// it does not exist / is not owned by the caller (a 404).
	var one int
	err = s.db.QueryRowContext(ctx, `
		SELECT 1 FROM notifications WHERE id = ? AND user_id = ?`, id, userID).Scan(&one)
	if errors.Is(err, sql.ErrNoRows) {
		return ErrNotFound
	}
	return err
}

// HasNotification reports whether a user already has a notification with the
// given type and body. Used by feature subscribers to keep idempotent behavior
// when events may be published more than once for the same logical transition.
func (s *Store) HasNotification(ctx context.Context, userID, typ, body string) (bool, error) {
	var one int
	err := s.db.QueryRowContext(ctx, `
		SELECT 1 FROM notifications WHERE user_id = ? AND type = ? AND body = ? LIMIT 1`,
		userID, typ, body).Scan(&one)
	if errors.Is(err, sql.ErrNoRows) {
		return false, nil
	}
	if err != nil {
		return false, err
	}
	return true, nil
}
