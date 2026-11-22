package store

import (
	"context"
	"database/sql"
	"path/filepath"
	"testing"
)

// TestOpenMigratesLegacyComponentColumns simulates a database created before D29:
// requests have the canonical urgency but no component/notes, bank_stock has the
// old two-column primary key, and users lack apheresis_ok. Open must add/rebuild
// them idempotently while preserving rows.
func TestOpenMigratesLegacyComponentColumns(t *testing.T) {
	path := filepath.Join(t.TempDir(), "legacy-d29.db")
	legacy, err := sql.Open("sqlite", path)
	if err != nil {
		t.Fatalf("sql.Open: %v", err)
	}
	legacySchema := `
		CREATE TABLE users (
			id TEXT PRIMARY KEY, name TEXT NOT NULL, role TEXT NOT NULL,
			blood_group TEXT, lat REAL NOT NULL, lng REAL NOT NULL, push_token TEXT,
			created_at TEXT NOT NULL, UNIQUE(name, role));
		CREATE TABLE bank_stock (
			bank_id TEXT NOT NULL, blood_group TEXT NOT NULL,
			units INTEGER NOT NULL DEFAULT 0, updated_at TEXT NOT NULL,
			PRIMARY KEY (bank_id, blood_group));
		CREATE TABLE requests (
			id TEXT PRIMARY KEY, requester_id TEXT NOT NULL, blood_group TEXT NOT NULL,
			units INTEGER NOT NULL, hospital TEXT NOT NULL,
			urgency TEXT NOT NULL CHECK (urgency IN ('low','medium','high','critical')),
			lat REAL NOT NULL, lng REAL NOT NULL, status TEXT NOT NULL,
			channel_id TEXT, created_at TEXT NOT NULL, fulfilled_at TEXT);
	`
	if _, err := legacy.Exec(legacySchema); err != nil {
		t.Fatalf("apply legacy schema: %v", err)
	}
	if _, err := legacy.Exec(`
		INSERT INTO users (id,name,role,blood_group,lat,lng,created_at)
		VALUES ('ubank','Legacy Bank','bank',NULL,21,79,'2026-11-22T09:00:00Z'),
		       ('udon','Legacy Donor','donor','O+',21,79,'2026-11-22T09:00:00Z');
		INSERT INTO bank_stock (bank_id,blood_group,units,updated_at)
		VALUES ('ubank','O+',7,'2026-11-22T09:00:00Z');
		INSERT INTO requests (id,requester_id,blood_group,units,hospital,urgency,lat,lng,status,channel_id,created_at)
		VALUES ('r1','udon','O+',2,'Legacy Hospital','critical',21,79,'open','reqr1','2026-11-22T09:00:00Z');
	`); err != nil {
		t.Fatalf("insert legacy rows: %v", err)
	}
	if err := legacy.Close(); err != nil {
		t.Fatalf("close legacy: %v", err)
	}

	st, err := Open(path)
	if err != nil {
		t.Fatalf("Open: %v", err)
	}
	defer st.Close()

	ctx := context.Background()
	r, err := st.RequestByID(ctx, "r1")
	if err != nil {
		t.Fatalf("RequestByID: %v", err)
	}
	if r.Component != "whole_blood" || r.Notes != "" {
		t.Fatalf("migrated request component/notes = %q/%q", r.Component, r.Notes)
	}

	stock, err := st.BankStock(ctx, "ubank")
	if err != nil || len(stock) != 1 {
		t.Fatalf("migrated stock = %+v, %v", stock, err)
	}
	if stock[0].Component != "whole_blood" || stock[0].Units != 7 {
		t.Fatalf("migrated stock row = %+v", stock[0])
	}

	donor, err := st.UserByID(ctx, "udon")
	if err != nil {
		t.Fatalf("UserByID: %v", err)
	}
	if donor.ApheresisOK {
		t.Fatal("legacy donor must default to apheresis_ok = false")
	}

	// The new composite PK allows distinct components for one group.
	if err := st.UpsertBankStock(ctx, "ubank", []Stock{
		{BloodGroup: "O+", Component: "whole_blood", Units: 7},
		{BloodGroup: "O+", Component: "plasma", Units: 3},
	}); err != nil {
		t.Fatalf("upsert component stock: %v", err)
	}
	stock, err = st.BankStock(ctx, "ubank")
	if err != nil || len(stock) != 2 {
		t.Fatalf("component stock = %+v, %v", stock, err)
	}
}
