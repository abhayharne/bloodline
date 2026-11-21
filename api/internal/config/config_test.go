package config

import (
	"strings"
	"testing"
)

func setRequiredEnv(t *testing.T) {
	t.Helper()
	t.Setenv("JWT_SECRET", "test-secret")
	t.Setenv("NEXCONN_APP_KEY", "test-key")
	t.Setenv("NEXCONN_APP_SECRET", "test-app-secret")
	t.Setenv("NEXCONN_API_BASE", "https://api.example.test")
	t.Setenv("NEXCONN_API_BASE_BACKUP", "https://api-b.example.test")
	t.Setenv("NEXCONN_MOCK", "")
	t.Setenv("NEXCONN_FAKE", "")
}

func TestLoadDefaults(t *testing.T) {
	setRequiredEnv(t)
	t.Setenv("PORT", "")
	t.Setenv("DB_PATH", "")
	t.Setenv("MATCH_RADIUS_KM", "")

	cfg, err := Load()
	if err != nil {
		t.Fatalf("Load: %v", err)
	}
	if cfg.Port != "8080" {
		t.Errorf("Port = %q, want 8080", cfg.Port)
	}
	if cfg.DBPath != "./bloodline.db" {
		t.Errorf("DBPath = %q, want ./bloodline.db", cfg.DBPath)
	}
	if cfg.MatchRadiusKM != 10 {
		t.Errorf("MatchRadiusKM = %v, want 10", cfg.MatchRadiusKM)
	}
	if cfg.JWTSecret != "test-secret" {
		t.Errorf("JWTSecret not loaded")
	}
}

func TestLoadDemoOTPAndFeatures(t *testing.T) {
	setRequiredEnv(t)
	t.Setenv("DEMO_OTP", "")
	t.Setenv("FEATURES", "")

	cfg, err := Load()
	if err != nil {
		t.Fatalf("Load: %v", err)
	}
	if cfg.DemoOTP != "123456" {
		t.Errorf("DemoOTP = %q, want 123456", cfg.DemoOTP)
	}
	if len(cfg.Features) != 0 {
		t.Errorf("Features = %v, want empty", cfg.Features)
	}

	t.Setenv("DEMO_OTP", "998877")
	t.Setenv("FEATURES", " notifications, eligibility,notifications, ")
	cfg, err = Load()
	if err != nil {
		t.Fatalf("Load with env: %v", err)
	}
	if cfg.DemoOTP != "998877" {
		t.Errorf("DemoOTP = %q, want 998877", cfg.DemoOTP)
	}
	if len(cfg.Features) != 2 || cfg.Features[0] != "notifications" || cfg.Features[1] != "eligibility" {
		t.Errorf("Features = %v", cfg.Features)
	}
}

func TestLoadMockModeSkipsNexconnCredentials(t *testing.T) {
	t.Setenv("JWT_SECRET", "test-secret")
	t.Setenv("NEXCONN_APP_KEY", "")
	t.Setenv("NEXCONN_APP_SECRET", "")
	t.Setenv("NEXCONN_API_BASE", "")
	t.Setenv("NEXCONN_API_BASE_BACKUP", "")
	t.Setenv("NEXCONN_MOCK", "1")

	cfg, err := Load()
	if err != nil {
		t.Fatalf("Load: %v", err)
	}
	if !cfg.NexconnMock {
		t.Error("NexconnMock = false, want true")
	}
}

func TestLoadFakeModeSkipsNexconnCredentials(t *testing.T) {
	t.Setenv("JWT_SECRET", "test-secret")
	t.Setenv("NEXCONN_APP_KEY", "")
	t.Setenv("NEXCONN_APP_SECRET", "")
	t.Setenv("NEXCONN_API_BASE", "")
	t.Setenv("NEXCONN_API_BASE_BACKUP", "")
	t.Setenv("NEXCONN_MOCK", "")
	t.Setenv("NEXCONN_FAKE", "1")

	cfg, err := Load()
	if err != nil {
		t.Fatalf("Load: %v", err)
	}
	if !cfg.NexconnFake {
		t.Error("NexconnFake = false, want true")
	}
	if cfg.NexconnMock {
		t.Error("NexconnMock = true, want false")
	}
}

func TestLoadFakeAndMockFlagsAreIndependent(t *testing.T) {
	setRequiredEnv(t)
	t.Setenv("NEXCONN_MOCK", "1")
	t.Setenv("NEXCONN_FAKE", "")
	cfg, err := Load()
	if err != nil || !cfg.NexconnMock || cfg.NexconnFake {
		t.Fatalf("mock-only config = %+v, err = %v", cfg, err)
	}

	t.Setenv("NEXCONN_MOCK", "1")
	t.Setenv("NEXCONN_FAKE", "1")
	cfg, err = Load()
	if err != nil || !cfg.NexconnMock || !cfg.NexconnFake {
		t.Fatalf("both-flags config = %+v, err = %v", cfg, err)
	}
}

func TestLoadDevFlag(t *testing.T) {
	setRequiredEnv(t)
	t.Setenv("DEV", "")

	cfg, err := Load()
	if err != nil {
		t.Fatalf("Load: %v", err)
	}
	if cfg.Dev {
		t.Error("Dev = true, want false by default")
	}

	t.Setenv("DEV", "1")
	cfg, err = Load()
	if err != nil {
		t.Fatalf("Load with DEV=1: %v", err)
	}
	if !cfg.Dev {
		t.Error("Dev = false, want true when DEV=1")
	}
}

func TestLoadMissingRequired(t *testing.T) {
	setRequiredEnv(t)
	t.Setenv("JWT_SECRET", "")
	t.Setenv("NEXCONN_APP_SECRET", "")

	_, err := Load()
	if err == nil {
		t.Fatal("Load succeeded, want missing-env error")
	}
	for _, name := range []string{"JWT_SECRET", "NEXCONN_APP_SECRET"} {
		if !strings.Contains(err.Error(), name) {
			t.Errorf("error %q does not mention %s", err, name)
		}
	}
	if strings.Contains(err.Error(), "test-app-secret") {
		t.Errorf("error leaks a secret value: %q", err)
	}
}

func TestLoadRejectsBadRadius(t *testing.T) {
	setRequiredEnv(t)
	t.Setenv("MATCH_RADIUS_KM", "not-a-number")

	if _, err := Load(); err == nil {
		t.Fatal("Load succeeded, want MATCH_RADIUS_KM error")
	}
}

func TestLoadRejectsBadPort(t *testing.T) {
	setRequiredEnv(t)
	t.Setenv("PORT", "70000")

	if _, err := Load(); err == nil {
		t.Fatal("Load succeeded, want PORT error")
	}
}
