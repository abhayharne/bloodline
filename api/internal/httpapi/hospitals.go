package httpapi

import (
	"net/http"
	"strconv"
	"strings"

	"bloodline/internal/service"
)

type hospitalsResponse struct {
	Hospitals []service.Hospital `json:"hospitals"`
}

// hospitals serves the embedded demo directory. Query parsing failures are
// validation errors (400 with a specific message); semantic validation lives
// in the service so it is shared with request creation.
func (s *Server) hospitals(w http.ResponseWriter, r *http.Request) {
	query := r.URL.Query()
	var lat, lng *float64
	if raw := strings.TrimSpace(query.Get("lat")); raw != "" {
		value, err := strconv.ParseFloat(raw, 64)
		if err != nil {
			writeError(w, http.StatusBadRequest, "lat must be a number")
			return
		}
		lat = &value
	}
	if raw := strings.TrimSpace(query.Get("lng")); raw != "" {
		value, err := strconv.ParseFloat(raw, 64)
		if err != nil {
			writeError(w, http.StatusBadRequest, "lng must be a number")
			return
		}
		lng = &value
	}
	var limit *int
	if raw := strings.TrimSpace(query.Get("limit")); raw != "" {
		value, err := strconv.Atoi(raw)
		if err != nil {
			writeError(w, http.StatusBadRequest, "limit must be an integer")
			return
		}
		limit = &value
	}

	result, err := s.svc.Hospitals(service.HospitalQuery{
		Q: query.Get("q"), Lat: lat, Lng: lng, Limit: limit,
	})
	if err != nil {
		writeServiceError(w, err)
		return
	}
	writeJSON(w, http.StatusOK, hospitalsResponse{Hospitals: result})
}
