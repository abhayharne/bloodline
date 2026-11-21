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

// markNotificationRead marks a single notification as read. The row is
// owner-scoped in the store, so a user cannot read or modify another user's
// notifications; success is an empty 204 response.
func (s *Server) markNotificationRead(w http.ResponseWriter, r *http.Request) {
	claims, ok := claimsFromContext(r.Context())
	if !ok {
		writeError(w, http.StatusUnauthorized, "missing or invalid token")
		return
	}
	id := r.PathValue("id")
	if id == "" {
		writeError(w, http.StatusBadRequest, "missing notification id")
		return
	}
	if err := s.svc.MarkNotificationRead(r.Context(), id, claims.Subject); err != nil {
		writeServiceError(w, err)
		return
	}
	w.WriteHeader(http.StatusNoContent)
}
