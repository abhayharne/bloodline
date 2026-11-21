// Package config loads runtime configuration from the environment.
//
// Secrets (JWT_SECRET, NEXCONN_APP_SECRET) are only read here and are never logged.
package config

import (
	"fmt"
	"os"
	"path/filepath"
	"strconv"
	"strings"
)

// Config is the complete runtime configuration for the API server.
type Config struct {
	Port                 string
	DBPath               string
	JWTSecret            string
	NexconnAppKey        string
	NexconnAppSecret     string
	NexconnAPIBase       string
	NexconnAPIBaseBackup string
	MatchRadiusKM        float64
}

// Load reads configuration from the process environment and validates it.
// It does not read .env; call LoadDotEnv first if a local .env should be used.
func Load() (Config, error) {
	cfg := Config{
		Port:                 getenv("PORT", "8080"),
		DBPath:               getenv("DB_PATH", "./bloodline.db"),
		JWTSecret:            os.Getenv("JWT_SECRET"),
		NexconnAppKey:        os.Getenv("NEXCONN_APP_KEY"),
		NexconnAppSecret:     os.Getenv("NEXCONN_APP_SECRET"),
		NexconnAPIBase:       os.Getenv("NEXCONN_API_BASE"),
		NexconnAPIBaseBackup: os.Getenv("NEXCONN_API_BASE_BACKUP"),
	}

	radiusRaw := getenv("MATCH_RADIUS_KM", "10")
	radius, err := strconv.ParseFloat(radiusRaw, 64)
	if err != nil || radius <= 0 {
		return Config{}, fmt.Errorf("MATCH_RADIUS_KM must be a positive number, got %q", radiusRaw)
	}
	cfg.MatchRadiusKM = radius

	if err := cfg.validate(); err != nil {
		return Config{}, err
	}
	return cfg, nil
}

func (c Config) validate() error {
	var missing []string
	if c.JWTSecret == "" {
		missing = append(missing, "JWT_SECRET")
	}
	if c.NexconnAppKey == "" {
		missing = append(missing, "NEXCONN_APP_KEY")
	}
	if c.NexconnAppSecret == "" {
		missing = append(missing, "NEXCONN_APP_SECRET")
	}
	if c.NexconnAPIBase == "" {
		missing = append(missing, "NEXCONN_API_BASE")
	}
	if c.NexconnAPIBaseBackup == "" {
		missing = append(missing, "NEXCONN_API_BASE_BACKUP")
	}
	if len(missing) > 0 {
		return fmt.Errorf("missing required environment variables: %s", strings.Join(missing, ", "))
	}
	if port, err := strconv.Atoi(c.Port); err != nil || port < 1 || port > 65535 {
		return fmt.Errorf("PORT must be a number between 1 and 65535, got %q", c.Port)
	}
	return nil
}

// LoadDotEnv reads KEY=VALUE lines from the nearest .env walking up from the
// working directory. Real environment variables win, so nothing is overridden.
// A missing .env is not an error.
func LoadDotEnv() error {
	dir, err := os.Getwd()
	if err != nil {
		return err
	}
	for i := 0; i < 6; i++ {
		path := filepath.Join(dir, ".env")
		if _, statErr := os.Stat(path); statErr == nil {
			return loadEnvFile(path)
		}
		parent := filepath.Dir(dir)
		if parent == dir {
			break
		}
		dir = parent
	}
	return nil
}

func loadEnvFile(path string) error {
	raw, err := os.ReadFile(path)
	if err != nil {
		return err
	}
	for _, line := range strings.Split(string(raw), "\n") {
		line = strings.TrimSpace(line)
		if line == "" || strings.HasPrefix(line, "#") {
			continue
		}
		line = strings.TrimPrefix(line, "export ")
		key, value, ok := strings.Cut(line, "=")
		if !ok {
			continue
		}
		key = strings.TrimSpace(key)
		value = strings.Trim(strings.TrimSpace(value), `"'`)
		if key == "" {
			continue
		}
		if _, exists := os.LookupEnv(key); !exists {
			if err := os.Setenv(key, value); err != nil {
				return err
			}
		}
	}
	return nil
}

func getenv(key, fallback string) string {
	if v := os.Getenv(key); v != "" {
		return v
	}
	return fallback
}
