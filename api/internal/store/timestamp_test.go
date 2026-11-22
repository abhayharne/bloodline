package store

import (
	"regexp"
	"testing"
)

var rfc3339UTC = regexp.MustCompile(`^\d{4}-\d{2}-\d{2}T\d{2}:\d{2}:\d{2}Z$`)

func TestTimestampIsRFC3339UTCZ(t *testing.T) {
	stamp := Timestamp()
	if !rfc3339UTC.MatchString(stamp) {
		t.Fatalf("Timestamp() = %q, want RFC3339 UTC with Z", stamp)
	}
}

func TestNormaliseTimestamp(t *testing.T) {
	tests := []struct {
		name string
		raw  string
		want string
	}{
		{"already canonical", "2026-11-22T10:00:00Z", "2026-11-22T10:00:00Z"},
		{"legacy sqlite", "2026-11-22 10:00:00", "2026-11-22T10:00:00Z"},
		{"offset converts to UTC", "2026-11-22T15:30:00+05:30", "2026-11-22T10:00:00Z"},
		{"date only", "2026-11-22", "2026-11-22T00:00:00Z"},
		{"empty falls back", "", "1970-01-01T00:00:00Z"},
		{"whitespace falls back", "   ", "1970-01-01T00:00:00Z"},
		{"unparseable falls back", "yesterday", "1970-01-01T00:00:00Z"},
	}
	for _, tc := range tests {
		t.Run(tc.name, func(t *testing.T) {
			if got := NormaliseTimestamp(tc.raw); got != tc.want {
				t.Fatalf("NormaliseTimestamp(%q) = %q, want %q", tc.raw, got, tc.want)
			}
		})
	}
}
