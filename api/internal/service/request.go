package service

import (
	"context"
	"errors"
	"fmt"
	"slices"
	"sort"
	"strings"
	"time"
	"unicode/utf8"

	"bloodline/data"
	"bloodline/internal/events"
	"bloodline/internal/id"
	"bloodline/internal/matching"
	"bloodline/internal/store"
)

var (
	// ErrForbidden is mapped to HTTP 403 (e.g. fulfilling someone else's request).
	ErrForbidden = errors.New("forbidden")
	// ErrNotOpen is mapped to HTTP 409.
	ErrNotOpen = errors.New("request is not open")
)

// RequestInput is the validated shape of POST /requests.
type RequestInput struct {
	RequesterID   string
	RequesterName string
	BloodGroup    string
	Units         int
	Hospital      string
	HospitalID    string
	Urgency       string
	Lat           *float64
	Lng           *float64
	Component     string
	Notes         string
}

// RequestResult is returned by POST /requests.
type RequestResult struct {
	Request store.Request
	Banks   int
	Donors  int
}

// RequestView is one row of the role-aware request feed.
type RequestView struct {
	store.Request
	DistanceKM    float64 `json:"distance_km"`
	RequesterName string  `json:"requester_name"`
	Joined        bool    `json:"joined"`
}

// CreateRequest stores a request, creates its Nexconn room with the closest
// banks with stock, and emits request.created for the matched users.
func (s *Service) CreateRequest(ctx context.Context, in RequestInput) (RequestResult, error) {
	group := normaliseBloodGroup(in.BloodGroup)
	if !validBloodGroups[group] {
		return RequestResult{}, invalid("blood_group must be one of A+, A-, B+, B-, AB+, AB-, O+, O-")
	}
	if in.Units <= 0 {
		return RequestResult{}, invalid("units must be positive")
	}
	component, err := normaliseComponent(in.Component)
	if err != nil {
		return RequestResult{}, err
	}
	notes := strings.TrimSpace(in.Notes)
	if utf8.RuneCountInString(notes) > 500 {
		return RequestResult{}, invalid("notes must be at most 500 characters")
	}
	urgency, err := normaliseUrgency(in.Urgency)
	if err != nil {
		return RequestResult{}, err
	}

	// hospital_id resolves from the embedded directory and wins over both the
	// free-text hospital name and supplied coordinates.
	hospital := strings.TrimSpace(in.Hospital)
	lat, lng := 0.0, 0.0
	if in.Lat != nil {
		lat = *in.Lat
	}
	if in.Lng != nil {
		lng = *in.Lng
	}
	if hospitalID := strings.TrimSpace(in.HospitalID); hospitalID != "" {
		h, ok := data.ByID(hospitalID)
		if !ok {
			return RequestResult{}, invalid("hospital_id not found")
		}
		hospital, lat, lng = h.Name, h.Lat, h.Lng
	} else {
		if hospital == "" {
			return RequestResult{}, invalid("hospital is required when hospital_id is omitted")
		}
		if in.Lat == nil || in.Lng == nil {
			return RequestResult{}, invalid("lat and lng are required when hospital_id is omitted")
		}
		if err := validateCoordinates(lat, lng); err != nil {
			return RequestResult{}, err
		}
	}

	requestID, err := id.New("r")
	if err != nil {
		return RequestResult{}, err
	}
	channelID := "req" + requestID
	request := store.Request{
		ID:          requestID,
		RequesterID: in.RequesterID,
		BloodGroup:  group,
		Units:       in.Units,
		Hospital:    hospital,
		Urgency:     urgency,
		Lat:         lat,
		Lng:         lng,
		Status:      "open",
		ChannelID:   channelID,
		CreatedAt:   store.Timestamp(),
		Component:   component,
		Notes:       notes,
	}

	// Whole blood/red cells/other keep the exact-group live rule (D4). Apheresis
	// components use compatible groups, component stock and apheresis-opted-in
	// donors; platelets additionally rank same-ABO and Rh-negative donors first.
	apheresis := isApheresisComponent(component)
	groups := []string{group}
	if apheresis {
		groups = matching.CompatibleGroups(group, component)
	}
	banks, err := s.store.BanksWithStockFor(ctx, groups, component, in.Units)
	if err != nil {
		return RequestResult{}, err
	}
	var donors []store.User
	if apheresis {
		donors, err = s.store.DonorsByGroups(ctx, groups, true)
	} else {
		donors, err = s.store.DonorsByGroup(ctx, group)
	}
	if err != nil {
		return RequestResult{}, err
	}
	if s.HasFeature("reminders") {
		if !apheresis {
			donors, err = s.store.DonorsByGroupAll(ctx, group)
			if err != nil {
				return RequestResult{}, err
			}
		}
		donors = applyReminderFilters(group, lat, lng, donors)
	}
	donors = slices.DeleteFunc(donors, func(donor store.User) bool {
		return matching.DistanceKM(lat, lng, donor.Lat, donor.Lng) > s.matchRadius
	})
	rankByDistance(lat, lng, banks)
	if apheresis {
		sort.SliceStable(donors, func(i, j int) bool {
			ri := matching.DonorRankForComponent(group, donorGroup(donors[i]), component)
			rj := matching.DonorRankForComponent(group, donorGroup(donors[j]), component)
			if ri != rj {
				return ri < rj
			}
			di := matching.DistanceKM(lat, lng, donors[i].Lat, donors[i].Lng)
			dj := matching.DistanceKM(lat, lng, donors[j].Lat, donors[j].Lng)
			return di < dj
		})
	} else {
		rankByDistance(lat, lng, donors)
	}
	banks = limitUsers(banks, 2)
	donors = limitUsers(donors, 10)

	bankIDs := userIDs(banks)
	donorIDs := userIDs(donors)
	roomName := truncate("Blood request "+group+" at "+hospital, 64)
	if err := s.chat.CreateGroupChannel(ctx, channelID, roomName, in.RequesterID, bankIDs); err != nil {
		return RequestResult{}, fmt.Errorf("create room: %w", err)
	}
	if err := s.store.CreateRequest(ctx, request, bankIDs...); err != nil {
		return RequestResult{}, err
	}

	s.Publish(ctx, events.RequestCreated, events.RequestCreatedPayload{
		RequestID:     requestID,
		BloodGroup:    group,
		Hospital:      hospital,
		Units:         in.Units,
		RecipientIDs:  append(bankIDs, donorIDs...),
		RequesterName: in.RequesterName,
	})
	return RequestResult{Request: request, Banks: len(bankIDs), Donors: len(donorIDs)}, nil
}

