package store

import (
	"context"
	"database/sql"
	"errors"
	"strings"
)

// User is a BloodLine account. BloodGroup is nil for bank accounts.
// Optional profile fields are pointers so JSON consumers can distinguish
// "not provided" from a zero value.
type User struct {
	ID            string   `json:"id"`
	Phone         *string  `json:"phone"`
	Name          string   `json:"name"`
	Role          string   `json:"role"`
	BloodGroup    *string  `json:"blood_group"`
	Lat           float64  `json:"lat"`
	Lng           float64  `json:"lng"`
	Sex           *string  `json:"sex"`
	Age           *int     `json:"age"`
	WeightKG      *float64 `json:"weight_kg"`
	HeightCM      *float64 `json:"height_cm"`
	DonatedBefore bool     `json:"donated_before"`
	LastDonatedAt *string  `json:"last_donated_at"`
	Available     bool     `json:"available"`
	ConsentAt     *string  `json:"consent_at"`
	PushToken     *string  `json:"-"`
	CreatedAt     string   `json:"-"`
}

const userColumns = `id, name, role, blood_group, lat, lng, push_token, created_at,
	phone, sex, age, weight_kg, height_cm, donated_before, last_donated_at,
	available, consent_at`

// CreateUser inserts a user. It returns ErrConflict if name+role or phone already exists.
func (s *Store) CreateUser(ctx context.Context, u User) error {
	_, err := s.db.ExecContext(ctx, `
		INSERT INTO users (id, name, role, blood_group, lat, lng,
			phone, sex, age, weight_kg, height_cm, donated_before,
			last_donated_at, available, consent_at)
		VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?)`,
		u.ID, u.Name, u.Role, u.BloodGroup, u.Lat, u.Lng,
		u.Phone, u.Sex, u.Age, u.WeightKG, u.HeightCM, u.DonatedBefore,
		u.LastDonatedAt, u.Available, u.ConsentAt,
	)
	if err != nil {
		if isUniqueViolation(err) {
			return ErrConflict
		}
		return err
	}
	return nil
}

// UserByNameRole finds an account used by the legacy passwordless login.
func (s *Store) UserByNameRole(ctx context.Context, name, role string) (User, error) {
	return scanUser(s.db.QueryRowContext(ctx, `
		SELECT `+userColumns+`
		FROM users WHERE name = ? AND role = ?`, name, role))
}

// UserByID finds an account by its id.
func (s *Store) UserByID(ctx context.Context, id string) (User, error) {
	return scanUser(s.db.QueryRowContext(ctx, `
		SELECT `+userColumns+`
		FROM users WHERE id = ?`, id))
}

// UserByPhone finds the account used by POST /auth/verify.
func (s *Store) UserByPhone(ctx context.Context, phone string) (User, error) {
	return scanUser(s.db.QueryRowContext(ctx, `
		SELECT `+userColumns+`
		FROM users WHERE phone = ?`, phone))
}

func scanUser(row *sql.Row) (User, error) {
	var (
		u             User
		bloodGroup    sql.NullString
		pushToken     sql.NullString
		phone         sql.NullString
		sex           sql.NullString
		age           sql.NullInt64
		weightKG      sql.NullFloat64
		heightCM      sql.NullFloat64
		lastDonatedAt sql.NullString
		consentAt     sql.NullString
		donatedBefore int
		available     int
	)
	err := row.Scan(
		&u.ID, &u.Name, &u.Role, &bloodGroup, &u.Lat, &u.Lng, &pushToken, &u.CreatedAt,
		&phone, &sex, &age, &weightKG, &heightCM, &donatedBefore, &lastDonatedAt,
		&available, &consentAt,
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
	if phone.Valid {
		u.Phone = &phone.String
	}
	if sex.Valid {
		u.Sex = &sex.String
	}
	if age.Valid {
		value := int(age.Int64)
		u.Age = &value
	}
	if weightKG.Valid {
		u.WeightKG = &weightKG.Float64
	}
	if heightCM.Valid {
		u.HeightCM = &heightCM.Float64
	}
	if lastDonatedAt.Valid {
		u.LastDonatedAt = &lastDonatedAt.String
	}
	if consentAt.Valid {
		u.ConsentAt = &consentAt.String
	}
	u.DonatedBefore = donatedBefore != 0
	u.Available = available != 0
	return u, nil
}

func isUniqueViolation(err error) bool {
	message := err.Error()
	return strings.Contains(message, "UNIQUE constraint failed") ||
		strings.Contains(message, "constraint failed: UNIQUE")
}
