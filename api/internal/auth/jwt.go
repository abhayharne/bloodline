// Package auth issues and validates the app JWT (HS256).
package auth

import (
	"crypto/hmac"
	"crypto/sha256"
	"encoding/base64"
	"encoding/json"
	"errors"
	"strings"
	"time"
)

// ErrInvalidToken is returned for malformed, tampered or expired tokens.
var ErrInvalidToken = errors.New("invalid token")

// Claims is the JWT payload. Subject is the BloodLine user id.
type Claims struct {
	Subject   string `json:"sub"`
	Role      string `json:"role"`
	Name      string `json:"name"`
	ExpiresAt int64  `json:"exp"`
}

// Issuer signs and verifies app JWTs.
type Issuer struct {
	secret []byte
	ttl    time.Duration
	now    func() time.Time
}

// NewIssuer returns an Issuer. The secret must not be empty.
func NewIssuer(secret string, ttl time.Duration) (*Issuer, error) {
	if secret == "" {
		return nil, errors.New("jwt secret is empty")
	}
	if ttl <= 0 {
		return nil, errors.New("jwt ttl must be positive")
	}
	return &Issuer{secret: []byte(secret), ttl: ttl, now: time.Now}, nil
}

// Issue creates a signed token for the user.
func (i *Issuer) Issue(userID, role, name string) (string, error) {
	header := base64.RawURLEncoding.EncodeToString([]byte(`{"alg":"HS256","typ":"JWT"}`))
	payload, err := json.Marshal(Claims{
		Subject:   userID,
		Role:      role,
		Name:      name,
		ExpiresAt: i.now().Add(i.ttl).Unix(),
	})
	if err != nil {
		return "", err
	}
	body := header + "." + base64.RawURLEncoding.EncodeToString(payload)
	signature := i.sign(body)
	return body + "." + base64.RawURLEncoding.EncodeToString(signature), nil
}

// Parse verifies the signature and expiry, returning the claims.
func (i *Issuer) Parse(token string) (Claims, error) {
	parts := strings.Split(token, ".")
	if len(parts) != 3 {
		return Claims{}, ErrInvalidToken
	}

	headerRaw, err := base64.RawURLEncoding.DecodeString(parts[0])
	if err != nil {
		return Claims{}, ErrInvalidToken
	}
	var header struct {
		Algorithm string `json:"alg"`
	}
	if err := json.Unmarshal(headerRaw, &header); err != nil || header.Algorithm != "HS256" {
		return Claims{}, ErrInvalidToken
	}

	gotSignature, err := base64.RawURLEncoding.DecodeString(parts[2])
	if err != nil || !hmac.Equal(gotSignature, i.sign(parts[0]+"."+parts[1])) {
		return Claims{}, ErrInvalidToken
	}

	payloadRaw, err := base64.RawURLEncoding.DecodeString(parts[1])
	if err != nil {
		return Claims{}, ErrInvalidToken
	}
	var claims Claims
	if err := json.Unmarshal(payloadRaw, &claims); err != nil {
		return Claims{}, ErrInvalidToken
	}
	if claims.Subject == "" || claims.ExpiresAt <= i.now().Unix() {
		return Claims{}, ErrInvalidToken
	}
	return claims, nil
}

func (i *Issuer) sign(input string) []byte {
	mac := hmac.New(sha256.New, i.secret)
	mac.Write([]byte(input))
	return mac.Sum(nil)
}