// Requests returns the role-aware feed. The live path deliberately uses the
// exact blood group rule (D4); the D11 filter pipeline is not wired in yet.
func (s *Service) Requests(ctx context.Context, userID, role, status string) ([]RequestView, error) {
	if status == "" {
		status = "open"
	}
	if status != "open" && status != "fulfilled" && status != "cancelled" && status != "all" {
		return nil, invalid("status must be open, fulfilled, cancelled or all")
	}
	caller, err := s.store.UserByID(ctx, userID)
	if err != nil {
		return nil, err
	}
	all, err := s.store.Requests(ctx, status)
	if err != nil {
		return nil, err
	}

	views := make([]RequestView, 0, len(all))
	for _, request := range all {
		distance := 0.0
		switch role {
		case "requester":
			if request.RequesterID != userID {
				continue
			}
		case "donor":
			if !donorMatchesRequest(caller, request) {
				continue
			}
			distance = matching.DistanceKM(caller.Lat, caller.Lng, request.Lat, request.Lng)
			if distance > s.matchRadius {
				continue
			}
		case "bank":
			distance = matching.DistanceKM(caller.Lat, caller.Lng, request.Lat, request.Lng)
			if distance > s.matchRadius {
				continue
			}
		default:
			return nil, ErrForbidden
		}

		joined, err := s.store.HasRequestMember(ctx, request.ID, userID)
		if err != nil {
			return nil, err
		}
		requesterName := ""
		if requester, err := s.store.UserByID(ctx, request.RequesterID); err == nil {
			requesterName = requester.Name
		} else if !errors.Is(err, store.ErrNotFound) {
			return nil, err
		}
		views = append(views, RequestView{
			Request:       request,
			DistanceKM:    distance,
			RequesterName: requesterName,
			Joined:        joined,
		})
	}
	return views, nil
}

