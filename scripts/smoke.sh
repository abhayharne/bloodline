#!/usr/bin/env bash
# End-to-end happy path: signup -> request -> accept -> fulfill.
# Run the API first:  cd api && go run ./cmd/server
# Usage: BASE_URL=http://localhost:8080 ./scripts/smoke.sh
# Never prints tokens or OTPs.
set -euo pipefail

BASE_URL="${BASE_URL:-http://localhost:8080}"
WORKDIR="$(mktemp -d)"
trap 'rm -rf "$WORKDIR"' EXIT

command -v curl >/dev/null || { echo "curl is required" >&2; exit 1; }
command -v jq >/dev/null || { echo "jq is required" >&2; exit 1; }

# Unique 10-digit phones so repeated runs work against a persistent database.
SUFFIX="$(date +%s%N | tail -c 10)"
REQUESTER_PHONE="+91${SUFFIX}"
DONOR_PHONE="+91$((10#${SUFFIX} + 1))"

post() {
  local path="$1" body="$2" token="${3:-}" out="$WORKDIR/response.json"
  local -a args=(-sS -o "$out" -w '%{http_code}' -H 'Content-Type: application/json')
  if [[ -n "$token" ]]; then
    args+=(-H "Authorization: Bearer ${token}")
  fi
  curl "${args[@]}" -X POST -d "$body" "${BASE_URL}${path}"
}

step() { printf '%s\n' "$*"; }

step "1/5 health"
code="$(curl -sS -o "$WORKDIR/response.json" -w '%{http_code}' "${BASE_URL}/health")"
[[ "$code" == "200" ]] || { echo "health failed: HTTP $code" >&2; exit 1; }

step "2/5 signup requester and donor"
code="$(post /auth/signup "$(printf '{"phone":"%s","name":"Smoke Requester","role":"requester","blood_group":"O-","lat":21.1458,"lng":79.0882,"consent":true}' "$REQUESTER_PHONE")")"
[[ "$code" == "201" ]] || { echo "requester signup failed: HTTP $code" >&2; exit 1; }
requester_token="$(jq -r '.token' "$WORKDIR/response.json")"
requester_id="$(jq -r '.user.id' "$WORKDIR/response.json")"

code="$(post /auth/signup "$(printf '{"phone":"%s","name":"Smoke Donor","role":"donor","blood_group":"O-","lat":21.15,"lng":79.09,"consent":true}' "$DONOR_PHONE")")"
[[ "$code" == "201" ]] || { echo "donor signup failed: HTTP $code" >&2; exit 1; }
donor_token="$(jq -r '.token' "$WORKDIR/response.json")"
donor_id="$(jq -r '.user.id' "$WORKDIR/response.json")"

step "3/5 create request"
code="$(post /requests '{"blood_group":"O-","units":2,"hospital":"City Hospital","urgency":"critical","lat":21.16,"lng":79.10}' "$requester_token")"
[[ "$code" == "201" ]] || { echo "create request failed: HTTP $code ($(jq -c . "$WORKDIR/response.json"))" >&2; exit 1; }
request_id="$(jq -r '.request.id' "$WORKDIR/response.json")"
channel_id="$(jq -r '.request.channel_id' "$WORKDIR/response.json")"
step "    request ${request_id} room ${channel_id}"

step "4/5 donor accepts"
code="$(post "/requests/${request_id}/accept" '{}' "$donor_token")"
[[ "$code" == "200" ]] || { echo "accept failed: HTTP $code ($(jq -c . "$WORKDIR/response.json"))" >&2; exit 1; }
step "    donor ${donor_id} joined"

step "5/5 requester fulfills"
code="$(post "/requests/${request_id}/fulfill" '{}' "$requester_token")"
[[ "$code" == "200" ]] || { echo "fulfill failed: HTTP $code ($(jq -c . "$WORKDIR/response.json"))" >&2; exit 1; }
status="$(jq -r '.request.status' "$WORKDIR/response.json")"
[[ "$status" == "fulfilled" ]] || { echo "status = $status, want fulfilled" >&2; exit 1; }
step "    request ${request_id} is ${status}"
step "SMOKE OK"
