package service

import (
	"context"
	"strings"
	"testing"

	"bloodline/internal/store"
)

func TestHospitalsSearchAndValidation(t *testing.T) {
	env := newTestService(t)

	all, err := env.svc.Hospitals(HospitalQuery{})
	if err != nil {
		t.Fatal(err)
	}
	if len(all) != 12 {
		t.Fatalf("all hospitals = %d, want 12", len(all))
	}
	for i := 1; i < len(all); i++ {
		if all[i-1].Name > all[i].Name {
			t.Fatalf("default order not by name: %q before %q", all[i-1].Name, all[i].Name)
		}
	}

	byArea, err := env.svc.Hospitals(HospitalQuery{Q: "mihan"})
	if err != nil || len(byArea) == 0 {
		t.Fatalf("area search = %v, %v", byArea, err)
	}
	for _, h := range byArea {
		if !strings.Contains(strings.ToLower(h.Area), "mihan") &&
			!strings.Contains(strings.ToLower(h.Name), "mihan") {
			t.Fatalf("area search returned %+v", h)
		}
	}

	byName, err := env.svc.Hospitals(HospitalQuery{Q: "CITY"})
	if err != nil || len(byName) == 0 || byName[0].ID != "hcity" {
		t.Fatalf("name search = %v, %v", byName, err)
	}

	near, err := env.svc.Hospitals(HospitalQuery{
		Q: "hospital", Lat: floatPtr(21.1460), Lng: floatPtr(79.0870), Limit: intPtr(3),
	})
	if err != nil || len(near) != 3 {
		t.Fatalf("nearby search = %v, %v", near, err)
	}

	bad := []HospitalQuery{
		{Lat: floatPtr(21)},
		{Lat: floatPtr(91), Lng: floatPtr(0)},
		{Lng: floatPtr(181), Lat: floatPtr(0)},
		{Limit: intPtr(51)},
		{Limit: intPtr(0)},
		{Limit: intPtr(-1)},
	}
	for _, q := range bad {
		if _, err := env.svc.Hospitals(q); err == nil {
			t.Fatalf("Hospitals(%+v): want validation error", q)
		}
	}
}

func TestCreateRequestHospitalIDAndComponent(t *testing.T) {
	env := newTestService(t)
	ctx := context.Background()
	createUser(t, env.st, store.User{ID: "uReq", Name: "Ravi", Role: "requester"})

	result, err := env.svc.CreateRequest(ctx, RequestInput{
		RequesterID: "uReq", RequesterName: "Ravi", BloodGroup: "O-", Units: 2,
		HospitalID: "hcity", Urgency: "critical",
		// Supplied coordinates and name must be ignored in favour of the id.
		Hospital: "Wrong Hospital", Lat: floatPtr(0), Lng: floatPtr(0),
		Component: ComponentPlasma, Notes: "  Patient in ward 4  ",
	})
	if err != nil {
		t.Fatal(err)
	}
	r := result.Request
	if r.Hospital != "City Hospital" || r.Lat != 21.1458 || r.Lng != 79.0882 {
		t.Fatalf("resolved hospital = %q at (%v,%v)", r.Hospital, r.Lat, r.Lng)
	}
	if r.Component != ComponentPlasma || r.Notes != "Patient in ward 4" {
		t.Fatalf("component/notes = %q/%q", r.Component, r.Notes)
	}

	stored, err := env.st.RequestByID(ctx, r.ID)
	if err != nil {
		t.Fatal(err)
	}
	if stored.Component != ComponentPlasma || stored.Notes != "Patient in ward 4" {
		t.Fatalf("stored component/notes = %q/%q", stored.Component, stored.Notes)
	}

	// The feed (as the requester) must expose the new row with status open and
	// the additive component/notes fields.
	views, err := env.svc.Requests(ctx, "uReq", "requester", "")
	if err != nil || len(views) != 1 {
		t.Fatalf("requester feed = %v, %v", views, err)
	}
	if views[0].ID != r.ID || views[0].Status != "open" ||
		views[0].Component != ComponentPlasma || views[0].Notes != "Patient in ward 4" {
		t.Fatalf("feed row = %+v", views[0])
	}
}

