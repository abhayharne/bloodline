#!/usr/bin/env bash
# End-to-end smoke test: starts a throwaway API server on a random free port,
# then walks signup -> bank stock -> request -> feed -> accept -> donated ->
# fulfill and asserts status codes and key response fields.
#
# Called by scripts/gate-api.sh with NEXCONN_FAKE=1 and FEATURES set explicitly.
# Can also be run directly. Never prints tokens or OTPs.
set -euo pipefail

ROOT="$(cd "$(dirname "$0")/.." && pwd)"
WORKDIR="$(mktemp -d)"
SERVER_PID=""
RESPONSE="$WORKDIR/response.json"

cleanup() {
  if [[ -n "$SERVER_PID" ]]; then
    kill "$SERVER_PID" 2>/dev/null || true
    wait "$SERVER_PID" 2>/dev/null || true
  fi
  rm -rf "$WORKDIR"
}
trap cleanup EXIT

command -v curl >/dev/null || { echo "curl is required" >&2; exit 1; }
command -v jq >/dev/null || { echo "jq is required" >&2; exit 1; }
command -v go >/dev/null || { echo "go is required" >&2; exit 1; }

# Redact secrets before printing a response in a failure message.
body_summary() {
  jq -c 'if type == "object" then
           with_entries(if (.key | test("token|otp|phone")) then .value = "<redacted>" else . end)
         else . end' "$RESPONSE" 2>/dev/null || echo '<unparseable>'
}

fail() {
  echo "SMOKE FAIL: $*" >&2
  echo "  response: $(body_summary)" >&2
  if [[ -f "$WORKDIR/server.log" ]]; then
    echo "  server log:" >&2
    sed 's/^/    /' "$WORKDIR/server.log" >&2
  fi
  exit 1
}

step() { printf '%s\n' "$*"; }

expect_code() {
  local got="$1" want="$2" label="$3"
  [[ "$got" == "$want" ]] || fail "$label: expected HTTP $want, got $got"
}

# method path body [bearer token]; writes the body to $RESPONSE, prints status.
req() {
  local method="$1" path="$2" body="$3" token="${4:-}"
  local -a args=(-sS --max-time 10 -o "$RESPONSE" -w '%{http_code}' -X "$method"
                 -H 'Content-Type: application/json')
  if [[ -n "$token" ]]; then
    args+=(-H "Authorization: Bearer ${token}")
  fi
  if [[ -n "$body" ]]; then
    args+=(-d "$body")
  fi
  curl "${args[@]}" "${BASE_URL}${path}" || true
}

# Ask the OS for a free port; fall back to a random high port without python3.
free_port() {
  if command -v python3 >/dev/null 2>&1; then
    python3 -c 'import socket; s=socket.socket(); s.bind(("127.0.0.1", 0)); print(s.getsockname()[1]); s.close()'
  else
    echo $((20000 + RANDOM % 40000))
  fi
}

PORT="$(free_port)"
[[ "$PORT" =~ ^[0-9]+$ ]] || fail "could not choose a free port"
BASE_URL="http://127.0.0.1:${PORT}"

step "building API server"
(cd "$ROOT/api" && go build -o "$WORKDIR/server" ./cmd/server) || fail "go build failed"

step "starting API server on random port ${PORT} with a temp DB"
# Explicit values win over any .env found by config.LoadDotEnv.
PORT="$PORT" \
DB_PATH="$WORKDIR/smoke.db" \
JWT_SECRET="smoke-only-secret-not-a-real-credential" \
NEXCONN_FAKE=1 \
NEXCONN_MOCK= \
FEATURES="${FEATURES:-}" \
DEMO_OTP="${DEMO_OTP:-123456}" \
  "$WORKDIR/server" >"$WORKDIR/server.log" 2>&1 &
SERVER_PID=$!

ready=0
for ((attempt = 0; attempt < 100; attempt++)); do
  if ! kill -0 "$SERVER_PID" 2>/dev/null; then
    fail "server exited during startup"
  fi
  code="$(curl -sS --max-time 2 -o "$RESPONSE" -w '%{http_code}' "${BASE_URL}/health" 2>/dev/null || true)"
  if [[ "$code" == "200" ]]; then
    ready=1
    break
  fi
  sleep 0.1
