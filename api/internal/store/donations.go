package store

import (
	"context"
	"database/sql"
	"errors"
)

// Donation is a donor's pledge to fulfil a request.
type Donation struct {
	ID        string `json:"id"`
	RequestID string `json:"request_id"`
	DonorID   string `json:"donor_id"`
	Units     int    `json:"units"`
	CreatedAt string `json:"created_at"`
}

// DonationFor returns the single donation row for a (request, donor) pair.
// The pair is unique in the schema, so a donor accept and a later
// POST /requests/{id}/donated resolve to the same row. ErrNotFound means no
// donation has been recorded yet.
func (s *Store) DonationFor(ctx context.Context, requestID, donorID string) (Donation, error) {
	var d Donation
	err := s.db.QueryRowContext(ctx, `
		SELECT id, request_id, donor_id, units, created_at
		FROM donations WHERE request_id = ? AND donor_id = ?`, requestID, donorID).
		Scan(&d.ID, &d.RequestID, &d.DonorID, &d.Units, &d.CreatedAt)
	if errors.Is(err, sql.ErrNoRows) {
		return Donation{}, ErrNotFound
	}
	return d, err
}

// DonationCount counts a donor's donation rows. Pledges written on accept are
// included, so a repeat POST /donated never double-counts.
func (s *Store) DonationCount(ctx context.Context, donorID string) (int, error) {
	var count int
	err := s.db.QueryRowContext(ctx, `
		SELECT COUNT(*) FROM donations WHERE donor_id = ?`, donorID).Scan(&count)
	return count, err
}
