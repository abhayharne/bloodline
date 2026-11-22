package httpapi

import (
	"net/http"

	"bloodline/internal/service"
	"bloodline/internal/store"
)

type createRequestInput struct {
	BloodGroup string   `json:"blood_group"`
	Units      int      `json:"units"`
	Hospital   string   `json:"hospital"`
	HospitalID string   `json:"hospital_id"`
	Urgency    string   `json:"urgency"`
	Lat        *float64 `json:"lat"`
	Lng        *float64 `json:"lng"`
	Component  string   `json:"component"`
	Notes      string   `json:"notes"`
}

type createRequestResponse struct {
	Request store.Request `json:"request"`
	Matches struct {
		Banks  int `json:"banks"`
		Donors int `json:"donors"`
	} `json:"matches"`
}

type requestsResponse struct {
	Requests []service.RequestView `json:"requests"`
}

type acceptResponse struct {
	ChannelID string `json:"channel_id"`
}

type fulfillResponse struct {
	Request store.Request `json:"request"`
}

func (s *Server) createRequest(w http.ResponseWriter, r *http.Request) {
	claims, ok := claimsFromContext(r.Context())
	if !ok {
		writeError(w, http.StatusUnauthorized, "missing or invalid token")
		return
	}
	var req createRequestInput
	if !decodeJSON(w, r, &req) {
		return
	}

	result, err := s.svc.CreateRequest(r.Context(), service.RequestInput{
		RequesterID:   claims.Subject,
		RequesterName: claims.Name,
		BloodGroup:    req.BloodGroup,
		Units:         req.Units,
		Hospital:      req.Hospital,
		HospitalID:    req.HospitalID,
		Urgency:       req.Urgency,
		Lat:           req.Lat,
		Lng:           req.Lng,
		Component:     req.Component,
		Notes:         req.Notes,
	})
	if err != nil {
		writeServiceError(w, err)
		return
	}

	resp := createRequestResponse{Request: result.Request}
	resp.Matches.Banks = result.Banks
	resp.Matches.Donors = result.Donors
	writeJSON(w, http.StatusCreated, resp)
}

func (s *Server) listRequests(w http.ResponseWriter, r *http.Request) {
	claims, ok := claimsFromContext(r.Context())
	if !ok {
		writeError(w, http.StatusUnauthorized, "missing or invalid token")
		return
	}
	status := r.URL.Query().Get("status")
	requests, err := s.svc.Requests(r.Context(), claims.Subject, claims.Role, status)
	if err != nil {
		writeServiceError(w, err)
		return
	}
	writeJSON(w, http.StatusOK, requestsResponse{Requests: requests})
}

func (s *Server) acceptRequest(w http.ResponseWriter, r *http.Request) {
	claims, ok := claimsFromContext(r.Context())
	if !ok {
		writeError(w, http.StatusUnauthorized, "missing or invalid token")
		return
	}
	channelID, err := s.svc.AcceptRequest(r.Context(), r.PathValue("id"), claims.Subject)
	if err != nil {
		writeServiceError(w, err)
		return
	}
	writeJSON(w, http.StatusOK, acceptResponse{ChannelID: channelID})
}

func (s *Server) recordDonation(w http.ResponseWriter, r *http.Request) {
	claims, ok := claimsFromContext(r.Context())
	if !ok {
		writeError(w, http.StatusUnauthorized, "missing or invalid token")
		return
	}
	result, err := s.svc.RecordDonation(r.Context(), r.PathValue("id"), claims.Subject)
	if err != nil {
		writeServiceError(w, err)
		return
	}
	writeJSON(w, http.StatusCreated, result)
}

func (s *Server) fulfillRequest(w http.ResponseWriter, r *http.Request) {
	claims, ok := claimsFromContext(r.Context())
	if !ok {
		writeError(w, http.StatusUnauthorized, "missing or invalid token")
		return
	}
	request, err := s.svc.FulfillRequest(r.Context(), r.PathValue("id"), claims.Subject)
	if err != nil {
		writeServiceError(w, err)
		return
	}
	writeJSON(w, http.StatusOK, fulfillResponse{Request: request})
}
