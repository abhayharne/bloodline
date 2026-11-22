package store

import (
	"strings"
	"time"
)

// legacyTimestampLayout is what SQLite's datetime('now') produced before the
// schema moved to strftime with a trailing Z. It is UTC, but uses a space.
const legacyTimestampLayout = "2006-01-02 15:04:05"

// fallbackTimestamp keeps a missing or unparseable legacy value out of JSON as
// an empty string while remaining a valid RFC3339 UTC instant.
const fallbackTimestamp = "1970-01-01T00:00:00Z"

// Timestamp returns the current UTC time in RFC3339 with a trailing Z.
func Timestamp() string {
	return time.Now().UTC().Format(time.RFC3339)
}

// NormaliseTimestamp converts any stored timestamp to RFC3339 UTC with a Z
// suffix. Fresh rows already use that format; legacy SQLite datetime values
// (and RFC3339 offsets) are converted on read so clients never see either "",
// a space-separated value, or an offset other than Z.
func NormaliseTimestamp(raw string) string {
	value := strings.TrimSpace(raw)
	if value == "" {
		return fallbackTimestamp
	}
	// time.Parse(time.RFC3339, ...) also accepts fractional seconds.
	if parsed, err := time.Parse(time.RFC3339, value); err == nil {
		return parsed.UTC().Format(time.RFC3339)
	}
	for _, layout := range []string{legacyTimestampLayout, "2006-01-02"} {
		if parsed, err := time.Parse(layout, value); err == nil {
			return parsed.UTC().Format(time.RFC3339)
		}
	}
	return fallbackTimestamp
}
