package store

import (
	"context"
	"database/sql"
	"errors"
	"strings"
)

// User is a BloodLine account. BloodGroup is nil for bank accounts.
type User struct {
	ID         string  `json:"id"`
	Name       string  `json:"name"`
	Role       string  `json:"role"`
	BloodGroup *string `json:"blood_group"`
	Lat        float64 `json:"lat"`
	Lng        float64 `json:"lng"`
	PushToken  *string `json:"-"`
	CreatedAt  string  `json:"-"`
}

// CreateUser inserts a user. It returns ErrConflict if name+role already exists.
func (s *Store) CreateUser(ctx context.Context, u User) error {
	_, err := s.db.ExecContext(ctx, `
		INSERT INTO users (id, name, role, blood_group, lat, lng)
		VALUES (?, ?, ?, ?, ?, ?)`,
		u.ID, u.Name, u.Role, u.BloodGroup, u.Lat, u.Lng,
	)
	if err != nil {
		if isUniqueViolation(err) {
			return ErrConflict
		}
		return err
	}
	return nil
}

// UserByNameRole finds the account used for passwordless login.
func (s *Store) UserByNameRole(ctx context.Context, name, role string) (User, error) {
	return scanUser(s.db.QueryRowContext(ctx, `
		SELECT id, name, role, blood_group, lat, lng, push_token, created_at
		FROM users WHERE name = ? AND role = ?`, name, role))
}

// UserByID finds an account by its id.
func (s *Store) UserByID(ctx context.Context, id string) (User, error) {
	return scanUser(s.db.QueryRowContext(ctx, `
		SELECT id, name, role, blood_group, lat, lng, push_token, created_at
		FROM users WHERE id = ?`, id))
}

func scanUser(row *sql.Row) (User, error) {
	var (
		u          User
		bloodGroup sql.NullString
		pushToken  sql.NullString
	)
	err := row.Scan(
		&u.ID, &u.Name, &u.Role, &bloodGroup, &u.Lat, &u.Lng, &pushToken, &u.CreatedAt,
	)
	if errors.Is(err, sql.ErrNoRows) {
		return User{}, ErrNotFound
	}
	if err != nil {
		return User{}, err
	}
	if bloodGroup.Valid {
		u.BloodGroup = &bloodGroup.String
	}
	if pushToken.Valid {
		u.PushToken = &pushToken.String
	}
	return u, nil
}

func isUniqueViolation(err error) bool {
	message := err.Error()
	return strings.Contains(message, "UNIQUE constraint failed") ||
		strings.Contains(message, "constraint failed: UNIQUE")
}
