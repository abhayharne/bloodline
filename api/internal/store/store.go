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

	return &Store{db: d}, nil
}

// Close closes the underlying database.
func (s *Store) Close() error {
	return s.db.Close()
}
