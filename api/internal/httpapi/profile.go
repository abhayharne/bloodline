package httpapi

import (
	"net/http"

	"bloodline/internal/service"
)

// profileInput maps PUT /me. Every field is a pointer so an omitted field can
// never overwrite a stored value with a zero.
type profileInput struct {
	Available     *bool    `json:"available"`
	Lat           *float64 `json:"lat"`
	Lng           *float64 `json:"lng"`
	WeightKG      *float64 `json:"weight_kg"`
	HeightCM      *float64 `json:"height_cm"`
	LastDonatedAt *string  `json:"last_donated_at"`
	ApheresisOK   *bool    `json:"apheresis_ok"`
}

func (s *Server) getMe(w http.ResponseWriter, r *http.Request) {
	claims, ok := claimsFromContext(r.Context())
	if !ok {
		writeError(w, http.StatusUnauthorized, "missing or invalid token")
		return
	}
	view, err := s.svc.Profile(r.Context(), claims.Subject)
	if err != nil {
		writeServiceError(w, err)
		return
	}
	writeJSON(w, http.StatusOK, view)
}

func (s *Server) putMe(w http.ResponseWriter, r *http.Request) {
	claims, ok := claimsFromContext(r.Context())
	if !ok {
		writeError(w, http.StatusUnauthorized, "missing or invalid token")
		return
	}
	var in profileInput
	if !decodeJSON(w, r, &in) {
		return
	}
	view, err := s.svc.UpdateProfile(r.Context(), claims.Subject, service.ProfileInput{
		Available:     in.Available,
		Lat:           in.Lat,
		Lng:           in.Lng,
		WeightKG:      in.WeightKG,
		HeightCM:      in.HeightCM,
		LastDonatedAt: in.LastDonatedAt,
		ApheresisOK:   in.ApheresisOK,
	})
	if err != nil {
		writeServiceError(w, err)
		return
	}
	writeJSON(w, http.StatusOK, view)
}
