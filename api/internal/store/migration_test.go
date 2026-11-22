package store

import (
	"context"
	"database/sql"
	"path/filepath"
	"strings"
	"testing"

	"bloodline/db"
)

func TestOpenMigratesLegacyRequestsTable(t *testing.T) {
	path := filepath.Join(t.TempDir(), "legacy-requests.db")
	legacy, err := sql.Open("sqlite", path)
	if err != nil {
		t.Fatalf("sql.Open: %v", err)
	}
	// Recreate the pre-D28 CHECK constraint; CREATE TABLE IF NOT EXISTS on
	// Open would otherwise leave the legacy definition in place.
	legacySchema := strings.ReplaceAll(db.Schema,
		"urgency IN ('low','medium','high','critical')",
		"urgency IN ('critical','urgent','planned')")
	if _, err := legacy.Exec(legacySchema); err != nil {
		t.Fatalf("apply legacy schema: %v", err)
	}
	_, err = legacy.Exec(`
		INSERT INTO users (id, name, role, blood_group, lat, lng)
		VALUES ('u1', 'Ravi', 'requester', 'O+', 21, 79);
		INSERT INTO requests (id, requester_id, blood_group, units, hospital,
			urgency, lat, lng, status, channel_id, created_at)
		VALUES
			('r1', 'u1', 'O+', 1, 'H1', 'urgent', 21, 79, 'open', 'reqr1', '2026-11-22 10:00:00'),
			('r2', 'u1', 'O+', 1, 'H2', 'planned', 21, 79, 'open', 'reqr2', '');`)
	if err != nil {
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
	r1, err := st.RequestByID(ctx, "r1")
	if err != nil {
		t.Fatalf("RequestByID(r1): %v", err)
	}
	if r1.Urgency != "high" || r1.CreatedAt != "2026-11-22T10:00:00Z" {
		t.Errorf("r1 = %+v, want urgency high and RFC3339 created_at", r1)
	}
	r2, err := st.RequestByID(ctx, "r2")
	if err != nil {
		t.Fatalf("RequestByID(r2): %v", err)
	}
	if r2.Urgency != "low" || !rfc3339UTC.MatchString(r2.CreatedAt) {
		t.Errorf("r2 = %+v, want urgency low and RFC3339 created_at", r2)
	}

	var definition string
	if err := st.db.QueryRow(
		`SELECT sql FROM sqlite_master WHERE type = 'table' AND name = 'requests'`,
	).Scan(&definition); err != nil {
		t.Fatalf("read requests schema: %v", err)
	}
	if strings.Contains(definition, "'urgent'") || strings.Contains(definition, "'planned'") {
		t.Errorf("migrated schema still allows legacy urgencies: %s", definition)
	}
	if _, err := st.db.ExecContext(ctx, `
		INSERT INTO requests (id, requester_id, blood_group, units, hospital, urgency, lat, lng)
		VALUES ('r3', 'u1', 'O+', 1, 'H3', 'urgent', 21, 79)`); err == nil {
		t.Error("legacy urgency 'urgent' was accepted after migration")
	}
}
