package httpapi

import (
	"encoding/json"
	"net/http"
	"strings"
	"testing"
)

func TestHospitalsEndpoint(t *testing.T) {
	api := newTestAPI(t)

	rec := api.do(t, http.MethodGet, "/hospitals", "")
	if rec.Code != http.StatusOK {
		t.Fatalf("GET /hospitals = %d (body %s)", rec.Code, rec.Body.String())
	}
	var resp struct {
		Hospitals []storeStockHospital `json:"hospitals"`
	}
	if err := json.Unmarshal(rec.Body.Bytes(), &resp); err != nil {
		t.Fatalf("decode: %v (body %s)", err, rec.Body.String())
	}
	if len(resp.Hospitals) != 12 {
		t.Fatalf("hospitals = %d, want 12", len(resp.Hospitals))
	}

	search := api.do(t, http.MethodGet, "/hospitals?q=Mihan&limit=5", "")
	if search.Code != http.StatusOK {
		t.Fatalf("search = %d", search.Code)
	}
	var found struct {
		Hospitals []storeStockHospital `json:"hospitals"`
	}
	if err := json.Unmarshal(search.Body.Bytes(), &found); err != nil {
		t.Fatal(err)
	}
	if len(found.Hospitals) == 0 {
		t.Fatal("area search returned no hospitals")
	}

	unknown := api.do(t, http.MethodGet, "/hospitals?q=does-not-exist", "")
	if unknown.Code != http.StatusOK || !strings.Contains(unknown.Body.String(), `"hospitals":[]`) {
		t.Fatalf("unknown q = %d %s", unknown.Code, unknown.Body.String())
	}

	for _, path := range []string{
		"/hospitals?lat=21",
		"/hospitals?lat=91&lng=0",
		"/hospitals?lat=abc&lng=0",
		"/hospitals?limit=0",
		"/hospitals?limit=51",
		"/hospitals?limit=x",
	} {
		r := api.do(t, http.MethodGet, path, "")
		if r.Code != http.StatusBadRequest {
			t.Fatalf("GET %s = %d, want 400", path, r.Code)
		}
		var body map[string]string
		if err := json.Unmarshal(r.Body.Bytes(), &body); err != nil || body["error"] == "" {
			t.Fatalf("GET %s error body = %s (%v)", path, r.Body.String(), err)
		}
	}
}

// storeStockHospital mirrors the public hospital JSON shape.
type storeStockHospital struct {
	ID   string  `json:"id"`
	Name string  `json:"name"`
	Area string  `json:"area"`
	Lat  float64 `json:"lat"`
	Lng  float64 `json:"lng"`
}

// TestRequesterSeesOwnOpenRequest is the regression for the human's explicit
// requirement: create a request as a requester, then read it back from that
// requester's feed with status open.
func TestRequesterSeesOwnOpenRequest(t *testing.T) {
	api, users := setupRequestAPI(t)
	created := createTestRequest(t, api, users)

	feed := decodeRequests(t, api.doWithToken(t, http.MethodGet, "/requests", "", users.requesterToken))
	if len(feed.Requests) != 1 {
		t.Fatalf("requester feed = %+v", feed.Requests)
	}
	row := feed.Requests[0]
	if row.ID != created.Request.ID || row.RequesterID != users.requesterID ||
		row.Status != "open" {
		t.Fatalf("own request row = %+v", row)
	}
}

