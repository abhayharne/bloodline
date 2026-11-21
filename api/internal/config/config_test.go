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
