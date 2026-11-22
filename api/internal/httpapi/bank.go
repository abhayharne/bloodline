package httpapi

import (
	"net/http"

	"bloodline/internal/service"
	"bloodline/internal/store"
)

type stockItem struct {
	BloodGroup string `json:"blood_group"`
	Component  string `json:"component"`
	Units      int    `json:"units"`
}

type stockRequest struct {
	Stock []stockItem `json:"stock"`
}

type stockResponse struct {
	Stock []store.Stock `json:"stock"`
}

func (s *Server) getBankStock(w http.ResponseWriter, r *http.Request) {
	claims, ok := claimsFromContext(r.Context())
	if !ok {
		writeError(w, http.StatusUnauthorized, "missing or invalid token")
		return
	}

	stock, err := s.svc.BankStock(r.Context(), claims.Subject)
	if err != nil {
		writeServiceError(w, err)
		return
	}
	writeJSON(w, http.StatusOK, stockResponse{Stock: stock})
}

func (s *Server) putBankStock(w http.ResponseWriter, r *http.Request) {
	claims, ok := claimsFromContext(r.Context())
	if !ok {
		writeError(w, http.StatusUnauthorized, "missing or invalid token")
		return
	}

	var req stockRequest
	if !decodeJSON(w, r, &req) {
		return
	}

	input := make([]service.StockInput, 0, len(req.Stock))
	for _, item := range req.Stock {
		input = append(input, service.StockInput{BloodGroup: item.BloodGroup, Component: item.Component, Units: item.Units})
	}

	stock, err := s.svc.UpdateBankStock(r.Context(), claims.Subject, input)
	if err != nil {
		writeServiceError(w, err)
		return
	}
	writeJSON(w, http.StatusOK, stockResponse{Stock: stock})
}
