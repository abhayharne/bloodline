package httpapi

import (
	"encoding/json"
	"net/http"
	"strings"
	"testing"

	"bloodline/internal/service"
)

const donorSignupBody = `{"phone":"+919876543210","name":"Asha","role":"donor",
	"blood_group":"O+","lat":21.15,"lng":79.09,"sex":"female","age":28,
	"weight_kg":58,"height_cm":163,"donated_before":false,
	"last_donated_at":"2026-01-01","available":true,"consent":true}`

func TestConfigDefaultsToNoFeatures(t *testing.T) {
	api := newTestAPI(t)
	rec := api.do(t, http.MethodGet, "/config", "")
	if rec.Code != http.StatusOK {
		t.Fatalf("status = %d, want 200", rec.Code)
	}
	var body struct {
		Features []string `json:"features"`
		DemoMode bool     `json:"demo_mode"`
	}
	if err := json.Unmarshal(rec.Body.Bytes(), &body); err != nil {
		t.Fatalf("decode: %v", err)
	}
	if len(body.Features) != 0 {
		t.Errorf("features = %v, want empty", body.Features)
	}
	if !body.DemoMode {
		t.Error("demo_mode = false, want true")
	}
}

func TestConfigReturnsConfiguredFeatures(t *testing.T) {
	api := newTestAPI(t, service.WithFeatures([]string{"notifications", "eligibility"}))
	rec := api.do(t, http.MethodGet, "/config", "")
	var body struct {
		Features []string `json:"features"`
	}
	if err := json.Unmarshal(rec.Body.Bytes(), &body); err != nil {
		t.Fatalf("decode: %v", err)
	}
	if len(body.Features) != 2 || body.Features[0] != "notifications" || body.Features[1] != "eligibility" {
		t.Errorf("features = %v", body.Features)
	}
}

func TestOTPSendNeverReturnsCode(t *testing.T) {
	api := newTestAPI(t, service.WithDemoOTP("654321"))
	rec := api.do(t, http.MethodPost, "/auth/otp/send", `{"phone":"+91 98765 43210"}`)
	if rec.Code != http.StatusOK {
		t.Fatalf("status = %d, want 200 (body %s)", rec.Code, rec.Body.String())
	}
	if strings.Contains(rec.Body.String(), "654321") {
		t.Errorf("OTP leaked into response: %s", rec.Body.String())
	}
}

func TestOTPSendRejectsInvalidPhone(t *testing.T) {
	api := newTestAPI(t)
	rec := api.do(t, http.MethodPost, "/auth/otp/send", `{"phone":"not-a-phone"}`)
	if rec.Code != http.StatusBadRequest {
		t.Fatalf("status = %d, want 400 (body %s)", rec.Code, rec.Body.String())
	}
}

func TestPhoneSignupAndVerifyLogin(t *testing.T) {
	api := newTestAPI(t, service.WithDemoOTP("135790"))
	signup := api.do(t, http.MethodPost, "/auth/signup", donorSignupBody)
	if signup.Code != http.StatusCreated {
		t.Fatalf("signup status = %d, want 201 (body %s)", signup.Code, signup.Body.String())
	}
	created := decodeAuthResponse(t, signup)
	if created.User.Phone == nil || *created.User.Phone != "+919876543210" {
		t.Errorf("phone = %v", created.User.Phone)
	}
	if created.User.Sex == nil || *created.User.Sex != "female" {
		t.Errorf("sex = %v", created.User.Sex)
	}
	if created.User.Age == nil || *created.User.Age != 28 {
		t.Errorf("age = %v", created.User.Age)
	}
	if created.User.WeightKG == nil || *created.User.WeightKG != 58 {
		t.Errorf("weight_kg = %v", created.User.WeightKG)
	}
	if created.User.HeightCM == nil || *created.User.HeightCM != 163 {
		t.Errorf("height_cm = %v", created.User.HeightCM)
	}
	if created.User.LastDonatedAt == nil || *created.User.LastDonatedAt != "2026-01-01" {
		t.Errorf("last_donated_at = %v", created.User.LastDonatedAt)
	}
	if !created.User.Available || created.User.DonatedBefore {
		t.Errorf("profile flags = %+v", created.User)
	}
	if created.User.ConsentAt == nil || *created.User.ConsentAt == "" {
		t.Errorf("consent_at = %v", created.User.ConsentAt)
	}

	// Wrong code does not log in.
	bad := api.do(t, http.MethodPost, "/auth/verify",
		`{"phone":"+919876543210","code":"123456"}`)
	if bad.Code != http.StatusUnauthorized {
		t.Fatalf("wrong OTP status = %d, want 401 (body %s)", bad.Code, bad.Body.String())
	}

	good := api.do(t, http.MethodPost, "/auth/verify",
		`{"phone":"+919876543210","code":"135790"}`)
	if good.Code != http.StatusOK {
		t.Fatalf("verify status = %d, want 200 (body %s)", good.Code, good.Body.String())
	}
	verified := decodeAuthResponse(t, good)
	if verified.User.ID != created.User.ID {
		t.Errorf("verify user id = %q, want %q", verified.User.ID, created.User.ID)
	}
	if verified.Token == "" || verified.NexconnToken == "" {
		t.Error("verify returned empty tokens")
	}
}

func TestVerifyUnknownPhone(t *testing.T) {
	api := newTestAPI(t)
	rec := api.do(t, http.MethodPost, "/auth/verify",
		`{"phone":"+919999999999","code":"123456"}`)
	if rec.Code != http.StatusNotFound {
		t.Fatalf("status = %d, want 404 (body %s)", rec.Code, rec.Body.String())
	}
}

func TestPhoneSignupValidation(t *testing.T) {
	tests := []struct {
		name string
		body string
	}{
		{"bad phone", `{"name":"A","role":"donor","blood_group":"O+","phone":"abc"}`},
		{"bad sex", `{"name":"A","role":"donor","blood_group":"O+","phone":"+919876543210","sex":"x"}`},
		{"bad age", `{"name":"A","role":"donor","blood_group":"O+","phone":"+919876543210","age":150}`},
		{"bad weight", `{"name":"A","role":"donor","blood_group":"O+","phone":"+919876543210","weight_kg":-2}`},
		{"bad donation date", `{"name":"A","role":"donor","blood_group":"O+","phone":"+919876543210","last_donated_at":" yesterday"}`},
		{"consent false", `{"name":"A","role":"donor","blood_group":"O+","phone":"+919876543210","consent":false}`},
	}
	for _, tc := range tests {
		t.Run(tc.name, func(t *testing.T) {
			api := newTestAPI(t)
			rec := api.do(t, http.MethodPost, "/auth/signup", tc.body)
			if rec.Code != http.StatusBadRequest {
				t.Fatalf("status = %d, want 400 (body %s)", rec.Code, rec.Body.String())
			}
		})
	}
}

func TestDuplicatePhoneSignup(t *testing.T) {
	api := newTestAPI(t)
	if rec := api.do(t, http.MethodPost, "/auth/signup", donorSignupBody); rec.Code != http.StatusCreated {
		t.Fatalf("first signup status = %d", rec.Code)
	}
	rec := api.do(t, http.MethodPost, "/auth/signup", donorSignupBody)
	if rec.Code != http.StatusConflict {
		t.Fatalf("second signup status = %d, want 409 (body %s)", rec.Code, rec.Body.String())
	}
}