func TestCreateRequestValidation(t *testing.T) {
	env := newTestService(t)
	ctx := context.Background()
	createUser(t, env.st, store.User{ID: "uReq", Name: "Ravi", Role: "requester"})

	base := RequestInput{
		RequesterID: "uReq", BloodGroup: "O-", Units: 1,
		HospitalID: "hcity", Urgency: "critical",
	}
	tests := map[string]func(*RequestInput){
		"bad blood group":  func(in *RequestInput) { in.BloodGroup = "Z+" },
		"no units":         func(in *RequestInput) { in.Units = 0 },
		"bad urgency":      func(in *RequestInput) { in.Urgency = "whenever" },
		"unknown hospital": func(in *RequestInput) { in.HospitalID = "nope" },
		"bad component":    func(in *RequestInput) { in.Component = "bones" },
		"long notes":       func(in *RequestInput) { in.Notes = strings.Repeat("x", 501) },
	}
	for name, mutate := range tests {
		t.Run(name, func(t *testing.T) {
			in := base
			mutate(&in)
			if _, err := env.svc.CreateRequest(ctx, in); err == nil {
				t.Fatal("expected validation error")
			}
		})
	}

	t.Run("missing coordinates", func(t *testing.T) {
		in := base
		in.HospitalID = ""
		in.Hospital = "City Hospital"
		if _, err := env.svc.CreateRequest(ctx, in); err == nil {
			t.Fatal("expected validation error")
		}
	})

	t.Run("default component", func(t *testing.T) {
		in := base
		result, err := env.svc.CreateRequest(ctx, in)
		if err != nil {
			t.Fatal(err)
		}
		if result.Request.Component != ComponentWholeBlood {
			t.Fatalf("component = %q, want whole_blood", result.Request.Component)
		}
	})
}

func TestComponentAwareMatching(t *testing.T) {
	env := newTestService(t)
	ctx := context.Background()
	group := "O+"
	createUser(t, env.st, store.User{ID: "uReq", Name: "Ravi", Role: "requester"})
	createUser(t, env.st, store.User{ID: "uBankPlasma", Name: "Plasma Bank", Role: "bank"})
	createUser(t, env.st, store.User{ID: "uBankWhole", Name: "Whole Bank", Role: "bank"})
	createUser(t, env.st, store.User{
		ID: "uApheresis", Name: "Apheresis Donor", Role: "donor",
		BloodGroup: &group, Lat: 21.145, Lng: 79.088, Available: true, ApheresisOK: true,
	})
	createUser(t, env.st, store.User{
		ID: "uRegular", Name: "Regular Donor", Role: "donor",
		BloodGroup: &group, Lat: 21.146, Lng: 79.089, Available: true,
	})
	createUser(t, env.st, store.User{
		ID: "uDistant", Name: "Distant Donor", Role: "donor",
		BloodGroup: &group, Lat: 22, Lng: 79.088, Available: true, ApheresisOK: true,
	})
	if err := env.st.UpsertBankStock(ctx, "uBankPlasma", []store.Stock{
		{BloodGroup: group, Component: ComponentPlasma, Units: 5},
		{BloodGroup: "AB+", Component: ComponentPlasma, Units: 5},
	}); err != nil {
		t.Fatal(err)
	}
	if err := env.st.UpsertBankStock(ctx, "uBankWhole", []store.Stock{
		{BloodGroup: group, Component: ComponentWholeBlood, Units: 5},
	}); err != nil {
		t.Fatal(err)
	}

	plasma, err := env.svc.CreateRequest(ctx, RequestInput{
		RequesterID: "uReq", BloodGroup: group, Units: 2,
		HospitalID: "hcity", Urgency: "high", Component: ComponentPlasma,
	})
	if err != nil {
		t.Fatal(err)
	}
	if plasma.Banks != 1 || plasma.Donors != 1 {
		t.Fatalf("plasma matches = banks %d donors %d, want 1/1", plasma.Banks, plasma.Donors)
	}

	whole, err := env.svc.CreateRequest(ctx, RequestInput{
		RequesterID: "uReq", BloodGroup: group, Units: 2,
		HospitalID: "hcity", Urgency: "high", Component: ComponentWholeBlood,
	})
	if err != nil {
		t.Fatal(err)
	}
	if whole.Banks != 1 || whole.Donors != 2 {
		t.Fatalf("whole blood matches = banks %d donors %d, want 1/2", whole.Banks, whole.Donors)
	}

	// Donor feed visibility honours the apheresis flag and component rule.
	for _, tc := range []struct {
		userID string
		want   bool
	}{
		{"uApheresis", true},
		{"uRegular", false},
	} {
		views, err := env.svc.Requests(ctx, tc.userID, "donor", "")
		if err != nil {
			t.Fatal(err)
		}
		found := false
		for _, v := range views {
			if v.ID == plasma.Request.ID {
				found = true
			}
		}
		if found != tc.want {
			t.Fatalf("donor %s sees plasma request = %v, want %v", tc.userID, found, tc.want)
		}
	}
}

func TestApheresisProfileRoundTrip(t *testing.T) {
	env := newTestService(t)
	ctx := context.Background()
	group := "O+"
	createUser(t, env.st, store.User{
		ID: "u1", Name: "Asha", Role: "donor", BloodGroup: &group,
	})
	view, err := env.svc.UpdateProfile(ctx, "u1", ProfileInput{ApheresisOK: boolPtr(true)})
	if err != nil {
		t.Fatal(err)
	}
	if !view.User.ApheresisOK {
		t.Fatalf("apheresis_ok = false after enabling")
	}
	view, err = env.svc.Profile(ctx, "u1")
	if err != nil || !view.User.ApheresisOK {
		t.Fatalf("apheresis_ok did not persist: %+v, %v", view.User, err)
	}
}
