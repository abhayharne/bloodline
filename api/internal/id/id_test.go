package id

import (
	"regexp"
	"testing"
)

func TestNewIsAlphanumericAndUnique(t *testing.T) {
	pattern := regexp.MustCompile(`^u[0-9a-f]{16}$`)
	seen := make(map[string]bool)
	for i := 0; i < 100; i++ {
		got, err := New("u")
		if err != nil {
			t.Fatalf("New: %v", err)
		}
		if !pattern.MatchString(got) {
			t.Fatalf("New() = %q, want alphanumeric id with u prefix", got)
		}
		if seen[got] {
			t.Fatalf("New() returned duplicate id %q", got)
		}
		seen[got] = true
	}
}
