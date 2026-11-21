// Package id generates identifiers that are safe for Nexconn (alphanumeric only).
package id

import (
	"crypto/rand"
	"encoding/hex"
	"fmt"
)

// New returns prefix followed by 16 random hex characters, e.g. "u9f2c...".
// The result contains only A-Z, a-z and 0-9.
func New(prefix string) (string, error) {
	var raw [8]byte
	if _, err := rand.Read(raw[:]); err != nil {
		return "", fmt.Errorf("generate id: %w", err)
	}
	return prefix + hex.EncodeToString(raw[:]), nil
}
