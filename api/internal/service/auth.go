package service

import (
	"context"
	"fmt"
	"strings"

	"bloodline/internal/id"
	"bloodline/internal/store"
)

// SignupInput is the validated shape of POST /auth/signup.
type SignupInput struct {
	Name       string
	Role       string
	BloodGroup string
	Lat        float64
	Lng        float64
}

// LoginInput is the shape of POST /auth/login.
type LoginInput struct {
	Name string
	Role string
}

// AuthResult is returned by signup and login.
type AuthResult struct {
	User         store.User
	Token        string
	NexconnToken string
}

// Signup creates the account and returns an app JWT plus a Nexconn chat token.
func (s *Service) Signup(ctx context.Context, in SignupInput) (AuthResult, error) {
	name := strings.TrimSpace(in.Name)
	if name == "" {
		return AuthResult{}, invalid("name is required")
	}

	role := normaliseRole(in.Role)
	if !validRoles[role] {
		return AuthResult{}, invalid("role must be requester, donor or bank")
	}

	bloodGroup, err := validateBloodGroup(role, in.BloodGroup)
	if err != nil {
		return AuthResult{}, err
	}

	userID, err := id.New("u")
	if err != nil {
		return AuthResult{}, err
	}
	user := store.User{
		ID:         userID,
		Name:       name,
		Role:       role,
		BloodGroup: bloodGroup,
		Lat:        in.Lat,
		Lng:        in.Lng,
	}
	if err := s.store.CreateUser(ctx, user); err != nil {
		return AuthResult{}, err
	}

	return s.finishAuth(ctx, user)
}

// Login finds an existing account and returns fresh tokens.
func (s *Service) Login(ctx context.Context, in LoginInput) (AuthResult, error) {
	name := strings.TrimSpace(in.Name)
	if name == "" {
		return AuthResult{}, invalid("name is required")
	}
	role := normaliseRole(in.Role)
	if !validRoles[role] {
		return AuthResult{}, invalid("role must be requester, donor or bank")
	}

	user, err := s.store.UserByNameRole(ctx, name, role)
	if err != nil {
		return AuthResult{}, err
	}
	return s.finishAuth(ctx, user)
}

func (s *Service) finishAuth(ctx context.Context, user store.User) (AuthResult, error) {
	nexconnToken, err := s.chat.IssueToken(ctx, user.ID, user.Name)
	if err != nil {
		return AuthResult{}, fmt.Errorf("issue nexconn token: %w", err)
	}
	token, err := s.jwt.Issue(user.ID, user.Role, user.Name)
	if err != nil {
		return AuthResult{}, fmt.Errorf("issue app token: %w", err)
	}
	return AuthResult{User: user, Token: token, NexconnToken: nexconnToken}, nil
}

func validateBloodGroup(role, raw string) (*string, error) {
	group := normaliseBloodGroup(raw)
	if role == "bank" {
		if group != "" {
			return nil, invalid("blood_group must be omitted for bank")
		}
		return nil, nil
	}
	if group == "" {
		return nil, invalid("blood_group is required for requester and donor")
	}
	if !validBloodGroups[group] {
		return nil, invalid("blood_group must be one of A+, A-, B+, B-, AB+, AB-, O+, O-")
	}
	return &group, nil
}
