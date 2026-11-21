package httpapi

import (
	"encoding/json"
	"net/http"
	"net/http/httptest"
	"testing"
)

func signupBank(t *testing.T, api *testAPI) (id, token string) {
	t.Helper()
	rec := api.do(t, http.MethodPost, "/auth/signup",
		`{"name":"City Blood Bank","role":"bank","lat":21.148,"lng":79.085}`)
	if rec.Code != http.StatusCreated {
		t.Fatalf("bank signup status = %d, want 201 (body %s)", rec.Code, rec.Body.String())
	}
	resp := decodeAuthResponse(t, rec)
	return resp.User.ID, resp.Token
}

func signupDonor(t *testing.T, api *testAPI) (id, token string) {
	t.Helper()
	rec := api.do(t, http.MethodPost, "/auth/signup",
		`{"name":"Asha","role":"donor","blood_group":"O+","lat":21.15,"lng":79.09}`)
	if rec.Code != http.StatusCreated {
		t.Fatalf("donor signup status = %d, want 201 (body %s)", rec.Code, rec.Body.String())
	}
	resp := decodeAuthResponse(t, rec)
	return resp.User.ID, resp.Token
}

func decodeStock(t *testing.T, rec *httptest.ResponseRecorder) stockResponse {
	t.Helper()
	var resp stockResponse
	if err := json.Unmarshal(rec.Body.Bytes(), &resp); err != nil {
		t.Fatalf("decode stock response: %v (body %s)", err, rec.Body.String())
	}
	return resp
}

func TestBankStockRequiresBankToken(t *testing.T) {
	api := newTestAPI(t)
	_, donorToken := signupDonor(t, api)

	if rec := api.do(t, http.MethodGet, "/banks/me/stock", ""); rec.Code != http.StatusUnauthorized {
		t.Errorf("no token: status = %d, want 401", rec.Code)
	}
	if rec := api.doWithToken(t, http.MethodGet, "/banks/me/stock", "", donorToken); rec.Code != http.StatusForbidden {
		t.Errorf("donor token: status = %d, want 403", rec.Code)
	}
	if rec := api.doWithToken(t, http.MethodGet, "/banks/me/stock", "", donorToken+"tampered"); rec.Code != http.StatusUnauthorized {
		t.Errorf("tampered token: status = %d, want 401", rec.Code)
	}
}

func TestBankStockStartsEmpty(t *testing.T) {
	api := newTestAPI(t)
	_, token := signupBank(t, api)

	rec := api.doWithToken(t, http.MethodGet, "/banks/me/stock", "", token)
	if rec.Code != http.StatusOK {
		t.Fatalf("status = %d, want 200 (body %s)", rec.Code, rec.Body.String())
	}
	resp := decodeStock(t, rec)
	if len(resp.Stock) != 0 {
		t.Errorf("stock = %+v, want empty", resp.Stock)
	}
}

func TestPutBankStockThenGet(t *testing.T) {
	api := newTestAPI(t)
	_, token := signupBank(t, api)

	put := api.doWithToken(t, http.MethodPut, "/banks/me/stock",
		`{"stock":[{"blood_group":"O+","units":5},{"blood_group":"O-","units":0}]}`, token)
	if put.Code != http.StatusOK {
		t.Fatalf("PUT status = %d, want 200 (body %s)", put.Code, put.Body.String())
	}
	putResp := decodeStock(t, put)
	if len(putResp.Stock) != 2 {
		t.Fatalf("PUT stock = %+v, want 2 rows", putResp.Stock)
	}
	if putResp.Stock[0].BloodGroup != "O+" || putResp.Stock[0].Units != 5 {
		t.Errorf("first row = %+v", putResp.Stock[0])
	}
	if putResp.Stock[0].UpdatedAt == "" {
		t.Error("updated_at is empty")
	}

	get := api.doWithToken(t, http.MethodGet, "/banks/me/stock", "", token)
	if get.Code != http.StatusOK {
		t.Fatalf("GET status = %d, want 200", get.Code)
	}
	getResp := decodeStock(t, get)
	if len(getResp.Stock) != 2 {
		t.Fatalf("GET stock = %+v, want 2 rows", getResp.Stock)
	}
	if getResp.Stock[1].BloodGroup != "O-" || getResp.Stock[1].Units != 0 {
		t.Errorf("second row = %+v", getResp.Stock[1])
	}
}

func TestPutBankStockUpdatesExistingGroup(t *testing.T) {
	api := newTestAPI(t)
	_, token := signupBank(t, api)

	if rec := api.doWithToken(t, http.MethodPut, "/banks/me/stock",
		`{"stock":[{"blood_group":"A+","units":2}]}`, token); rec.Code != http.StatusOK {
		t.Fatalf("first PUT status = %d", rec.Code)
	}
	rec := api.doWithToken(t, http.MethodPut, "/banks/me/stock",
		`{"stock":[{"blood_group":"a+","units":7}]}`, token)
	if rec.Code != http.StatusOK {
		t.Fatalf("second PUT status = %d (body %s)", rec.Code, rec.Body.String())
	}

	resp := decodeStock(t, rec)
	if len(resp.Stock) != 1 || resp.Stock[0].BloodGroup != "A+" || resp.Stock[0].Units != 7 {
		t.Errorf("stock = %+v, want one A+ row with 7 units", resp.Stock)
	}
}

func TestPutBankStockValidation(t *testing.T) {
	tests := []struct {
		name string
		body string
	}{
		{name: "empty stock", body: `{"stock":[]}`},
		{name: "invalid group", body: `{"stock":[{"blood_group":"Z+","units":1}]}`},
		{name: "negative units", body: `{"stock":[{"blood_group":"O+","units":-1}]}`},
		{name: "duplicate group", body: `{"stock":[{"blood_group":"O+","units":1},{"blood_group":"o+","units":2}]}`},
		{name: "invalid json", body: `{`},
	}

	for _, tc := range tests {
		t.Run(tc.name, func(t *testing.T) {
			api := newTestAPI(t)
			_, token := signupBank(t, api)
			rec := api.doWithToken(t, http.MethodPut, "/banks/me/stock", tc.body, token)
			if rec.Code != http.StatusBadRequest {
				t.Fatalf("status = %d, want 400 (body %s)", rec.Code, rec.Body.String())
			}
		})
	}
}

func TestPutBankStockForbiddenForDonor(t *testing.T) {
	api := newTestAPI(t)
	_, token := signupDonor(t, api)

	rec := api.doWithToken(t, http.MethodPut, "/banks/me/stock",
		`{"stock":[{"blood_group":"O+","units":1}]}`, token)
	if rec.Code != http.StatusForbidden {
		t.Fatalf("status = %d, want 403 (body %s)", rec.Code, rec.Body.String())
	}
}
