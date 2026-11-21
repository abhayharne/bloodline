// Package store owns the SQLite database: opening it, applying the schema and
// running the small set of queries the API needs.
package store

import (
	"database/sql"
	"errors"
	"fmt"

	_ "modernc.org/sqlite"

	"bloodline/db"
)

var (
	// ErrNotFound means the requested row does not exist.
	ErrNotFound = errors.New("not found")
	// ErrConflict means a uniqueness constraint was violated.
	ErrConflict = errors.New("already exists")
)

// Store is a SQLite-backed data store. It is safe for concurrent use.
type Store struct {
	db *sql.DB
}

// Open opens (creating if needed) the SQLite database at path and applies the
// schema. Use ":memory:" for an ephemeral database.
func Open(path string) (*Store, error) {
	if path == "" {
		return nil, errors.New("database path is empty")
	}

	d, err := sql.Open("sqlite", path)
	if err != nil {
		return nil, fmt.Errorf("open sqlite: %w", err)
	}
	// SQLite writes are serialised; one connection avoids SQLITE_BUSY surprises
	// and keeps the per-connection PRAGMAs below in effect.
	d.SetMaxOpenConns(1)
	d.SetMaxIdleConns(1)

	if _, err := d.Exec("PRAGMA foreign_keys = ON"); err != nil {
		d.Close()
		return nil, fmt.Errorf("enable foreign keys: %w", err)
	}
	if _, err := d.Exec("PRAGMA busy_timeout = 5000"); err != nil {
		d.Close()
		return nil, fmt.Errorf("set busy timeout: %w", err)
	}
	if _, err := d.Exec(db.Schema); err != nil {
		d.Close()
		return nil, fmt.Errorf("apply schema: %w", err)
	}
	if err := migrateUsers(d); err != nil {
		d.Close()
		return nil, fmt.Errorf("migrate users: %w", err)
	}

	return &Store{db: d}, nil
}

// migrateUsers adds profile columns to databases created before D11. CREATE
// TABLE IF NOT EXISTS cannot alter an existing users table, so this is the
// idempotent companion to db/schema.sql.
func migrateUsers(d *sql.DB) error {
	rows, err := d.Query("PRAGMA table_info(users)")
	if err != nil {
		return err
	}
	existing := make(map[string]bool)
	for rows.Next() {
		var cid, notNull, primaryKey int
		var name, columnType string
		var defaultValue any
		if err := rows.Scan(&cid, &name, &columnType, &notNull, &defaultValue, &primaryKey); err != nil {
			rows.Close()
			return err
		}
		existing[name] = true
	}
	if err := rows.Err(); err != nil {
		rows.Close()
		return err
	}
	if err := rows.Close(); err != nil {
		return err
	}

	additions := []struct{ name, definition string }{
		// SQLite cannot ALTER TABLE ADD COLUMN with UNIQUE; the index below
		// enforces the same constraint for migrated databases.
		{"phone", "TEXT"},
		{"sex", "TEXT CHECK (sex IS NULL OR sex IN ('male','female','other'))"},
		{"age", "INTEGER CHECK (age IS NULL OR (age >= 0 AND age <= 120))"},
		{"weight_kg", "REAL CHECK (weight_kg IS NULL OR weight_kg >= 0)"},
		{"height_cm", "REAL CHECK (height_cm IS NULL OR height_cm >= 0)"},
		{"donated_before", "INTEGER NOT NULL DEFAULT 0"},
		{"last_donated_at", "TEXT"},
		{"available", "INTEGER NOT NULL DEFAULT 1 CHECK (available IN (0,1))"},
		{"consent_at", "TEXT"},
	}
	for _, column := range additions {
		if existing[column.name] {
			continue
		}
		if _, err := d.Exec("ALTER TABLE users ADD COLUMN " + column.name + " " + column.definition); err != nil {
			return fmt.Errorf("add column %s: %w", column.name, err)
		}
	}
	_, err = d.Exec("CREATE UNIQUE INDEX IF NOT EXISTS idx_users_phone ON users(phone)")
	return err
}

// Close closes the underlying database.
func (s *Store) Close() error {
	return s.db.Close()
}
