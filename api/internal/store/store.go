// Package store owns the SQLite database: opening it, applying the schema and
// running the small set of queries the API needs.
package store

import (
	"database/sql"
	"errors"
	"fmt"
	"strings"

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
	if err := migrateRequests(d); err != nil {
		d.Close()
		return nil, fmt.Errorf("migrate requests: %w", err)
	}
	if err := migrateRequestColumns(d); err != nil {
		d.Close()
		return nil, fmt.Errorf("migrate request columns: %w", err)
	}
	if err := migrateBankStock(d); err != nil {
		d.Close()
		return nil, fmt.Errorf("migrate bank stock: %w", err)
	}

	return &Store{db: d}, nil
}

// tableColumns returns the column names of table, for idempotent migrations.
func tableColumns(d *sql.DB, table string) (map[string]bool, error) {
	rows, err := d.Query("PRAGMA table_info(" + table + ")")
	if err != nil {
		return nil, err
	}
	defer rows.Close()
	columns := make(map[string]bool)
	for rows.Next() {
		var cid, notNull, primaryKey int
		var name, columnType string
		var defaultValue any
		if err := rows.Scan(&cid, &name, &columnType, &notNull, &defaultValue, &primaryKey); err != nil {
			return nil, err
		}
		columns[name] = true
	}
	return columns, rows.Err()
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
		{"apheresis_ok", "INTEGER NOT NULL DEFAULT 0 CHECK (apheresis_ok IN (0,1))"},
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

// migrateRequests replaces a pre-D28 requests table whose CHECK still allowed
// the legacy urgent/planned urgencies. SQLite cannot ALTER a CHECK constraint,
// so the table is rebuilt in one transaction with the canonical constraint and
// existing rows mapped through the same aliases the API accepts. Foreign keys
// are disabled only for the rebuild; child tables keep pointing at "requests".
func migrateRequests(d *sql.DB) error {
	var definition string
	if err := d.QueryRow(
		`SELECT sql FROM sqlite_master WHERE type = 'table' AND name = 'requests'`,
	).Scan(&definition); err != nil {
		return err
	}
	if strings.Contains(definition, "'low'") &&
		strings.Contains(definition, "'medium'") &&
		strings.Contains(definition, "'high'") {
		return nil // already the canonical constraint
	}

	if _, err := d.Exec("PRAGMA foreign_keys = OFF"); err != nil {
		return err
	}
	defer func() { _, _ = d.Exec("PRAGMA foreign_keys = ON") }()

	tx, err := d.Begin()
	if err != nil {
		return err
	}
	defer tx.Rollback()

	stmts := []string{
		`CREATE TABLE requests_v2 (
			id           TEXT PRIMARY KEY,
			requester_id TEXT NOT NULL REFERENCES users(id),
			blood_group  TEXT NOT NULL CHECK (blood_group IN ('A+','A-','B+','B-','AB+','AB-','O+','O-')),
			units        INTEGER NOT NULL CHECK (units > 0),
			hospital     TEXT NOT NULL,
			urgency      TEXT NOT NULL CHECK (urgency IN ('low','medium','high','critical')),
			lat          REAL NOT NULL,
			lng          REAL NOT NULL,
			status       TEXT NOT NULL DEFAULT 'open' CHECK (status IN ('open','fulfilled','cancelled')),
			channel_id   TEXT,
			created_at   TEXT NOT NULL DEFAULT (strftime('%Y-%m-%dT%H:%M:%SZ','now')),
			fulfilled_at TEXT,
			component    TEXT NOT NULL DEFAULT 'whole_blood' CHECK (component IN
				('whole_blood','red_cells','platelets','plasma','cryo','other')),
			notes        TEXT
		)`,
		`INSERT INTO requests_v2 (id, requester_id, blood_group, units, hospital,
			urgency, lat, lng, status, channel_id, created_at, fulfilled_at)
		SELECT id, requester_id, blood_group, units, hospital,
			CASE lower(trim(urgency))
				WHEN 'urgent' THEN 'high' WHEN 'planned' THEN 'low'
				WHEN 'med' THEN 'medium' WHEN 'critical' THEN 'critical'
				WHEN 'high' THEN 'high' WHEN 'medium' THEN 'medium'
				WHEN 'low' THEN 'low' ELSE 'low' END,
			lat, lng, status, channel_id,
			CASE WHEN trim(created_at) = '' THEN strftime('%Y-%m-%dT%H:%M:%SZ','now')
				ELSE COALESCE(strftime('%Y-%m-%dT%H:%M:%SZ', created_at), trim(created_at)) END,
			CASE WHEN fulfilled_at IS NULL OR trim(fulfilled_at) = '' THEN NULL
				ELSE COALESCE(strftime('%Y-%m-%dT%H:%M:%SZ', fulfilled_at), trim(fulfilled_at)) END
		FROM requests`,
		`DROP TABLE requests`,
		`ALTER TABLE requests_v2 RENAME TO requests`,
		`CREATE INDEX IF NOT EXISTS idx_requests_status ON requests(status)`,
	}
	for _, stmt := range stmts {
		if _, err := tx.Exec(stmt); err != nil {
			return fmt.Errorf("rebuild requests: %w", err)
		}
	}
	return tx.Commit()
}

// migrateRequestColumns covers databases that already had the canonical urgency
// CHECK (so migrateRequests returned early) but predate D29's component/notes.
func migrateRequestColumns(d *sql.DB) error {
	columns, err := tableColumns(d, "requests")
	if err != nil {
		return err
	}
	additions := []struct{ name, definition string }{
		{"component", "TEXT NOT NULL DEFAULT 'whole_blood' CHECK (component IN ('whole_blood','red_cells','platelets','plasma','cryo','other'))"},
		{"notes", "TEXT"},
	}
	for _, column := range additions {
		if columns[column.name] {
			continue
		}
		if _, err := d.Exec("ALTER TABLE requests ADD COLUMN " + column.name + " " + column.definition); err != nil {
			return fmt.Errorf("add column %s: %w", column.name, err)
		}
	}
	return nil
}

// migrateBankStock adds the component dimension to the stock primary key. The
// PK cannot be altered in place, so the table is rebuilt in one transaction;
// every legacy row keeps its units and becomes whole_blood stock.
func migrateBankStock(d *sql.DB) error {
	columns, err := tableColumns(d, "bank_stock")
	if err != nil {
		return err
	}
	if columns["component"] {
		return nil
	}
	if _, err := d.Exec("PRAGMA foreign_keys = OFF"); err != nil {
		return err
	}
	defer func() { _, _ = d.Exec("PRAGMA foreign_keys = ON") }()

	tx, err := d.Begin()
	if err != nil {
		return err
	}
	defer tx.Rollback()

	stmts := []string{
		`CREATE TABLE bank_stock_v2 (
			bank_id     TEXT NOT NULL REFERENCES users(id),
			blood_group TEXT NOT NULL CHECK (blood_group IN ('A+','A-','B+','B-','AB+','AB-','O+','O-')),
			component   TEXT NOT NULL DEFAULT 'whole_blood' CHECK (component IN
				('whole_blood','red_cells','platelets','plasma','cryo','other')),
			units       INTEGER NOT NULL DEFAULT 0 CHECK (units >= 0),
			updated_at  TEXT NOT NULL DEFAULT (strftime('%Y-%m-%dT%H:%M:%SZ','now')),
			PRIMARY KEY (bank_id, blood_group, component)
		)`,
		`INSERT INTO bank_stock_v2 (bank_id, blood_group, units, updated_at)
			SELECT bank_id, blood_group, units, updated_at FROM bank_stock`,
		`DROP TABLE bank_stock`,
		`ALTER TABLE bank_stock_v2 RENAME TO bank_stock`,
	}
	for _, stmt := range stmts {
		if _, err := tx.Exec(stmt); err != nil {
			return fmt.Errorf("rebuild bank_stock: %w", err)
		}
	}
	return tx.Commit()
}

// Close closes the underlying database.
func (s *Store) Close() error {
	return s.db.Close()
}
