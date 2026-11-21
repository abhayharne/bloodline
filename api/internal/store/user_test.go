package store

import (
	"context"
	"errors"
	"path/filepath"
	"testing"
)

func newTestStore(t *testing.T) *Store {
	t.Helper()
	st, err := Open(filepath.Join(t.TempDir(), "test.db"))
	if err != nil {
		t.Fatalf("Open: %v", err)
	}
	t.Cleanup(func() { st.Close() })
	return st
}

func TestCreateAndFindUser(t *testing.T) {
	st := newTestStore(t)
	ctx := context.Background()
	group := "O+"

	want := User{
		ID: "u123", Name: "Asha", Role: "donor", BloodGroup: &group, Lat: 21.1, Lng: 79.1,
	}
	if err := st.CreateUser(ctx, want); err != nil {
		t.Fatalf("CreateUser: %v", err)
	}

	byName, err := st.UserByNameRole(ctx, "Asha", "donor")
	if err != nil {
		t.Fatalf("UserByNameRole: %v", err)
	}
	if byName.ID != want.ID || byName.Name != want.Name || byName.Role != want.Role {
		t.Errorf("byName = %+v", byName)
	}
	if byName.BloodGroup == nil || *byName.BloodGroup != group {
		t.Errorf("BloodGroup = %v, want %s", byName.BloodGroup, group)
	}

	byID, err := st.UserByID(ctx, "u123")
	if err != nil {
		t.Fatalf("UserByID: %v", err)
	}
	if byID.Name != "Asha" {
		t.Errorf("byID.Name = %q", byID.Name)
	}
}

func TestBankUserHasNoBloodGroup(t *testing.T) {
	st := newTestStore(t)
	ctx := context.Background()

	if err := st.CreateUser(ctx, User{
		ID: "ubank", Name: "City Blood Bank", Role: "bank", Lat: 21.1, Lng: 79.1,
	}); err != nil {
		t.Fatalf("CreateUser: %v", err)
	}

	bank, err := st.UserByID(ctx, "ubank")
	if err != nil {
		t.Fatalf("UserByID: %v", err)
	}
	if bank.BloodGroup != nil {
		t.Errorf("BloodGroup = %v, want nil", bank.BloodGroup)
	}
}

func TestCreateUserConflict(t *testing.T) {
	st := newTestStore(t)
	ctx := context.Background()
	group := "A+"
	user := User{ID: "u1", Name: "Ravi", Role: "requester", BloodGroup: &group}

	if err := st.CreateUser(ctx, user); err != nil {
		t.Fatalf("first CreateUser: %v", err)
	}
	user.ID = "u2"
	if err := st.CreateUser(ctx, user); !errors.Is(err, ErrConflict) {
		t.Fatalf("second CreateUser error = %v, want ErrConflict", err)
	}
}

func TestCreateUserWithPhoneAndProfile(t *testing.T) {
	st := newTestStore(t)
	ctx := context.Background()
	group, phone, sex, last := "O+", "+919876543210", "female", "2026-01-01"
	age, weight, height := 28, 58.5, 163.0
	consent := "2026-11-22 10:00:00"

	want := User{
		ID: "u1", Name: "Asha", Role: "donor", BloodGroup: &group,
		Phone: &phone, Sex: &sex, Age: &age, WeightKG: &weight, HeightCM: &height,
		DonatedBefore: true, LastDonatedAt: &last, Available: true, ConsentAt: &consent,
	}
	if err := st.CreateUser(ctx, want); err != nil {
		t.Fatalf("CreateUser: %v", err)
	}

	got, err := st.UserByPhone(ctx, phone)
	if err != nil {
		t.Fatalf("UserByPhone: %v", err)
	}
	if got.ID != "u1" || got.Phone == nil || *got.Phone != phone ||
		got.Sex == nil || *got.Sex != sex || got.Age == nil || *got.Age != age ||
		got.WeightKG == nil || *got.WeightKG != weight || got.HeightCM == nil || *got.HeightCM != height ||
		!got.DonatedBefore || got.LastDonatedAt == nil || *got.LastDonatedAt != last ||
		!got.Available || got.ConsentAt == nil || *got.ConsentAt != consent {
		t.Errorf("UserByPhone = %+v", got)
	}
}

func TestCreateUserDuplicatePhone(t *testing.T) {
	st := newTestStore(t)
	ctx := context.Background()
	phone := "+919876543210"
	if err := st.CreateUser(ctx, User{ID: "u1", Name: "A", Role: "donor", Phone: &phone}); err != nil {
		t.Fatalf("first CreateUser: %v", err)
	}
	if err := st.CreateUser(ctx, User{ID: "u2", Name: "B", Role: "donor", Phone: &phone}); !errors.Is(err, ErrConflict) {
		t.Fatalf("second CreateUser error = %v, want ErrConflict", err)
	}
}

func TestFindUserNotFound(t *testing.T) {
	st := newTestStore(t)
	ctx := context.Background()

	if _, err := st.UserByNameRole(ctx, "Nobody", "donor"); !errors.Is(err, ErrNotFound) {
		t.Fatalf("UserByNameRole error = %v, want ErrNotFound", err)
	}
	if _, err := st.UserByID(ctx, "missing"); !errors.Is(err, ErrNotFound) {
		t.Fatalf("UserByID error = %v, want ErrNotFound", err)
	}
}

func TestUpdateProfilePartialAndClear(t *testing.T) {
	st := newTestStore(t)
	ctx := context.Background()
	if err := st.CreateUser(ctx, User{
		ID: "u1", Name: "Asha", Role: "donor", Lat: 21.1, Lng: 79.1, Available: true,
	}); err != nil {
		t.Fatal(err)
	}

	// An empty update is a harmless no-op.
	if err := st.UpdateProfile(ctx, "u1", ProfileUpdate{}); err != nil {
		t.Fatalf("empty update: %v", err)
	}

	available := false
	weight := 58.0
	last := "2026-01-01"
	lat := 22.0
	if err := st.UpdateProfile(ctx, "u1", ProfileUpdate{
		Available: &available, WeightKG: &weight, LastDonatedAt: &last, Lat: &lat,
	}); err != nil {
		t.Fatal(err)
	}
	got, err := st.UserByID(ctx, "u1")
	if err != nil {
		t.Fatal(err)
	}
	if got.Available || got.WeightKG == nil || *got.WeightKG != weight ||
		got.LastDonatedAt == nil || *got.LastDonatedAt != last || got.Lat != lat ||
		got.Lng != 79.1 {
		t.Fatalf("partial update = %+v", got)
	}

	empty := ""
	if err := st.UpdateProfile(ctx, "u1", ProfileUpdate{LastDonatedAt: &empty}); err != nil {
		t.Fatal(err)
	}
	got, err = st.UserByID(ctx, "u1")
	if err != nil {
		t.Fatal(err)
	}
	if got.LastDonatedAt != nil {
		t.Fatalf("LastDonatedAt = %q, want cleared", *got.LastDonatedAt)
	}

	if err := st.UpdateProfile(ctx, "missing", ProfileUpdate{Lat: &lat}); !errors.Is(err, ErrNotFound) {
		t.Fatalf("missing user update error = %v, want ErrNotFound", err)
	}
}
