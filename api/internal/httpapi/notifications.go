package httpapi

import (
	"net/http"

	"bloodline/internal/store"
)

type notificationsResponse struct {
	Notifications []store.Notification `json:"notifications"`
}

func (s *Server) getNotifications(w http.ResponseWriter, r *http.Request) {
	claims, ok := claimsFromContext(r.Context())
	if !ok {
		writeError(w, http.StatusUnauthorized, "missing or invalid token")
		return
	}
	items, err := s.svc.Notifications(r.Context(), claims.Subject)
	if err != nil {
		writeServiceError(w, err)
		return
	}
	writeJSON(w, http.StatusOK, notificationsResponse{Notifications: items})
}
