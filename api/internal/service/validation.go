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

// Components accepted on requests and bank stock. Whole blood is the default
// so older clients and seeded rows keep their previous behaviour.
const (
	ComponentWholeBlood = "whole_blood"
	ComponentRedCells   = "red_cells"
	ComponentPlatelets  = "platelets"
	ComponentPlasma     = "plasma"
	ComponentCryo       = "cryo"
	ComponentOther      = "other"
)

var validComponents = map[string]bool{
	ComponentWholeBlood: true, ComponentRedCells: true, ComponentPlatelets: true,
	ComponentPlasma: true, ComponentCryo: true, ComponentOther: true,
}

// Apheresis components need a donor who opted in via PUT /me.
func isApheresisComponent(component string) bool {
	switch component {
	case ComponentPlatelets, ComponentPlasma, ComponentCryo:
		return true
	default:
		return false
	}
}

func normaliseComponent(raw string) (string, error) {
	value := strings.ToLower(strings.TrimSpace(raw))
	if value == "" {
		return ComponentWholeBlood, nil
	}
	if !validComponents[value] {
		return "", invalid("component must be one of whole_blood, red_cells, platelets, plasma, cryo, other")
	}
	return value, nil
}

// validateCoordinates checks the geographic range shared by requests and the
// hospital lookup. Presence is checked by the caller (0,0 is a valid point).
func validateCoordinates(lat, lng float64) error {
	if lat < -90 || lat > 90 {
		return invalid("lat must be between -90 and 90")
	}
	if lng < -180 || lng > 180 {
		return invalid("lng must be between -180 and 180")
	}
	return nil
}

// normaliseUrgency maps the legacy wire values onto the canonical set stored in
// the database. Unknown values are rejected before a request reaches the store.
func normaliseUrgency(raw string) (string, error) {
	value := strings.ToLower(strings.TrimSpace(raw))
	switch value {
	case "critical":
		return "critical", nil
	case "high", "urgent":
		return "high", nil
	case "medium", "med":
		return "medium", nil
	case "low", "planned":
		return "low", nil
	default:
		return "", invalid("urgency must be low, medium, high or critical")
	}
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
