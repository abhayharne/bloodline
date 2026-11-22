package store

import (
	"context"
	"database/sql"
	"errors"
	"strings"
)

// Request is one live coordination room.
type Request struct {
	ID          string  `json:"id"`
	RequesterID string  `json:"requester_id"`
	BloodGroup  string  `json:"blood_group"`
	Units       int     `json:"units"`
	Hospital    string  `json:"hospital"`
	Urgency     string  `json:"urgency"`
	Lat         float64 `json:"lat"`
	Lng         float64 `json:"lng"`
	Status      string  `json:"status"`
	ChannelID   string  `json:"channel_id"`
	CreatedAt   string  `json:"created_at"`
	FulfilledAt *string `json:"fulfilled_at"`
	Component   string  `json:"component"`
	Notes       string  `json:"notes"`
}

// CreateRequest inserts a new open request and its initial chat membership.
func (s *Store) CreateRequest(ctx context.Context, r Request, bankIDs ...string) error {
	tx, err := s.db.BeginTx(ctx, nil)
	if err != nil {
		return err
	}
	defer tx.Rollback()

	createdAt := r.CreatedAt
	if createdAt == "" {
		createdAt = Timestamp()
	} else {
		createdAt = NormaliseTimestamp(createdAt)
	}
	component := r.Component
	if component == "" {
		component = "whole_blood"
	}
	_, err = tx.ExecContext(ctx, `
		INSERT INTO requests (id, requester_id, blood_group, units, hospital,
			urgency, lat, lng, status, channel_id, created_at, component, notes)
		VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?)`,
		r.ID, r.RequesterID, r.BloodGroup, r.Units, r.Hospital,
		r.Urgency, r.Lat, r.Lng, "open", r.ChannelID, createdAt, component, r.Notes,
	)
	if err != nil {
		if isUniqueViolation(err) {
			return ErrConflict
		}
		return err
	}
	if _, err := tx.ExecContext(ctx, `
		INSERT INTO request_members (request_id, user_id, role)
		VALUES (?, ?, 'requester')`, r.ID, r.RequesterID); err != nil {
		return err
	}
	for _, bankID := range bankIDs {
		if _, err := tx.ExecContext(ctx, `
			INSERT INTO request_members (request_id, user_id, role)
			VALUES (?, ?, 'bank')`, r.ID, bankID); err != nil {
			return err
		}
	}
	return tx.Commit()
}

// RequestByID finds a request by id.
func (s *Store) RequestByID(ctx context.Context, id string) (Request, error) {
	return scanRequest(s.db.QueryRowContext(ctx, `
		SELECT id, requester_id, blood_group, units, hospital, urgency,
			lat, lng, status, channel_id, created_at, fulfilled_at, component, notes
		FROM requests WHERE id = ?`, id))
}

// Requests returns requests filtered by status; "all" means no filter.
func (s *Store) Requests(ctx context.Context, status string) ([]Request, error) {
	query := `
		SELECT id, requester_id, blood_group, units, hospital, urgency,
			lat, lng, status, channel_id, created_at, fulfilled_at, component, notes
		FROM requests`
	args := []any{}
	if status != "" && status != "all" {
		query += " WHERE status = ?"
		args = append(args, status)
	}
	// Urgency is a request priority: critical work surfaces before routine work.
	// created_at/rowid keep the documented newest-first tiebreak within a level.
	query += ` ORDER BY CASE urgency
		WHEN 'critical' THEN 0 WHEN 'high' THEN 1 WHEN 'medium' THEN 2
		WHEN 'low' THEN 3 ELSE 4 END, created_at DESC, rowid DESC`

	rows, err := s.db.QueryContext(ctx, query, args...)
	if err != nil {
		return nil, err
	}
	defer rows.Close()

	requests := make([]Request, 0)
	for rows.Next() {
		r, err := scanRequestRow(rows)
		if err != nil {
			return nil, err
		}
		requests = append(requests, r)
	}
	if err := rows.Err(); err != nil {
		return nil, err
	}
	return requests, nil
}