done
[[ "$ready" == "1" ]] || fail "server did not become healthy in time"

# Unique phones keep the script safe even if a persistent DB is ever used.
SUFFIX="$(date +%s%N | tail -c 9)"
REQUESTER_PHONE="+919${SUFFIX}"
DONOR_PHONE="+917${SUFFIX}"
BANK_PHONE="+918${SUFFIX}"

step "1/9 health and config"
[[ "$(jq -r '.status' "$RESPONSE")" == "ok" ]] || fail "health status is not ok"
code="$(req GET /config '')"
expect_code "$code" 200 "GET /config"
jq -e --arg features "${FEATURES:-}" '
  .demo_mode == true and
  (.features == ($features | split(",") | map(select(. != ""))))
' "$RESPONSE" >/dev/null || fail "GET /config shape (features/demo_mode)"

step "2/9 signup requester, donor and bank"
code="$(req POST /auth/signup "{\"phone\":\"$REQUESTER_PHONE\",\"name\":\"Smoke Requester\",\"role\":\"requester\",\"blood_group\":\"O-\",\"lat\":21.1458,\"lng\":79.0882,\"consent\":true}")"
expect_code "$code" 201 "requester signup"
requester_token="$(jq -r '.token' "$RESPONSE")"
requester_id="$(jq -r '.user.id' "$RESPONSE")"
[[ -n "$requester_token" && "$requester_token" != "null" ]] || fail "requester token missing"
[[ "$requester_id" =~ ^u[A-Za-z0-9]+$ ]] || fail "requester id is not alphanumeric"
jq -e '.user.role == "requester" and (.nexconn_token | length) > 0' "$RESPONSE" >/dev/null ||
  fail "requester signup fields"

code="$(req POST /auth/signup "{\"phone\":\"$DONOR_PHONE\",\"name\":\"Smoke Donor\",\"role\":\"donor\",\"blood_group\":\"O-\",\"sex\":\"male\",\"age\":28,\"weight_kg\":60,\"height_cm\":170,\"lat\":21.15,\"lng\":79.09,\"available\":true,\"consent\":true}")"
expect_code "$code" 201 "donor signup"
donor_token="$(jq -r '.token' "$RESPONSE")"
donor_id="$(jq -r '.user.id' "$RESPONSE")"
[[ -n "$donor_token" && "$donor_token" != "null" ]] || fail "donor token missing"
[[ "$donor_id" =~ ^u[A-Za-z0-9]+$ ]] || fail "donor id is not alphanumeric"
jq -e '.user.role == "donor" and .user.blood_group == "O-" and .user.available == true' "$RESPONSE" >/dev/null ||
  fail "donor signup fields"

code="$(req POST /auth/signup "{\"phone\":\"$BANK_PHONE\",\"name\":\"Smoke Bank\",\"role\":\"bank\",\"lat\":21.14,\"lng\":79.08,\"consent\":true}")"
expect_code "$code" 201 "bank signup"
bank_token="$(jq -r '.token' "$RESPONSE")"
[[ -n "$bank_token" && "$bank_token" != "null" ]] || fail "bank token missing"
jq -e '.user.role == "bank" and .user.blood_group == null' "$RESPONSE" >/dev/null ||
  fail "bank signup fields"

step "3/9 bank declares stock"
code="$(req PUT /banks/me/stock '{"stock":[{"blood_group":"O-","units":5},{"blood_group":"O+","units":2}]}' "$bank_token")"
expect_code "$code" 200 "PUT /banks/me/stock"
jq -e '.stock | any(.blood_group == "O-" and .units == 5)' "$RESPONSE" >/dev/null ||
  fail "bank stock did not persist"

