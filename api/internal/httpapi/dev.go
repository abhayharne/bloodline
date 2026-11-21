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