// AcceptRequest joins a donor or bank to the room and records the pledge.
func (s *Service) AcceptRequest(ctx context.Context, requestID, userID string) (string, error) {
	request, err := s.store.RequestByID(ctx, requestID)
	if err != nil {
		return "", err
	}
	if request.Status != "open" {
		return "", ErrNotOpen
	}
	user, err := s.store.UserByID(ctx, userID)
	if err != nil {
		return "", err
	}
	if user.Role != "donor" && user.Role != "bank" {
		return "", ErrForbidden
	}

	joined, err := s.store.HasRequestMember(ctx, requestID, userID)
	if err != nil {
		return "", err
	}
	if !joined {
		if matching.DistanceKM(user.Lat, user.Lng, request.Lat, request.Lng) > s.matchRadius ||
			(user.Role == "donor" && !donorMatchesRequest(user, request)) {
			return "", ErrForbidden
		}
		if err := s.chat.JoinGroupChannel(ctx, request.ChannelID, []string{userID}); err != nil {
			return "", fmt.Errorf("join room: %w", err)
		}
		if err := s.store.AddRequestMember(ctx, requestID, userID, user.Role); err != nil {
			return "", err
		}
		if user.Role == "donor" {
			donationID, err := id.New("d")
			if err != nil {
				return "", err
			}
			if err := s.store.CreateDonation(ctx, store.Donation{
				ID: donationID, RequestID: requestID, DonorID: userID, Units: request.Units,
			}); err != nil {
				return "", err
			}
		}
		s.Publish(ctx, events.RequestAccepted, events.RequestAcceptedPayload{
			RequestID:   requestID,
			UserID:      userID,
			UserName:    user.Name,
			UserRole:    user.Role,
			RequesterID: request.RequesterID,
		})
	}
	return request.ChannelID, nil
}

// DonationView is the client-facing shape of a recorded donation. The
// database column is created_at; the v2 contract calls it donated_at.
type DonationView struct {
	ID        string `json:"id"`
	RequestID string `json:"request_id"`
	DonatedAt string `json:"donated_at"`
}

// DonationResult is returned by POST /requests/{id}/donated.
type DonationResult struct {
	Donation      DonationView `json:"donation"`
	DonationCount int          `json:"donation_count"`
}

// RecordDonation marks a joined donor's pledge as recorded. Accepting a
// request already writes the donation row (A8/A9), so an existing row is
// reused: the operation is idempotent per (donor, request) and never inflates
// donation_count. Only a donor who joined the room may record a donation.
func (s *Service) RecordDonation(ctx context.Context, requestID, donorID string) (DonationResult, error) {
	request, err := s.store.RequestByID(ctx, requestID)
	if err != nil {
		return DonationResult{}, err
	}
	user, err := s.store.UserByID(ctx, donorID)
	if err != nil {
		return DonationResult{}, err
	}
	if user.Role != "donor" {
		return DonationResult{}, ErrForbidden
	}
	joined, err := s.store.HasRequestMember(ctx, requestID, donorID)
	if err != nil {
		return DonationResult{}, err
	}
	if !joined {
		return DonationResult{}, ErrForbidden
	}

	donation, err := s.store.DonationFor(ctx, requestID, donorID)
	if errors.Is(err, store.ErrNotFound) {
		donationID, idErr := id.New("d")
		if idErr != nil {
			return DonationResult{}, idErr
		}
		if err := s.store.CreateDonation(ctx, store.Donation{
			ID: donationID, RequestID: requestID, DonorID: donorID, Units: request.Units,
		}); err != nil {
			return DonationResult{}, err
		}
		// CreateDonation uses INSERT OR IGNORE, so reload to return the row
		// that actually won in the store (including its created_at).
		donation, err = s.store.DonationFor(ctx, requestID, donorID)
		if err != nil {
			return DonationResult{}, err
		}
	} else if err != nil {
		return DonationResult{}, err
	}

	count, err := s.store.DonationCount(ctx, donorID)
	if err != nil {
		return DonationResult{}, err
	}
	s.Publish(ctx, events.DonationRecorded, events.DonationRecordedPayload{
		DonationID:    donation.ID,
		RequestID:     requestID,
		DonorID:       donorID,
		DonationCount: count,
	})
	return DonationResult{
		Donation: DonationView{
			ID:        donation.ID,
			RequestID: donation.RequestID,
			DonatedAt: donation.CreatedAt,
		},
		DonationCount: count,
	}, nil
}