func TestRequestHospitalIDComponentAndNotes(t *testing.T) {
	api, users := setupRequestAPI(t)

	body := `{"blood_group":"O-","units":2,"hospital_id":"hcity",` +
		`"component":"platelets","notes":"Ward 4","urgency":"high",` +
		`"hospital":"Ignored","lat":0,"lng":0}`
	rec := api.doWithToken(t, http.MethodPost, "/requests", body, users.requesterToken)
	if rec.Code != http.StatusCreated {
		t.Fatalf("create = %d (body %s)", rec.Code, rec.Body.String())
	}
	var created createRequestResponse
	if err := json.Unmarshal(rec.Body.Bytes(), &created); err != nil {
		t.Fatal(err)
	}
	r := created.Request
	if r.Hospital != "City Hospital" || r.Lat != 21.1458 || r.Lng != 79.0882 {
		t.Fatalf("resolved hospital = %q at (%v,%v)", r.Hospital, r.Lat, r.Lng)
	}
	if r.Component != "platelets" || r.Notes != "Ward 4" {
		t.Fatalf("component/notes = %q/%q", r.Component, r.Notes)
	}

	feed := decodeRequests(t, api.doWithToken(t, http.MethodGet, "/requests", "", users.requesterToken))
	if len(feed.Requests) != 1 || feed.Requests[0].Component != "platelets" ||
		feed.Requests[0].Notes != "Ward 4" {
		t.Fatalf("feed = %+v", feed.Requests)
	}

	for _, tc := range []struct {
		name, body string
	}{
		{"unknown hospital", `{"blood_group":"O-","units":1,"hospital_id":"nope","urgency":"high"}`},
		{"missing coordinates", `{"blood_group":"O-","units":1,"hospital":"City Hospital","urgency":"high"}`},
		{"bad component", `{"blood_group":"O-","units":1,"hospital_id":"hcity","urgency":"high","component":"bones"}`},
	} {
		t.Run(tc.name, func(t *testing.T) {
			r := api.doWithToken(t, http.MethodPost, "/requests", tc.body, users.requesterToken)
			if r.Code != http.StatusBadRequest {
				t.Fatalf("status = %d, want 400 (body %s)", r.Code, r.Body.String())
			}
			var errBody map[string]string
			if err := json.Unmarshal(r.Body.Bytes(), &errBody); err != nil || errBody["error"] == "" {
				t.Fatalf("error body = %s (%v)", r.Body.String(), err)
			}
		})
	}
}

func TestBankStockComponentRoundTrip(t *testing.T) {
	api := newTestAPI(t)
	_, token := signupForTest(t, api, bankSignup)

	body := `{"stock":[` +
		`{"blood_group":"O+","component":"whole_blood","units":5},` +
		`{"blood_group":"O+","component":"plasma","units":3},` +
		`{"blood_group":"O-","units":1}` +
		`]}`
	rec := api.doWithToken(t, http.MethodPut, "/banks/me/stock", body, token)
	if rec.Code != http.StatusOK {
		t.Fatalf("PUT stock = %d (body %s)", rec.Code, rec.Body.String())
	}
	var resp stockResponse
	if err := json.Unmarshal(rec.Body.Bytes(), &resp); err != nil {
		t.Fatal(err)
	}
	if len(resp.Stock) != 3 {
		t.Fatalf("stock = %+v", resp.Stock)
	}
	seen := map[string]int{}
	for _, item := range resp.Stock {
		seen[item.BloodGroup+"/"+item.Component] = item.Units
	}
	if seen["O+/whole_blood"] != 5 || seen["O+/plasma"] != 3 || seen["O-/whole_blood"] != 1 {
		t.Fatalf("stock map = %+v", seen)
	}

	again := api.doWithToken(t, http.MethodGet, "/banks/me/stock", "", token)
	var reread stockResponse
	if err := json.Unmarshal(again.Body.Bytes(), &reread); err != nil || len(reread.Stock) != 3 {
		t.Fatalf("GET stock = %+v (%v)", reread, err)
	}

	bad := api.doWithToken(t, http.MethodPut, "/banks/me/stock",
		`{"stock":[{"blood_group":"O+","component":"bones","units":1}]}`, token)
	if bad.Code != http.StatusBadRequest {
		t.Fatalf("bad component stock = %d, want 400", bad.Code)
	}
	dup := api.doWithToken(t, http.MethodPut, "/banks/me/stock",
		`{"stock":[{"blood_group":"O+","units":1},{"blood_group":"O+","units":2}]}`, token)
	if dup.Code != http.StatusBadRequest {
		t.Fatalf("duplicate stock = %d, want 400", dup.Code)
	}
}
