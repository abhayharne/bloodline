package httpapi

import (
	"errors"
	"net/http"

	"bloodline/internal/service"
	"bloodline/internal/store"
)

type signupRequest struct {
	Name       string  `json:"name"`
	Role       string  `json:"role"`
	BloodGroup string  `json:"blood_group"`
	Lat        float64 `json:"lat"`
	Lng        float64 `json:"lng"`
}

type loginRequest struct {
	Name string `json:"name"`
	Role string `json:"role"`
}

type authResponse struct {
	User         store.User `json:"user"`
	Token        string     `json:"token"`
	NexconnToken string     `json:"nexconn_token"`
}

func (s *Server) signup(w http.ResponseWriter, r *http.Request) {
	var req signupRequest
	if !decodeJSON(w, r, &req) {
		return
	}

	result, err := s.svc.Signup(r.Context(), service.SignupInput{
		Name:       req.Name,
		Role:       req.Role,
		BloodGroup: req.BloodGroup,
		Lat:        req.Lat,
		Lng:        req.Lng,
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