// FulfillRequest posts a system message, freezes the room and marks it fulfilled.
func (s *Service) FulfillRequest(ctx context.Context, requestID, userID string) (store.Request, error) {
	request, err := s.store.RequestByID(ctx, requestID)
	if err != nil {
		return store.Request{}, err
	}
	if request.RequesterID != userID {
		return store.Request{}, ErrForbidden
	}
	if request.Status != "open" {
		return store.Request{}, ErrNotOpen
	}

	content := fmt.Sprintf(`{"content":"This request has been fulfilled. Thank you!"}`)
	if err := s.chat.SendGroupMessage(ctx, request.ChannelID, userID, "RC:TxtMsg", content); err != nil {
		return store.Request{}, fmt.Errorf("post system message: %w", err)
	}
	if err := s.chat.FreezeGroupChannel(ctx, request.ChannelID); err != nil {
		return store.Request{}, fmt.Errorf("freeze room: %w", err)
	}
	if err := s.store.SetRequestStatus(ctx, requestID, "fulfilled"); err != nil {
		return store.Request{}, err
	}
	members, err := s.store.RequestMemberIDs(ctx, requestID)
	if err != nil {
		return store.Request{}, err
	}
	s.Publish(ctx, events.RequestFulfilled, events.RequestFulfilledPayload{
		RequestID:    requestID,
		RecipientIDs: members,
		BloodGroup:   request.BloodGroup,
		Hospital:     request.Hospital,
	})
	return s.store.RequestByID(ctx, requestID)
}

// applyReminderFilters runs the availability and eligibility filters that the
// reminders feature enables. Unknown age/weight get known-eligible defaults so
// the pipeline agrees with the permissive /me contract; an explicit
// available=false or a recent donation still excludes the donor.
func applyReminderFilters(group string, lat, lng float64, donors []store.User) []store.User {
	if len(donors) == 0 {
		return donors
	}
	profiles := make([]matching.Donor, 0, len(donors))
	for _, user := range donors {
		profile := matching.FromUser(user)
		if profile.Age == nil {
			age := 30
			profile.Age = &age
		}
		if profile.WeightKG == nil {
			weight := 60.0
			profile.WeightKG = &weight
		}
		profiles = append(profiles, profile)
	}
	kept := matching.NewPipeline(matching.ByAvailability(), matching.ByEligibility()).Apply(
		matching.Patient{BloodGroup: group, Lat: lat, Lng: lng}, profiles, time.Now())
	keepIDs := make(map[string]bool, len(kept))
	for _, profile := range kept {
		keepIDs[profile.ID] = true
	}
	result := make([]store.User, 0, len(kept))
	for _, user := range donors {
		if keepIDs[user.ID] {
			result = append(result, user)
		}
	}
	return result
}

func rankByDistance(lat, lng float64, users []store.User) {
	sort.SliceStable(users, func(i, j int) bool {
		return matching.DistanceKM(lat, lng, users[i].Lat, users[i].Lng) <
			matching.DistanceKM(lat, lng, users[j].Lat, users[j].Lng)
	})
}

func limitUsers(users []store.User, limit int) []store.User {
	if len(users) > limit {
		return users[:limit]
	}
	return users
}

func userIDs(users []store.User) []string {
	ids := make([]string, 0, len(users))
	for _, user := range users {
		ids = append(ids, user.ID)
	}
	return ids
}

func donorMatchesRequest(donor store.User, request store.Request) bool {
	group := donorGroup(donor)
	if isApheresisComponent(request.Component) {
		return donor.ApheresisOK && matching.CompatibleForComponent(request.BloodGroup, group, request.Component)
	}
	return group == request.BloodGroup
}

func donorGroup(user store.User) string {
	if user.BloodGroup == nil {
		return ""
	}
	return *user.BloodGroup
}

func truncate(value string, max int) string {
	if len(value) <= max {
		return value
	}
	for !utf8.RuneStart(value[max]) {
		max--
	}
	return value[:max]
}
