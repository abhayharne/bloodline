package store

import (
	"context"
)

// Stock is one blood group's unit count for a bank.
type Stock struct {
	BloodGroup string `json:"blood_group"`
	Units      int    `json:"units"`
	UpdatedAt  string `json:"updated_at"`
}

// BankStock returns all stock rows for a bank, ordered by blood group.
func (s *Store) BankStock(ctx context.Context, bankID string) ([]Stock, error) {
	rows, err := s.db.QueryContext(ctx, `
		SELECT blood_group, units, updated_at
		FROM bank_stock WHERE bank_id = ?
		ORDER BY blood_group`, bankID)
	if err != nil {
		return nil, err
	}
	defer rows.Close()

	stock := make([]Stock, 0)
	for rows.Next() {
		var item Stock
		if err := rows.Scan(&item.BloodGroup, &item.Units, &item.UpdatedAt); err != nil {
			return nil, err
		}
		item.UpdatedAt = NormaliseTimestamp(item.UpdatedAt)
		stock = append(stock, item)
	}
	if err := rows.Err(); err != nil {
		return nil, err
	}
	return stock, nil
}

// UpsertBankStock inserts or updates the given blood groups for a bank.
func (s *Store) UpsertBankStock(ctx context.Context, bankID string, stock []Stock) error {
	tx, err := s.db.BeginTx(ctx, nil)
	if err != nil {
		return err
	}
	defer tx.Rollback()

	for _, item := range stock {
		if _, err := tx.ExecContext(ctx, `
			INSERT INTO bank_stock (bank_id, blood_group, units, updated_at)
			VALUES (?, ?, ?, ?)
			ON CONFLICT (bank_id, blood_group) DO UPDATE SET
				units = excluded.units,
				updated_at = excluded.updated_at`,
			bankID, item.BloodGroup, item.Units, Timestamp(),
		); err != nil {
			return err
		}
	}
	return tx.Commit()
}
