package store

import (
	"context"
	"path/filepath"
	"testing"
)

func openSeededStore(t *testing.T) *Store {
	t.Helper()
	st, err := Open(filepath.Join(t.TempDir(), "seed.db"))
	if err != nil {
		t.Fatalf("Open: %v", err)
	}
	t.Cleanup(func() { st.Close() })
	if err := st.Reset(context.Background()); err != nil {
		t.Fatalf("Reset: %v", err)
	}
	return st
}

func TestReseedLoadsDemoData(t *testing.T) {
	st := openSeededStore(t)
	ctx := context.Background()

	var donors, banks, stock, requests, members, phones int
	if err := st.db.QueryRowContext(ctx, `SELECT
		(SELECT COUNT(*) FROM users WHERE role='donor'),
		(SELECT COUNT(*) FROM users WHERE role='bank'),
		(SELECT COUNT(*) FROM bank_stock),
		(SELECT COUNT(*) FROM requests),
		(SELECT COUNT(*) FROM request_members),
		(SELECT COUNT(*) FROM users WHERE phone IS NOT NULL)`,
	).Scan(&donors, &banks, &stock, &requests, &members, &phones); err != nil {
		t.Fatalf("count seed rows: %v", err)
	}
	if donors != 5 || banks != 2 || stock != 7 || requests != 1 || members != 3 || phones != 8 {
		t.Fatalf("seed counts = donors %d banks %d stock %d requests %d members %d phones %d",
			donors, banks, stock, requests, members, phones)
	}

	r, err := st.RequestByID(ctx, "rseed1")
	if err != nil {
		t.Fatalf("RequestByID: %v", err)
	}
	if r.Status != "open" || r.ChannelID != "reqrseed1" || r.RequesterID != "ureq1" ||
		r.BloodGroup != "O-" || r.Units != 2 {
		t.Errorf("seeded request = %+v", r)
	}

	asha, err := st.UserByPhone(ctx, "+919999900002")
	if err != nil {
		t.Fatalf("UserByPhone: %v", err)
	}
	if asha.ID != "udon1" || asha.Name != "Asha" || asha.BloodGroup == nil ||
		*asha.BloodGroup != "O-" || !asha.Available {
		t.Errorf("seeded donor = %+v", asha)
	}
}

func TestReseedIsRepeatableAndClearsTransientRows(t *testing.T) {
	st := openSeededStore(t)
	ctx := context.Background()

	if _, err := st.db.ExecContext(ctx, `
		INSERT INTO donations (id,request_id,donor_id,units) VALUES ('d1','rseed1','udon1',2);
		INSERT INTO notifications (id,user_id,type,title,body) VALUES ('n1','udon1','welcome','Hi','Body');
	`); err != nil {
		t.Fatalf("insert transient rows: %v", err)
	}

	if err := st.Reset(ctx); err != nil {
		t.Fatalf("second Reset: %v", err)
	}
	var donations, notifications, requests int
	if err := st.db.QueryRowContext(ctx, `SELECT
		(SELECT COUNT(*) FROM donations),
		(SELECT COUNT(*) FROM notifications),
		(SELECT COUNT(*) FROM requests)`,
	).Scan(&donations, &notifications, &requests); err != nil {
		t.Fatalf("count after reseed: %v", err)
	}
	if donations != 0 || notifications != 0 || requests != 1 {
		t.Errorf("after reseed: donations %d notifications %d requests %d", donations, notifications, requests)
	}
}

func TestSeedOnEmptyNeverResetsExistingData(t *testing.T) {
	st, err := Open(filepath.Join(t.TempDir(), "boot.db"))
	if err != nil {
		t.Fatal(err)
	}
	defer st.Close()
	ctx := context.Background()
	seeded, err := st.SeedOnEmpty(ctx)
	if err != nil || !seeded {
		t.Fatalf("first seed=%v err=%v", seeded, err)
	}
	var users, requests int
	if err := st.db.QueryRowContext(ctx, "SELECT (SELECT COUNT(*) FROM users),(SELECT COUNT(*) FROM requests)").Scan(&users, &requests); err != nil {
		t.Fatal(err)
	}
	if users != 8 || requests != 0 {
		t.Fatalf("users=%d requests=%d", users, requests)
	}
	if _, err := st.db.ExecContext(ctx, "UPDATE users SET name='Preserved' WHERE id='ureq1'"); err != nil {
		t.Fatal(err)
	}
	seeded, err = st.SeedOnEmpty(ctx)
	if err != nil || seeded {
		t.Fatalf("second seed=%v err=%v", seeded, err)
	}
	u, err := st.UserByPhone(ctx, "+919999900001")
	if err != nil || u.Name != "Preserved" {
		t.Fatalf("existing data changed: %v", err)
	}
}
func TestSeedOnEmptyPreservesPartialDatabase(t *testing.T) {
	st, err := Open(filepath.Join(t.TempDir(), "partial.db"))
	if err != nil {
		t.Fatal(err)
	}
	defer st.Close()
	ctx := context.Background()
	_, err = st.db.ExecContext(ctx, "INSERT INTO users(id,name,role) VALUES('upartial','Keep','requester')")
	if err != nil {
		t.Fatal(err)
	}
	seeded, err := st.SeedOnEmpty(ctx)
	if err != nil || seeded {
		t.Fatalf("partial seed=%v err=%v", seeded, err)
	}
	var count int
	if err := st.db.QueryRowContext(ctx, "SELECT COUNT(*) FROM users").Scan(&count); err != nil {
		t.Fatal(err)
	}
	if count != 1 {
		t.Fatalf("partial DB overwritten: %d users", count)
	}
}
