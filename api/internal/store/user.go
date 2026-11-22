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
	CreatedAt     string   `json:"created_at"`
}

const userColumns = `id, name, role, blood_group, lat, lng, push_token, created_at,
	phone, sex, age, weight_kg, height_cm, donated_before, last_donated_at,
	available, consent_at`

// Qualified variant for queries that join tables sharing column names.
const qualifiedUserColumns = `u.id, u.name, u.role, u.blood_group, u.lat, u.lng,
	u.push_token, u.created_at, u.phone, u.sex, u.age, u.weight_kg, u.height_cm,
	u.donated_before, u.last_donated_at, u.available, u.consent_at`

// CreateUser inserts a user. It returns ErrConflict if name+role or phone already exists.
func (s *Store) CreateUser(ctx context.Context, u User) error {
	createdAt := u.CreatedAt
	if createdAt == "" {
		createdAt = Timestamp()
	} else {
		createdAt = NormaliseTimestamp(createdAt)
	}
	_, err := s.db.ExecContext(ctx, `
		INSERT INTO users (id, name, role, blood_group, lat, lng,
			phone, sex, age, weight_kg, height_cm, donated_before,
			last_donated_at, available, consent_at, created_at)
		VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?)`,
		u.ID, u.Name, u.Role, u.BloodGroup, u.Lat, u.Lng,
		u.Phone, u.Sex, u.Age, u.WeightKG, u.HeightCM, u.DonatedBefore,
		u.LastDonatedAt, u.Available, u.ConsentAt, createdAt,
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

// Donors returns every donor account, ordered by id. The reminders feature
// scans this list to find donors whose waiting period has elapsed.
func (s *Store) Donors(ctx context.Context) ([]User, error) {
	return scanUsers(s.db.QueryContext(ctx, `
		SELECT `+userColumns+`
		FROM users WHERE role = 'donor' ORDER BY id`))
}

// ProfileUpdate carries only the fields present in a PUT /me body. A nil
// pointer means "leave unchanged"; an empty LastDonatedAt clears the column.
type ProfileUpdate struct {
	Available     *bool
	Lat           *float64
	Lng           *float64
	WeightKG      *float64
	HeightCM      *float64
	LastDonatedAt *string
}

// UpdateProfile applies a partial profile update. An empty update is a no-op;
// a missing user is reported as ErrNotFound.
func (s *Store) UpdateProfile(ctx context.Context, id string, update ProfileUpdate) error {
	clauses := make([]string, 0, 6)
	args := make([]any, 0, 7)
	if update.Available != nil {
		clauses = append(clauses, "available = ?")
		args = append(args, *update.Available)
	}
	if update.Lat != nil {
		clauses = append(clauses, "lat = ?")
		args = append(args, *update.Lat)
	}
	if update.Lng != nil {
		clauses = append(clauses, "lng = ?")
		args = append(args, *update.Lng)
	}
	if update.WeightKG != nil {
		clauses = append(clauses, "weight_kg = ?")
		args = append(args, *update.WeightKG)
	}
	if update.HeightCM != nil {
		clauses = append(clauses, "height_cm = ?")
		args = append(args, *update.HeightCM)
	}
	if update.LastDonatedAt != nil {
		if strings.TrimSpace(*update.LastDonatedAt) == "" {
			clauses = append(clauses, "last_donated_at = NULL")
		} else {
			clauses = append(clauses, "last_donated_at = ?")
			args = append(args, strings.TrimSpace(*update.LastDonatedAt))
		}
	}
	if len(clauses) == 0 {
		return nil
	}
	args = append(args, id)
	result, err := s.db.ExecContext(ctx,
		"UPDATE users SET "+strings.Join(clauses, ", ")+" WHERE id = ?", args...)
	if err != nil {
		return err
	}
	affected, err := result.RowsAffected()
	if err != nil {
		return err
	}
	if affected == 0 {
		return ErrNotFound
	}
	return nil
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
	u.CreatedAt = NormaliseTimestamp(u.CreatedAt)
	return u, nil
}

func isUniqueViolation(err error) bool {
	message := err.Error()
	return strings.Contains(message, "UNIQUE constraint failed") ||
		strings.Contains(message, "constraint failed: UNIQUE")
}