step "4/9 requester creates a request"
code="$(req POST /requests '{"blood_group":"O-","units":2,"hospital":"City Hospital","urgency":"critical","lat":21.1458,"lng":79.0882}' "$requester_token")"
expect_code "$code" 201 "POST /requests"
request_id="$(jq -r '.request.id' "$RESPONSE")"
channel_id="$(jq -r '.request.channel_id' "$RESPONSE")"
[[ "$request_id" =~ ^r[A-Za-z0-9]+$ ]] || fail "request id is not alphanumeric"
[[ "$channel_id" == "req${request_id}" ]] || fail "channel_id is not req+request id"
jq -e --arg uid "$requester_id" '
  .request.status == "open" and .request.units == 2 and
  .request.requester_id == $uid and
  .matches.banks >= 1 and .matches.donors >= 1
' "$RESPONSE" >/dev/null || fail "create request fields / match counts"
step "    request ${request_id} room ${channel_id}"

step "5/9 donor feed sees the open request"
code="$(req GET /requests '' "$donor_token")"
expect_code "$code" 200 "donor GET /requests"
jq -e --arg rid "$request_id" --arg name "Smoke Requester" '
  .requests | any(.id == $rid and .status == "open" and .joined == false and
                  .requester_name == $name and (.distance_km | type) == "number")
' "$RESPONSE" >/dev/null || fail "donor feed missing the open request"

step "6/9 donor accepts the request (idempotently)"
code="$(req POST "/requests/${request_id}/accept" '{}' "$donor_token")"
expect_code "$code" 200 "POST accept"
[[ "$(jq -r '.channel_id' "$RESPONSE")" == "$channel_id" ]] || fail "accept returned wrong channel_id"
code="$(req POST "/requests/${request_id}/accept" '{}' "$donor_token")"
expect_code "$code" 200 "repeat POST accept"
code="$(req GET /requests '' "$donor_token")"
expect_code "$code" 200 "donor GET /requests after accept"
jq -e --arg rid "$request_id" '
  .requests | any(.id == $rid and .joined == true)
' "$RESPONSE" >/dev/null || fail "donor feed did not mark the request joined"

step "7/9 donation record (A11 contract, tolerated until the endpoint lands)"
code="$(req POST "/requests/${request_id}/donated" '{}' "$donor_token")"
case "$code" in
  201)
    jq -e --arg rid "$request_id" '
      .donation.request_id == $rid and (.donation.id | length) > 0 and
      (.donation_count | type) == "number" and .donation_count >= 1
    ' "$RESPONSE" >/dev/null || fail "POST donated fields"
    ;;
  404)
    step "    endpoint not implemented yet (A11); skipping until it lands"
    ;;
  *)
    fail "POST donated: unexpected HTTP $code"
    ;;
esac

step "8/9 notifications feed and mark-read"
code="$(req GET /notifications '' "$requester_token")"
expect_code "$code" 200 "GET /notifications"
jq -e '.notifications | type == "array"' "$RESPONSE" >/dev/null || fail "notifications is not an array"
first_notification="$(jq -r '.notifications[0].id // empty' "$RESPONSE")"
if [[ -n "$first_notification" ]]; then
  code="$(req POST "/notifications/${first_notification}/read" '' "$requester_token")"
  expect_code "$code" 204 "POST notification read"
  code="$(req GET /notifications '' "$requester_token")"
  expect_code "$code" 200 "GET /notifications after read"
  jq -e --arg nid "$first_notification" '
    .notifications | any(.id == $nid and .read == true)
  ' "$RESPONSE" >/dev/null || fail "notification did not become read"
fi

step "9/9 requester fulfills the request"
code="$(req POST "/requests/${request_id}/fulfill" '{}' "$requester_token")"
expect_code "$code" 200 "POST fulfill"
jq -e --arg rid "$request_id" '
  .request.id == $rid and .request.status == "fulfilled"
' "$RESPONSE" >/dev/null || fail "fulfill response status"
code="$(req GET '/requests?status=fulfilled' '' "$requester_token")"
expect_code "$code" 200 "requester GET /requests?status=fulfilled"
jq -e --arg rid "$request_id" '
  .requests | any(.id == $rid and .status == "fulfilled")
' "$RESPONSE" >/dev/null || fail "fulfilled request missing from requester feed"

step "SMOKE OK"
