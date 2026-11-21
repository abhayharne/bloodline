package auth

import (
	"strings"
	"testing"
	"time"
)

func TestIssueAndParse(t *testing.T) {
	issuer, err := NewIssuer("test-secret", time.Hour)
	if err != nil {
		t.Fatalf("NewIssuer: %v", err)
	}

	token, err := issuer.Issue("u123", "donor", "Asha")
	if err != nil {
		t.Fatalf("Issue: %v", err)
	}
	if len(strings.Split(token, ".")) != 3 {
		t.Fatalf("token %q is not a three-part JWT", token)
	}

	claims, err := issuer.Parse(token)
	if err != nil {
		t.Fatalf("Parse: %v", err)
	}
	if claims.Subject != "u123" || claims.Role != "donor" || claims.Name != "Asha" {
		t.Errorf("claims = %+v", claims)
	}
	if claims.ExpiresAt <= time.Now().Unix() {
		t.Errorf("ExpiresAt = %d, want in the future", claims.ExpiresAt)
	}
}

func TestParseRejectsTamperingAndWrongSecret(t *testing.T) {
	issuer, _ := NewIssuer("test-secret", time.Hour)
	token, _ := issuer.Issue("u123", "donor", "Asha")
	parts := strings.Split(token, ".")

	tampered := parts[0] + "." + parts[1] + "." + strings.Repeat("A", len(parts[2]))
	if _, err := issuer.Parse(tampered); err == nil {
		t.Error("Parse accepted a tampered signature")
	}

	other, _ := NewIssuer("other-secret", time.Hour)
	if _, err := other.Parse(token); err == nil {
		t.Error("Parse accepted a token signed with another secret")
	}

	if _, err := issuer.Parse("not-a-jwt"); err == nil {
		t.Error("Parse accepted a malformed token")
	}
}

func TestParseRejectsExpiredToken(t *testing.T) {
	issuer, _ := NewIssuer("test-secret", time.Hour)
	issuedAt := time.Now().Add(-2 * time.Hour)
	issuer.now = func() time.Time { return issuedAt }

	token, err := issuer.Issue("u123", "donor", "Asha")
	if err != nil {
		t.Fatalf("Issue: %v", err)
	}

	issuer.now = time.Now
	if _, err := issuer.Parse(token); err == nil {
		t.Error("Parse accepted an expired token")
	}
}

func TestNewIssuerRejectsEmptySecret(t *testing.T) {
	if _, err := NewIssuer("", time.Hour); err == nil {
		t.Error("NewIssuer accepted an empty secret")
	}
}
