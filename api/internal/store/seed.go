package store

import (
	"context"
	"fmt"

	"bloodline/db"
)

// Reset replaces all mutable demo data with the embedded db/seed.sql dataset.
// The deletes and inserts run in one transaction, so a failure leaves the
// previous data intact. Only the DEV=1 /dev/reset endpoint calls this.
func (s *Store) Reset(ctx context.Context) error {
	tx, err := s.db.BeginTx(ctx, nil)
	if err != nil {
		return err
	}
	defer tx.Rollback()

	if _, err := tx.ExecContext(ctx, db.Seed); err != nil {
		return fmt.Errorf("apply seed: %w", err)
	}
	return tx.Commit()
}

// Reseed is an alias for Reset kept for callers that use the older name.
func (s *Store) Reseed(ctx context.Context) error { return s.Reset(ctx) }

// SeedOnEmpty initializes fictional accounts and stock only when every mutable
// table is empty. No static request is exposed without a real Nexconn room.
func (s *Store) SeedOnEmpty(ctx context.Context) (bool, error) {
	tx, err := s.db.BeginTx(ctx, nil)
	if err != nil {
		return false, err
	}
	defer tx.Rollback()
	var rows int
	err = tx.QueryRowContext(ctx, `SELECT
 (SELECT COUNT(*) FROM users) + (SELECT COUNT(*) FROM bank_stock) +
 (SELECT COUNT(*) FROM requests) + (SELECT COUNT(*) FROM request_members) +
 (SELECT COUNT(*) FROM donations) + (SELECT COUNT(*) FROM notifications)`).Scan(&rows)
	if err != nil {
		return false, err
	}
	if rows != 0 {
		return false, nil
	}
	if _, err = tx.ExecContext(ctx, db.Seed); err != nil {
		return false, fmt.Errorf("seed empty database: %w", err)
	}
	if _, err = tx.ExecContext(ctx, "DELETE FROM request_members; DELETE FROM requests;"); err != nil {
		return false, err
	}
	if err = tx.Commit(); err != nil {
		return false, err
	}
	return true, nil
}
