package service

import (
	"context"

	"bloodline/internal/store"
)

// StockInput is one blood group row from PUT /banks/me/stock.
type StockInput struct {
	BloodGroup string
	Units      int
}

// BankStock returns the caller bank's current stock.
func (s *Service) BankStock(ctx context.Context, bankID string) ([]store.Stock, error) {
	return s.store.BankStock(ctx, bankID)
}

// UpdateBankStock validates and upserts stock rows, returning the full stock.
func (s *Service) UpdateBankStock(ctx context.Context, bankID string, in []StockInput) ([]store.Stock, error) {
	if len(in) == 0 {
		return nil, invalid("stock must contain at least one blood group")
	}

	stock := make([]store.Stock, 0, len(in))
	seen := make(map[string]bool, len(in))
	for _, row := range in {
		group := normaliseBloodGroup(row.BloodGroup)
		if !validBloodGroups[group] {
			return nil, invalid("blood_group must be one of A+, A-, B+, B-, AB+, AB-, O+, O-")
		}
		if seen[group] {
			return nil, invalid("duplicate blood_group " + group)
		}
		if row.Units < 0 {
			return nil, invalid("units must be zero or more")
		}
		seen[group] = true
		stock = append(stock, store.Stock{BloodGroup: group, Units: row.Units})
	}

	if err := s.store.UpsertBankStock(ctx, bankID, stock); err != nil {
		return nil, err
	}
	return s.store.BankStock(ctx, bankID)
}
