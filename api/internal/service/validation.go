package service

import (
	"errors"
	"regexp"
	"strings"
	"time"
)

var validRoles = map[string]bool{
	"requester": true,
	"donor":     true,
	"bank":      true,
}

var validBloodGroups = map[string]bool{
	"A+": true, "A-": true,
	"B+": true, "B-": true,
	"AB+": true, "AB-": true,
	"O+": true, "O-": true,
}

var validSexes = map[string]bool{
	"male": true, "female": true, "other": true,
}

var phonePattern = regexp.MustCompile(`^\+?[0-9]{7,15}$`)

// ErrInvalidOTP is mapped to HTTP 401 by the handler.
var ErrInvalidOTP = errors.New("invalid otp")

func normaliseRole(role string) string {
	return strings.ToLower(strings.TrimSpace(role))
}

func normaliseBloodGroup(group string) string {
	return strings.ToUpper(strings.TrimSpace(group))
}

func normaliseSex(sex string) string {
	return strings.ToLower(strings.TrimSpace(sex))
}

// normalisePhone strips display separators and validates the remaining digits.
// An empty input means "no phone" (legacy signup); callers decide whether that
// is allowed.
func normalisePhone(raw string) (string, error) {
	phone := strings.Map(func(r rune) rune {
		switch r {
		case ' ', '-', '(', ')':
			return -1
		}
		return r
	}, strings.TrimSpace(raw))
	if phone == "" {
		return "", nil
	}
	if !phonePattern.MatchString(phone) {
		return "", invalid("phone must be 7-15 digits, optionally prefixed with +")
	}
	return phone, nil
}

// parseDonationDate validates an optional last donation date and returns it
// trimmed. Both RFC3339 timestamps and YYYY-MM-DD dates are accepted.
func parseDonationDate(raw string) (string, error) {
	value := strings.TrimSpace(raw)
	if value == "" {
		return "", nil
	}
	if _, err := time.Parse(time.RFC3339, value); err == nil {
		return value, nil
	}
	if _, err := time.Parse("2006-01-02", value); err == nil {
		return value, nil
	}
	return "", invalid("last_donated_at must be an RFC3339 timestamp or YYYY-MM-DD date")
}
