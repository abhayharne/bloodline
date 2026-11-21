package store

import (
	"context"
	"database/sql"
	"path/filepath"
	"testing"
)

func TestOpenAppliesSchema(t *testing.T) {
	st, err := Open(filepath.Join(t.TempDir(), "bloodline.db"))
	if err != nil {
		t.Fatalf("Open: %v", err)
	}
	defer st.Close()

	for _, table := range []string{"users", "bank_stock", "requests", "request_members", "donations", "notifications"} {
		var name string
		err := st.db.QueryRow(
			`SELECT name FROM sqlite_master WHERE type = 'table' AND name = ?`, table,
		).Scan(&name)
		if err != nil {
			t.Errorf("table %s missing: %v", table, err)
		}
	}
}

func TestOpenIsIdempotent(t *testing.T) {
	path := filepath.Join(t.TempDir(), "bloodline.db")

	first, err := Open(path)
	if err != nil {
		t.Fatalf("first Open: %v", err)
	}
	if err := first.Close(); err != nil {
		t.Fatalf("close first: %v", err)
	}

	second, err := Open(path)
	if err != nil {
		t.Fatalf("second Open: %v", err)
	}
	defer second.Close()
}

func TestOpenMigratesLegacyUsersTable(t *testing.T) {
	path := filepath.Join(t.TempDir(), "legacy.db")
	legacy, err := sql.Open("sqlite", path)
	if err != nil {
		t.Fatalf("sql.Open: %v", err)
	}
	_, err = legacy.Exec(`CREATE TABLE users (
		id TEXT PRIMARY KEY, name TEXT NOT NULL, role TEXT NOT NULL,
		blood_group TEXT, lat REAL DEFAULT 0, lng REAL DEFAULT 0,
		push_token TEXT, created_at TEXT DEFAULT (datetime('now')))`)
	if err != nil {
		t.Fatalf("create legacy table: %v", err)
	}
	if err := legacy.Close(); err != nil {
		t.Fatalf("close legacy: %v", err)
	}

	st, err := Open(path)
	if err != nil {
		t.Fatalf("Open: %v", err)
	}
	defer st.Close()

	phone := "+919876543210"
	ctx := context.Background()
	if err := st.CreateUser(ctx, User{ID: "u1", Name: "Asha", Role: "donor", Phone: &phone}); err != nil {
		t.Fatalf("CreateUser: %v", err)
	}
	if _, err := st.UserByPhone(ctx, phone); err != nil {
		t.Fatalf("UserByPhone: %v", err)
	}
}

func TestOpenRejectsEmptyPath(t *testing.T) {
	if _, err := Open(""); err == nil {
		t.Fatal("Open(\"\") succeeded, want error")
	}
}
