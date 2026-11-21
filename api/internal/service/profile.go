package service

import (
	"context"
	"time"

	"bloodline/internal/matching"
	"bloodline/internal/store"
)

// Rank is the client-safe badge shape returned by /me. The ranks feature (A12)
// fills it in; until then the field is deliberately null. Fixing the wire
// shape now lets clients rely on it from day one.
type Rank struct {
	Key   string `json:"key"`
	Label string `json:"label"`
}

// DerivedProfile is the eligibility summary returned alongside the profile.
type DerivedProfile struct {
	Eligible       bool    `json:"eligible"`
	NextEligibleAt *string `json:"next_eligible_at"`
	DonationCount  int     `json:"donation_count"`
	Rank           *Rank   `json:"rank"`
}

// ProfileView is the response for GET /me and PUT /me.
type ProfileView struct {
	User    store.User     `json:"user"`
	Derived DerivedProfile `json:"derived"`
}

// ProfileInput is the validated shape of PUT /me. Pointers distinguish an
// omitted field from an explicit zero value.
type ProfileInput struct {
	Available     *bool
	Lat           *float64
	Lng           *float64
	WeightKG      *float64
	HeightCM      *float64
	LastDonatedAt *string
}

// Profile loads a user and computes the derived eligibility summary.
func (s *Service) Profile(ctx context.Context, userID string) (ProfileView, error) {
	user, err := s.store.UserByID(ctx, userID)
	if err != nil {
		return ProfileView{}, err
	}
	return s.profileView(ctx, user)
}

// UpdateProfile applies a partial profile update and returns the fresh view,
// so a client never has to follow a PUT with a GET.
func (s *Service) UpdateProfile(ctx context.Context, userID string, in ProfileInput) (ProfileView, error) {
	update, err := validateProfileInput(in)
	if err != nil {
		return ProfileView{}, err
	}
	if err := s.store.UpdateProfile(ctx, userID, update); err != nil {
		return ProfileView{}, err
	}
	return s.Profile(ctx, userID)
}

func (s *Service) profileView(ctx context.Context, user store.User) (ProfileView, error) {
	count, err := s.store.DonationCount(ctx, user.ID)
	if err != nil {
		return ProfileView{}, err
	}
	view := ProfileView{User: user, Derived: DerivedProfile{DonationCount: count}}
	if user.Role != "donor" {
		return view, nil
	}

	donor := matching.FromUser(user)
	// The addendum treats unknown age/weight as eligible (permissive), while
	// the tested pure matching.Eligible requires them to be known. Fill only
	// unknown values with known-eligible defaults so the pure rule stays
	// untouched and the /me contract stays permissive.
	age := 30
	weight := 60.0
	if donor.Age == nil {
		donor.Age = &age
	}
	if donor.WeightKG == nil {
		donor.WeightKG = &weight
	}
	now := time.Now()
	view.Derived.Eligible = matching.Eligible(donor, now)
	if next := matching.NextEligibleAt(donor, now); next != nil {
		value := next.UTC().Format("2006-01-02")
		view.Derived.NextEligibleAt = &value
	}
	return view, nil
}

func validateProfileInput(in ProfileInput) (store.ProfileUpdate, error) {
	update := store.ProfileUpdate{
		Available: in.Available,
		Lat:       in.Lat,
		Lng:       in.Lng,
		WeightKG:  in.WeightKG,
		HeightCM:  in.HeightCM,
	}
	if in.Lat != nil && (*in.Lat < -90 || *in.Lat > 90) {
		return store.ProfileUpdate{}, invalid("lat must be between -90 and 90")
	}
	if in.Lng != nil && (*in.Lng < -180 || *in.Lng > 180) {
		return store.ProfileUpdate{}, invalid("lng must be between -180 and 180")
	}
	if in.WeightKG != nil && *in.WeightKG < 0 {
		return store.ProfileUpdate{}, invalid("weight_kg must not be negative")
	}
	if in.HeightCM != nil && *in.HeightCM < 0 {
		return store.ProfileUpdate{}, invalid("height_cm must not be negative")
	}
	if in.LastDonatedAt != nil {
		value, err := parseDonationDate(*in.LastDonatedAt)
		if err != nil {
			return store.ProfileUpdate{}, err
		}
		update.LastDonatedAt = &value
	}
	return update, nil
}
