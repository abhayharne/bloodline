package store

import (
	"context"
	"errors"
	"testing"
)

func TestDonationForAndCount(t *testing.T) {
	st := newTestStore(t)
	ctx := context.Background()
	group := "O+"
	if err := st.CreateUser(ctx, User{ID: "u1", Name: "Asha", Role: "donor", BloodGroup: &group}); err != nil {
		t.Fatal(err)
	}
	if err := st.CreateUser(ctx, User{ID: "u2", Name: "Ravi", Role: "requester", BloodGroup: &group}); err != nil {
		t.Fatal(err)
	}
	for _, id := range []string{"r1", "r2"} {
		request := Request{
			ID: id, RequesterID: "u2", BloodGroup: group, Units: 2,
			Hospital: "City Hospital", Urgency: "urgent", Lat: 21, Lng: 79, Status: "open",
		}
		if err := st.CreateRequest(ctx, request); err != nil {
			t.Fatal(err)
		}
	}

	if _, err := st.DonationFor(ctx, "r1", "u1"); !errors.Is(err, ErrNotFound) {
		t.Fatalf("DonationFor before insert error = %v, want ErrNotFound", err)
	}

	if err := st.CreateDonation(ctx, Donation{ID: "d1", RequestID: "r1", DonorID: "u1", Units: 2}); err != nil {
		t.Fatal(err)
	}
	donation, err := st.DonationFor(ctx, "r1", "u1")
	if err != nil {
		t.Fatal(err)
	}
	if donation.ID != "d1" || donation.RequestID != "r1" || donation.DonorID != "u1" ||
		donation.Units != 2 || donation.CreatedAt == "" {
		t.Fatalf("DonationFor = %+v", donation)
	}
	count, err := st.DonationCount(ctx, "u1")
	if err != nil || count != 1 {
		t.Fatalf("DonationCount = %d, %v; want 1", count, err)
	}

	// INSERT OR IGNORE: a repeat (request, donor) never double-counts.
	if err := st.CreateDonation(ctx, Donation{ID: "d2", RequestID: "r1", DonorID: "u1", Units: 2}); err != nil {
		t.Fatal(err)
	}
	donation, err = st.DonationFor(ctx, "r1", "u1")
	if err != nil || donation.ID != "d1" {
		t.Fatalf("repeat DonationFor = %+v, %v; want original d1", donation, err)
	}

	if err := st.CreateDonation(ctx, Donation{ID: "d3", RequestID: "r2", DonorID: "u1", Units: 2}); err != nil {
		t.Fatal(err)
	}
	count, err = st.DonationCount(ctx, "u1")
	if err != nil || count != 2 {
		t.Fatalf("DonationCount after second request = %d, %v; want 2", count, err)
	}
	other, err := st.DonationCount(ctx, "u2")
	if err != nil || other != 0 {
		t.Fatalf("other donor count = %d, %v; want 0", other, err)
	}
}
