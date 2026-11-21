package httpapi

import (
	"errors"
	"net/http"

	"bloodline/internal/service"
	"bloodline/internal/store"
)

type signupRequest struct {
	Phone         string  `json:"phone"`
	Name          string  `json:"name"`
	Role          string  `json:"role"`
	BloodGroup    string  `json:"blood_group"`
	Lat           float64 `json:"lat"`
	Lng           float64 `json:"lng"`
	Sex           string  `json:"sex"`
	Age           int     `json:"age"`
	WeightKG      float64 `json:"weight_kg"`
	HeightCM      float64 `json:"height_cm"`
	DonatedBefore bool    `json:"donated_before"`
	LastDonatedAt string  `json:"last_donated_at"`
	Available     *bool   `json:"available"`
	Consent       *bool   `json:"consent"`
}

type loginRequest struct {
	Name string `json:"name"`
	Role string `json:"role"`
}

type otpRequest struct {
	Phone string `json:"phone"`
	Code  string `json:"code"`
}

type authResponse struct {
	User         store.User `json:"user"`
	Token        string     `json:"token"`
	NexconnToken string     `json:"nexconn_token"`
}

type configResponse struct {
	Features []string `json:"features"`
	DemoMode bool     `json:"demo_mode"`
}

// config exposes client-safe flags only. demo_mode is a fixed marker for the
// demo build (mock OTP, no real SMS/chat credentials in offline modes); no
// secrets or tokens are ever returned here.
func (s *Server) config(w http.ResponseWriter, _ *http.Request) {
	writeJSON(w, http.StatusOK, configResponse{Features: s.svc.Features(), DemoMode: true})
}

func (s *Server) otpSend(w http.ResponseWriter, r *http.Request) {
	var req otpRequest
	if !decodeJSON(w, r, &req) {
		return
	}
	if err := s.svc.SendOTP(r.Context(), req.Phone); err != nil {
		writeServiceError(w, err)
		return
	}
	// The mock code is deliberately absent from the response and from logs.
	writeJSON(w, http.StatusOK, map[string]bool{"sent": true})
}

func (s *Server) verifyOTP(w http.ResponseWriter, r *http.Request) {
	var req otpRequest
	if !decodeJSON(w, r, &req) {
		return
	}

	result, err := s.svc.Verify(r.Context(), service.OTPInput{Phone: req.Phone, Code: req.Code})
	switch {
	case errors.Is(err, service.ErrInvalidOTP):
		writeError(w, http.StatusUnauthorized, "invalid otp")
		return
	case errors.Is(err, store.ErrNotFound):
		writeError(w, http.StatusNotFound, "user not found")
		return
	case errors.Is(err, store.ErrConflict):
		writeError(w, http.StatusConflict, "user already exists")
		return
	case err != nil:
		writeServiceError(w, err)
		return
	}

	writeJSON(w, http.StatusOK, authResponse{
		User:         result.User,
		Token:        result.Token,
		NexconnToken: result.NexconnToken,
	})
}

func (s *Server) signup(w http.ResponseWriter, r *http.Request) {
	var req signupRequest
	if !decodeJSON(w, r, &req) {
		return
	}

	result, err := s.svc.Signup(r.Context(), service.SignupInput{
		Phone:         req.Phone,
		Name:          req.Name,
		Role:          req.Role,
		BloodGroup:    req.BloodGroup,
		Lat:           req.Lat,
		Lng:           req.Lng,
		Sex:           req.Sex,
		Age:           req.Age,
		WeightKG:      req.WeightKG,
		HeightCM:      req.HeightCM,
		DonatedBefore: req.DonatedBefore,
		LastDonatedAt: req.LastDonatedAt,
		Available:     req.Available,
		Consent:       req.Consent,
	})
	if errors.Is(err, store.ErrConflict) {
		writeError(w, http.StatusConflict, "user already exists")
		return
	}
	if err != nil {
		writeServiceError(w, err)
		return
	}

	writeJSON(w, http.StatusCreated, authResponse{
		User:         result.User,
		Token:        result.Token,
		NexconnToken: result.NexconnToken,
	})
}

func (s *Server) login(w http.ResponseWriter, r *http.Request) {
	var req loginRequest
	if !decodeJSON(w, r, &req) {
		return
	}

	result, err := s.svc.Login(r.Context(), service.LoginInput{Name: req.Name, Role: req.Role})
	if errors.Is(err, store.ErrNotFound) {
		writeError(w, http.StatusNotFound, "user not found")
		return
	}
	if err != nil {
		writeServiceError(w, err)
		return
	}

	writeJSON(w, http.StatusOK, authResponse{
		User:         result.User,
		Token:        result.Token,
		NexconnToken: result.NexconnToken,
	})
}
