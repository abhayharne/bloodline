package httpapi

import (
	"encoding/json"
	"fmt"
	"net/http"
	"regexp"
	"testing"

	"bloodline/internal/service"
)

var wireTimestamp = regexp.MustCompile(`^\d{4}-\d{2}-\d{2}T\d{2}:\d{2}:\d{2}Z$`)

func assertWireTimestamp(t *testing.T, label, value string) {
	t.Helper()
	if !wireTimestamp.MatchString(value) {
		t.Errorf("%s = %q, want RFC3339 UTC with Z", label, value)
	}
}

func TestAuthAcceptsOTPAndCodeAliases(t *testing.T) {
	api := newTestAPI(t, service.WithDemoOTP("135790"))

	signup := api.do(t, http.MethodPost, "/auth/signup",
		`{"phone":"+919876543210","otp":"135790","name":"Asha","role":"donor","blood_group":"O+","consent":true}`)
	if signup.Code != http.StatusCreated {
		t.Fatalf("signup status = %d (body %s)", signup.Code, signup.Body.String())
	}
	created := decodeAuthResponse(t, signup)
	assertWireTimestamp(t, "signup user.created_at", created.User.CreatedAt)

	// Verify accepts either field; a non-empty code wins when both are present.
	for _, tc := range []struct {
		name string
		body string
		want int
	}{
		{"otp only", `{"phone":"+919876543210","otp":"135790"}`, http.StatusOK},
		{"code only", `{"phone":"+919876543210","code":"135790"}`, http.StatusOK},
		{"both, good code", `{"phone":"+919876543210","code":"135790","otp":"000000"}`, http.StatusOK},
		{"both, bad code wins", `{"phone":"+919876543210","code":"000000","otp":"135790"}`, http.StatusUnauthorized},
		{"bad otp", `{"phone":"+919876543210","otp":"000000"}`, http.StatusUnauthorized},
	} {
		t.Run("verify "+tc.name, func(t *testing.T) {
			rec := api.do(t, http.MethodPost, "/auth/verify", tc.body)
			if rec.Code != tc.want {
				t.Fatalf("status = %d, want %d (body %s)", rec.Code, tc.want, rec.Body.String())
			}
			if tc.want == http.StatusOK {
				assertWireTimestamp(t, "verify user.created_at", decodeAuthResponse(t, rec).User.CreatedAt)
			}
		})
	}

	for _, tc := range []struct {
		name string
		body string
		want int
	}{
		{"bad otp", `{"phone":"+919876543211","otp":"000000","name":"Bad","role":"donor","blood_group":"O+"}`, http.StatusUnauthorized},
		{"bad code", `{"phone":"+919876543211","code":"000000","name":"Bad","role":"donor","blood_group":"O+"}`, http.StatusUnauthorized},
		{"good code wins", `{"phone":"+919876543211","code":"135790","otp":"000000","name":"Imran","role":"donor","blood_group":"O+"}`, http.StatusCreated},
	} {
		t.Run("signup "+tc.name, func(t *testing.T) {
			rec := api.do(t, http.MethodPost, "/auth/signup", tc.body)
			if rec.Code != tc.want {
				t.Fatalf("status = %d, want %d (body %s)", rec.Code, tc.want, rec.Body.String())
			}
			if tc.want == http.StatusCreated {
				assertWireTimestamp(t, "signup user.created_at", decodeAuthResponse(t, rec).User.CreatedAt)
			}
		})
	}
}

