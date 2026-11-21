package service

import (
	"context"
	"errors"
	"fmt"
	"sort"
	"strings"

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
	Urgency       string
	Lat           float64
	Lng           float64
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
	hospital := strings.TrimSpace(in.Hospital)
	if hospital == "" {
		return RequestResult{}, invalid("hospital is required")
	}
	urgency := strings.ToLower(strings.TrimSpace(in.Urgency))
	if urgency != "critical" && urgency != "urgent" && urgency != "planned" {
		return RequestResult{}, invalid("urgency must be critical, urgent or planned")
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
		Lat:         in.Lat,
		Lng:         in.Lng,
		Status:      "open",
		ChannelID:   channelID,
	}
	if err := s.store.CreateRequest(ctx, request); err != nil {
		return RequestResult{}, err
	}

	banks, err := s.store.BanksWithStock(ctx, group, in.Units)
	if err != nil {
		return RequestResult{}, err
	}
	donors, err := s.store.DonorsByGroup(ctx, group)
	if err != nil {
		return RequestResult{}, err
	}
	rankByDistance(in.Lat, in.Lng, banks)
	rankByDistance(in.Lat, in.Lng, donors)
	banks = limitUsers(banks, 2)
	donors = limitUsers(donors, 10)

	bankIDs := userIDs(banks)
	donorIDs := userIDs(donors)
	roomName := truncate("Blood request "+group+" at "+hospital, 64)
	if err := s.chat.CreateGroupChannel(ctx, channelID, roomName, in.RequesterID, bankIDs); err != nil {
		return RequestResult{}, fmt.Errorf("create room: %w", err)
	}
	if err := s.store.AddRequestMember(ctx, requestID, in.RequesterID, "requester"); err != nil {
		return RequestResult{}, err
	}
	for _, bankID := range bankIDs {
		if err := s.store.AddRequestMember(ctx, requestID, bankID, "bank"); err != nil {
			return RequestResult{}, err
		}
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
			if request.BloodGroup == "" || caller.BloodGroup == nil ||
				*caller.BloodGroup != request.BloodGroup {
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
	request.Status = "fulfilled"
	return request, nil
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

func truncate(value string, max int) string {
	if len(value) <= max {
		return value
	}
	return value[:max]
}
