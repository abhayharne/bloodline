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
