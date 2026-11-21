package httpapi

import "net/http"

// devReset reloads the demo seed. It is only registered when DEV=1 and is
// deliberately unauthenticated so the demo can reset before any login.
func (s *Server) devReset(w http.ResponseWriter, r *http.Request) {
	if err := s.svc.Reset(r.Context()); err != nil {
		writeServiceError(w, err)
		return
	}
	writeJSON(w, http.StatusOK, map[string]any{"status": "ok", "seeded": true})
}

// devRunReminders triggers one eligibility scan. It is only registered when
// DEV=1 and, like devReset, is unauthenticated so the demo can call it before
// login. The response reports how many reminders were written (0 on a repeat).
func (s *Server) devRunReminders(w http.ResponseWriter, r *http.Request) {
	if s.reminders == nil {
		writeError(w, http.StatusNotFound, "reminders runner not configured")
		return
	}
	sent, err := s.reminders.RunEligibilityChecks(r.Context())
	if err != nil {
		writeServiceError(w, err)
		return
	}
	writeJSON(w, http.StatusOK, map[string]any{"status": "ok", "sent": sent})
}
