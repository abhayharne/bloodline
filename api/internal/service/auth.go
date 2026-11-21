package service

import (
	"context"
	"errors"
	"fmt"
	"strings"
	"time"

	"bloodline/internal/id"
	"bloodline/internal/store"
)

// SignupInput is the validated shape of POST /auth/signup. Phone and the donor
// profile fields are optional so legacy name+role signups keep working.
type SignupInput struct {
	Phone         string
	Name          string
	Role          string
	BloodGroup    string
	Lat           float64
	Lng           float64
	Sex           string
	Age           int
	WeightKG      float64
	HeightCM      float64
	DonatedBefore bool
	LastDonatedAt string
	Available     *bool
	Consent       *bool
}

// LoginInput is the shape of the legacy POST /auth/login.
type LoginInput struct {
	Name string
	Role string
}

// OTPInput is the shape of POST /auth/verify.
type OTPInput struct {
	Phone string
	Code  string
}

// AuthResult is returned by signup, legacy login and OTP verify.
type AuthResult struct {
	User         store.User
	Token        string
	NexconnToken string
}

// SendOTP implements the demo OTP stub. No message is sent and no code is
// logged; the fixed code lives only in config.
func (s *Service) SendOTP(_ context.Context, phone string) error {
	_, err := normalisePhone(phone)
	return err
}

// Verify checks the mock OTP and logs in an existing phone owner.
func (s *Service) Verify(ctx context.Context, in OTPInput) (AuthResult, error) {
	phone, err := normalisePhone(in.Phone)
	if err != nil {
		return AuthResult{}, err
	}
	if phone == "" || strings.TrimSpace(in.Code) == "" {
		return AuthResult{}, invalid("phone and code are required")
	}
	if strings.TrimSpace(in.Code) != s.demoOTP {
		return AuthResult{}, ErrInvalidOTP
	}

	user, err := s.store.UserByPhone(ctx, phone)
	if err != nil {
		return AuthResult{}, err
	}
	return s.finishAuth(ctx, user)
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

	phone, err := normalisePhone(in.Phone)
	if err != nil {
		return AuthResult{}, err
	}
	if phone != "" {
		if _, err := s.store.UserByPhone(ctx, phone); err == nil {
			return AuthResult{}, store.ErrConflict
		} else if !errors.Is(err, store.ErrNotFound) {
			return AuthResult{}, err
		}
	}

	sex, err := validateSex(in.Sex)
	if err != nil {
		return AuthResult{}, err
	}
	age, err := optionalAge(in.Age)
	if err != nil {
		return AuthResult{}, err
	}
	weightKG, err := optionalMeasurement("weight_kg", in.WeightKG)
	if err != nil {
		return AuthResult{}, err
	}
	heightCM, err := optionalMeasurement("height_cm", in.HeightCM)
	if err != nil {
		return AuthResult{}, err
	}
	lastDonatedAt, err := parseDonationDate(in.LastDonatedAt)
	if err != nil {
		return AuthResult{}, err
	}
	if in.Consent != nil && !*in.Consent {
		return AuthResult{}, invalid("consent is required")
	}

	userID, err := id.New("u")
	if err != nil {
		return AuthResult{}, err
	}
	var phonePtr, consentAt *string
	if phone != "" {
		phonePtr = &phone
	}
	if in.Consent != nil && *in.Consent {
		stamp := time.Now().UTC().Format("2006-01-02 15:04:05")
		consentAt = &stamp
	}
	available := true
	if in.Available != nil {
		available = *in.Available
	}

	user := store.User{
		ID:            userID,
		Phone:         phonePtr,
		Name:          name,
		Role:          role,
		BloodGroup:    bloodGroup,
		Lat:           in.Lat,
		Lng:           in.Lng,
		Sex:           sex,
		Age:           age,
		WeightKG:      weightKG,
		HeightCM:      heightCM,
		DonatedBefore: in.DonatedBefore,
		LastDonatedAt: &lastDonatedAt,
		Available:     available,
		ConsentAt:     consentAt,
	}
	if lastDonatedAt == "" {
		user.LastDonatedAt = nil
	}
	if err := s.store.CreateUser(ctx, user); err != nil {
		return AuthResult{}, err
	}

	return s.finishAuth(ctx, user)
}

// Login finds an existing account for the legacy passwordless flow.
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

func validateSex(raw string) (*string, error) {
	value := normaliseSex(raw)
	if value == "" {
		return nil, nil
	}
	if !validSexes[value] {
		return nil, invalid("sex must be male, female or other")
	}
	return &value, nil
}

func optionalAge(value int) (*int, error) {
	if value == 0 {
		return nil, nil
	}
	if value < 0 || value > 120 {
		return nil, invalid("age must be between 0 and 120")
	}
	return &value, nil
}

func optionalMeasurement(name string, value float64) (*float64, error) {
	if value == 0 {
		return nil, nil
	}
	if value < 0 {
		return nil, invalid(name + " must not be negative")
	}
	return &value, nil
}
