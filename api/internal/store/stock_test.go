package store

import (
	"context"
	"testing"
)

func createBank(t *testing.T, st *Store, id string) {
	t.Helper()
	if err := st.CreateUser(context.Background(), User{
		ID: id, Name: "Bank " + id, Role: "bank",
	}); err != nil {
		t.Fatalf("CreateUser(%s): %v", id, err)
	}
}

func TestBankStockEmpty(t *testing.T) {
	st := newTestStore(t)
	createBank(t, st, "ubank")

	stock, err := st.BankStock(context.Background(), "ubank")
	if err != nil {
		t.Fatalf("BankStock: %v", err)
	}
	if stock == nil {
		t.Fatal("BankStock returned nil, want empty slice")
	}
	if len(stock) != 0 {
		t.Errorf("stock = %+v, want empty", stock)
	}
}

func TestUpsertAndReadBankStock(t *testing.T) {
	st := newTestStore(t)
	createBank(t, st, "ubank")
	ctx := context.Background()

	if err := st.UpsertBankStock(ctx, "ubank", []Stock{
		{BloodGroup: "O+", Units: 5},
		{BloodGroup: "O-", Units: 0},
	}); err != nil {
		t.Fatalf("UpsertBankStock: %v", err)
	}

	stock, err := st.BankStock(ctx, "ubank")
	if err != nil {
		t.Fatalf("BankStock: %v", err)
	}
	if len(stock) != 2 {
		t.Fatalf("stock = %+v, want 2 rows", stock)
	}
	if stock[0].BloodGroup != "O+" || stock[0].Units != 5 {
		t.Errorf("first row = %+v", stock[0])
	}
	if stock[0].UpdatedAt == "" {
		t.Error("updated_at is empty")
	}
	if stock[1].BloodGroup != "O-" || stock[1].Units != 0 {
		t.Errorf("second row = %+v", stock[1])
	}
}

func TestUpsertUpdatesExistingStock(t *testing.T) {
	st := newTestStore(t)
	createBank(t, st, "ubank")
	ctx := context.Background()

	if err := st.UpsertBankStock(ctx, "ubank", []Stock{{BloodGroup: "A+", Units: 2}}); err != nil {
		t.Fatalf("first UpsertBankStock: %v", err)
	}
	if err := st.UpsertBankStock(ctx, "ubank", []Stock{{BloodGroup: "A+", Units: 7}}); err != nil {
		t.Fatalf("second UpsertBankStock: %v", err)
	}

	stock, err := st.BankStock(ctx, "ubank")
	if err != nil {
		t.Fatalf("BankStock: %v", err)
	}
	if len(stock) != 1 || stock[0].Units != 7 {
		t.Errorf("stock = %+v, want one A+ row with 7 units", stock)
	}
}