// SetRequestStatus updates the lifecycle status and fulfilled_at timestamp.
func (s *Store) SetRequestStatus(ctx context.Context, id, status string) error {
	result, err := s.db.ExecContext(ctx, `
		UPDATE requests SET status = ?,
			fulfilled_at = CASE WHEN ? = 'fulfilled' THEN ? ELSE fulfilled_at END
		WHERE id = ?`, status, status, Timestamp(), id)
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

// AddRequestMember records membership in the request room. It is idempotent.
func (s *Store) AddRequestMember(ctx context.Context, requestID, userID, role string) error {
	_, err := s.db.ExecContext(ctx, `
		INSERT OR IGNORE INTO request_members (request_id, user_id, role)
		VALUES (?, ?, ?)`, requestID, userID, role)
	return err
}

// HasRequestMember reports whether a user already belongs to the room.
func (s *Store) HasRequestMember(ctx context.Context, requestID, userID string) (bool, error) {
	var one int
	err := s.db.QueryRowContext(ctx, `
		SELECT 1 FROM request_members WHERE request_id = ? AND user_id = ?`,
		requestID, userID).Scan(&one)
	if errors.Is(err, sql.ErrNoRows) {
		return false, nil
	}
	if err != nil {
		return false, err
	}
	return true, nil
}

// RequestMemberIDs lists every user joined to a request room.
func (s *Store) RequestMemberIDs(ctx context.Context, requestID string) ([]string, error) {
	rows, err := s.db.QueryContext(ctx, `
		SELECT user_id FROM request_members WHERE request_id = ? ORDER BY joined_at, user_id`, requestID)
	if err != nil {
		return nil, err
	}
	defer rows.Close()

	ids := make([]string, 0)
	for rows.Next() {
		var id string
		if err := rows.Scan(&id); err != nil {
			return nil, err
		}
		ids = append(ids, id)
	}
	return ids, rows.Err()
}

// DonorsByGroup returns available donor accounts with the exact blood group.
// Compatibility filtering lives in internal/matching and is not wired in yet.
func (s *Store) DonorsByGroup(ctx context.Context, group string) ([]User, error) {
	return scanUsers(s.db.QueryContext(ctx, `
		SELECT `+userColumns+`
		FROM users WHERE role = 'donor' AND blood_group = ? AND available = 1`, group))
}

// DonorsByGroupAll returns every donor account with the exact blood group,
// including those marked unavailable. The core matching path keeps using
// DonorsByGroup; features that enable the isAvailable/isEligible pipeline
// use this method so the pipeline, rather than SQL, decides who is matched.
func (s *Store) DonorsByGroupAll(ctx context.Context, group string) ([]User, error) {
	return scanUsers(s.db.QueryContext(ctx, `
		SELECT `+userColumns+`
		FROM users WHERE role = 'donor' AND blood_group = ?`, group))
}

// BanksWithStockFor returns bank accounts holding minUnits of one of groups in
// the requested component; it is used by CreateRequest:
// banks holding minUnits of one of groups in the requested component.
func (s *Store) BanksWithStockFor(ctx context.Context, groups []string, component string, minUnits int) ([]User, error) {
	if len(groups) == 0 {
		return []User{}, nil
	}
	placeholders := strings.TrimSuffix(strings.Repeat("?,", len(groups)), ",")
	args := make([]any, 0, len(groups)+2)
	for _, group := range groups {
		args = append(args, group)
	}
	args = append(args, component, minUnits)
	return scanUsers(s.db.QueryContext(ctx, `
		SELECT DISTINCT `+qualifiedUserColumns+`
		FROM users u
		JOIN bank_stock s ON s.bank_id = u.id
		WHERE u.role = 'bank' AND s.blood_group IN (`+placeholders+`)
			AND s.component = ? AND s.units >= ?`, args...))
}

// DonorsByGroups returns available donors whose group is in groups. Apheresis
// components additionally require the donor to have opted in via PUT /me.
func (s *Store) DonorsByGroups(ctx context.Context, groups []string, apheresisOnly bool) ([]User, error) {
	if len(groups) == 0 {
		return []User{}, nil
	}
	placeholders := strings.TrimSuffix(strings.Repeat("?,", len(groups)), ",")
	query := `SELECT ` + userColumns + ` FROM users
		WHERE role = 'donor' AND available = 1 AND blood_group IN (` + placeholders + `)`
	if apheresisOnly {
		query += " AND apheresis_ok = 1"
	}
	args := make([]any, 0, len(groups))
	for _, group := range groups {
		args = append(args, group)
	}
	return scanUsers(s.db.QueryContext(ctx, query, args...))
}

// CreateDonation records a donor's pledge for a request. It is idempotent per
// (request, donor), so a repeated accept never creates a duplicate row.
func (s *Store) CreateDonation(ctx context.Context, d Donation) error {
	createdAt := d.CreatedAt
	if createdAt == "" {
		createdAt = Timestamp()
	} else {
		createdAt = NormaliseTimestamp(createdAt)
	}
	_, err := s.db.ExecContext(ctx, `
		INSERT OR IGNORE INTO donations (id, request_id, donor_id, units, created_at)
		VALUES (?, ?, ?, ?, ?)`, d.ID, d.RequestID, d.DonorID, d.Units, createdAt)
	return err
}

type rowScanner interface {
	Scan(dest ...any) error
}

func scanRequest(row *sql.Row) (Request, error) {
	return scanRequestRow(row)
}

func scanRequestRow(row rowScanner) (Request, error) {
	var (
		r           Request
		fulfilledAt sql.NullString
		notes       sql.NullString
	)
	err := row.Scan(&r.ID, &r.RequesterID, &r.BloodGroup, &r.Units, &r.Hospital,
		&r.Urgency, &r.Lat, &r.Lng, &r.Status, &r.ChannelID, &r.CreatedAt, &fulfilledAt,
		&r.Component, &notes)
	if errors.Is(err, sql.ErrNoRows) {
		return Request{}, ErrNotFound
	}
	if err != nil {
		return Request{}, err
	}
	r.Notes = notes.String
	r.CreatedAt = NormaliseTimestamp(r.CreatedAt)
	if fulfilledAt.Valid {
		stamp := NormaliseTimestamp(fulfilledAt.String)
		r.FulfilledAt = &stamp
	}
	return r, nil
}

func scanUsers(rows *sql.Rows, err error) ([]User, error) {
	if err != nil {
		return nil, err
	}
	defer rows.Close()

	users := make([]User, 0)
	for rows.Next() {
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
			apheresisOK   int
		)
		if err := rows.Scan(&u.ID, &u.Name, &u.Role, &bloodGroup, &u.Lat, &u.Lng,
			&pushToken, &u.CreatedAt, &phone, &sex, &age, &weightKG, &heightCM,
			&donatedBefore, &lastDonatedAt, &available, &consentAt, &apheresisOK); err != nil {
			return nil, err
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
		u.ApheresisOK = apheresisOK != 0
		u.CreatedAt = NormaliseTimestamp(u.CreatedAt)
		users = append(users, u)
	}
	if err := rows.Err(); err != nil {
		return nil, err
	}
	return users, nil
}