func TestUrgencyAliasesNormaliseAndSort(t *testing.T) {
	api, users := setupRequestAPI(t)

	// Insert lowest priority first so the feed order proves sorting by urgency
	// rather than insertion order or recency.
	for _, tc := range []struct{ raw, hospital, want string }{
		{"planned", "Low Ward", "low"},
		{"med", "Medium Ward", "medium"},
		{"urgent", "High Ward", "high"},
	} {
		body := fmt.Sprintf(
			`{"blood_group":"O-","units":1,"hospital":%q,"urgency":%q,"lat":21.15,"lng":79.09}`,
			tc.hospital, tc.raw)
		rec := api.doWithToken(t, http.MethodPost, "/requests", body, users.requesterToken)
		if rec.Code != http.StatusCreated {
			t.Fatalf("urgency %q status = %d (body %s)", tc.raw, rec.Code, rec.Body.String())
		}
		var created createRequestResponse
		if err := json.Unmarshal(rec.Body.Bytes(), &created); err != nil {
			t.Fatalf("decode: %v", err)
		}
		if created.Request.Urgency != tc.want {
			t.Errorf("urgency %q stored as %q, want %q", tc.raw, created.Request.Urgency, tc.want)
		}
		assertWireTimestamp(t, "request.created_at", created.Request.CreatedAt)
	}

	critical := api.doWithToken(t, http.MethodPost, "/requests",
		`{"blood_group":"O-","units":1,"hospital":"Critical Ward","urgency":" CRITICAL ","lat":21.15,"lng":79.09}`,
		users.requesterToken)
	if critical.Code != http.StatusCreated {
		t.Fatalf("canonical urgency status = %d (body %s)", critical.Code, critical.Body.String())
	}

	feed := decodeRequests(t, api.doWithToken(t, http.MethodGet, "/requests?status=all", "", users.requesterToken))
	want := []string{"critical", "high", "medium", "low"}
	if len(feed.Requests) != len(want) {
		t.Fatalf("feed count = %d, want %d", len(feed.Requests), len(want))
	}
	for i, urgency := range want {
		if feed.Requests[i].Urgency != urgency {
			t.Errorf("feed[%d].urgency = %q, want %q", i, feed.Requests[i].Urgency, urgency)
		}
		assertWireTimestamp(t, fmt.Sprintf("feed[%d].created_at", i), feed.Requests[i].CreatedAt)
	}
}

func TestTimestampsOnMeNotificationsAndDonations(t *testing.T) {
	api, users := setupRequestAPI(t)
	created := createTestRequest(t, api, users)
	assertWireTimestamp(t, "created request.created_at", created.Request.CreatedAt)

	feed := decodeRequests(t, api.doWithToken(t, http.MethodGet, "/requests", "", users.donorToken))
	if len(feed.Requests) != 1 {
		t.Fatalf("donor feed count = %d, want 1", len(feed.Requests))
	}
	assertWireTimestamp(t, "feed request.created_at", feed.Requests[0].CreatedAt)

	path := "/requests/" + created.Request.ID
	if rec := api.doWithToken(t, http.MethodPost, path+"/accept", "", users.donorToken); rec.Code != http.StatusOK {
		t.Fatalf("accept status = %d (body %s)", rec.Code, rec.Body.String())
	}
	donated := api.doWithToken(t, http.MethodPost, path+"/donated", "", users.donorToken)
	if donated.Code != http.StatusCreated {
		t.Fatalf("donated status = %d (body %s)", donated.Code, donated.Body.String())
	}
	var donation service.DonationResult
	if err := json.Unmarshal(donated.Body.Bytes(), &donation); err != nil {
		t.Fatalf("decode donation: %v", err)
	}
	assertWireTimestamp(t, "donation.donated_at", donation.Donation.DonatedAt)

	me := api.doWithToken(t, http.MethodGet, "/me", "", users.donorToken)
	if me.Code != http.StatusOK {
		t.Fatalf("me status = %d", me.Code)
	}
	var view service.ProfileView
	if err := json.Unmarshal(me.Body.Bytes(), &view); err != nil {
		t.Fatalf("decode me: %v", err)
	}
	assertWireTimestamp(t, "/me user.created_at", view.User.CreatedAt)

	items := api.doWithToken(t, http.MethodGet, "/notifications", "", users.donorToken)
	var notifications notificationsResponse
	if err := json.Unmarshal(items.Body.Bytes(), &notifications); err != nil {
		t.Fatalf("decode notifications: %v", err)
	}
	if len(notifications.Notifications) == 0 {
		t.Fatal("donor has no notifications")
	}
	for i, item := range notifications.Notifications {
		assertWireTimestamp(t, fmt.Sprintf("notification[%d].created_at", i), item.CreatedAt)
	}
}
