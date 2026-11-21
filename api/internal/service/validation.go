package service

import "strings"

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

func normaliseRole(role string) string {
	return strings.ToLower(strings.TrimSpace(role))
}

func normaliseBloodGroup(group string) string {
	return strings.ToUpper(strings.TrimSpace(group))
}
