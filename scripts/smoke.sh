#!/usr/bin/env bash
# End-to-end smoke test for the BloodLine API.
#
# Starts a throwaway server on a random free port with NEXCONN_FAKE=1, curls the
# full request lifecycle and asserts status codes and key fields. Everything is
# isolated in a temp dir: a fresh SQLite DB, a local JWT secret and a random
# port. The server is always killed on exit. No real Nexconn credentials, fixed
# ports or phones are used.
#
# Usage:
#   FEATURES= ./scripts/smoke.sh
#   FEATURES=ranks,reminders ./scripts/smoke.sh
# The gate runs both variants. Never prints tokens or OTPs.
set -euo pipefail

root="$(cd "$(dirname "$0")/.." && pwd)"
api_dir="$root/api"
work="$(mktemp -d)"
server_pid=""

cleanup() {
  if [[ -n "$server_pid" ]]; then
    kill "$server_pid" 2>/dev/null || true
    wait "$server_pid" 2>/dev/null || true
  fi
  rm -rf "$work"
}
trap cleanup EXIT

for tool in curl jq python3 go; do
  command -v "$tool" >/dev/null || { echo "$tool is required" >&2; exit 1; }
done

step() { printf '%s\n' "$*"; }

# Never print tokens or phones in a failure message.
redacted_body() {
  jq -c 'if type == "object" then
           with_entries(if (.key | test("token|otp|phone")) then .value = "<redacted>" else . end)
         else . end' "$resp" 2>/dev/null || echo '<unparseable>'
}

fail() {
  echo "SMOKE FAILED: $*" >&2
  echo "  response: $(redacted_body)" >&2
  if [[ -f "$work/server.log" ]]; then
    echo "  server log:" >&2
    tail -20 "$work/server.log" >&2
  fi
  exit 1
}

# A free ephemeral port chosen by the OS, so two concurrent runs never collide.
port="$(python3 -c 'import socket; s=socket.socket(); s.bind(("127.0.0.1",0)); print(s.getsockname()[1]); s.close()')"
base="http://127.0.0.1:${port}"
resp="$work/resp.json"

# Build once into the temp dir; `go run` would leave a child process to clean up.
(cd "$api_dir" && go build -o "$work/server" ./cmd/server) || fail "go build"

# Explicit env values win over any local .env the server loads on boot.
PORT="$port" \
DB_PATH="$work/bloodline.db" \
JWT_SECRET="smoke-only-${port}" \
NEXCONN_FAKE=1 \
DEMO_OTP=123456 \
MATCH_RADIUS_KM=10 \
FEATURES="${FEATURES:-}" \
  "$work/server" >"$work/server.log" 2>&1 &
server_pid=$!

ready=0
for _ in $(seq 1 100); do
  if curl -fsS -o "$resp" "$base/health" 2>/dev/null; then ready=1; break; fi
  kill -0 "$server_pid" 2>/dev/null || fail "server exited during startup"
  sleep 0.1
done
[[ "$ready" == 1 ]] || fail "server did not become healthy"

# req METHOD PATH [BODY] [TOKEN] -> prints the HTTP status, writes the body to $resp.
req() {
  local method="$1" path="$2" body="${3:-}" token="${4:-}"
  local -a args=(-sS -o "$resp" -w '%{http_code}' -X "$method" -H 'Content-Type: application/json')
  [[ -n "$token" ]] && args+=(-H "Authorization: Bearer ${token}")
  [[ -n "$body" ]] && args+=(-d "$body")
  curl "${args[@]}" "$base${path}"
}

expect() {
  local want="$1" got="$2" label="$3"
  [[ "$got" == "$want" ]] || fail "$label: HTTP $got (want $want)"
}

# jq_ok FILTER LABEL   or   jq_ok --arg NAME VALUE FILTER LABEL
# The last argument is the failure label; everything before it goes to jq.
jq_ok() {
  local label="${@: -1}"
  local -a jq_args=("${@:1:$#-1}")
  jq -e "${jq_args[@]}" "$resp" >/dev/null 2>&1 || fail "$label"
}

step "1/10 health + config"
code="$(req GET /health)"
expect 200 "$code" "health"
jq_ok '.status == "ok"' "health body"
code="$(req GET /config)"
expect 200 "$code" "config"
jq_ok '.demo_mode == true and (.features | type == "array")' "config body"

# Signup bodies carry the addendum's `otp` as an ignored extra; this server
# reads `code` for /auth/verify and does not require an OTP for signup.
requester_phone="+919900000001"
donor_phone="+919900000002"
bank_phone="+919900000003"

step "2/10 signup requester, donor and bank"
code="$(req POST /auth/signup "{\"phone\":\"${requester_phone}\",\"otp\":\"123456\",\"name\":\"Smoke Requester\",\"role\":\"requester\",\"blood_group\":\"O-\",\"lat\":21.1458,\"lng\":79.0882,\"consent\":true}")"
expect 201 "$code" "requester signup"
jq_ok '.user.id | test("^u[0-9a-f]+$")' "requester id"
jq_ok '(.token | length) > 0 and (.nexconn_token | length) > 0' "requester tokens"
requester_token="$(jq -r '.token' "$resp")"
requester_id="$(jq -r '.user.id' "$resp")"

code="$(req POST /auth/signup "{\"phone\":\"${donor_phone}\",\"otp\":\"123456\",\"name\":\"Smoke Donor\",\"role\":\"donor\",\"blood_group\":\"O-\",\"lat\":21.15,\"lng\":79.09,\"sex\":\"female\",\"age\":28,\"weight_kg\":58,\"height_cm\":163,\"donated_before\":false,\"available\":true,\"consent\":true}")"
expect 201 "$code" "donor signup"
jq_ok '(.user.id | test("^u[0-9a-f]+$")) and .user.available == true' "donor profile"
donor_token="$(jq -r '.token' "$resp")"
donor_id="$(jq -r '.user.id' "$resp")"

code="$(req POST /auth/signup "{\"phone\":\"${bank_phone}\",\"otp\":\"123456\",\"name\":\"Smoke Bank\",\"role\":\"bank\",\"lat\":21.14,\"lng\":79.08,\"consent\":true}")"
expect 201 "$code" "bank signup"
jq_ok '(.user.id | test("^u[0-9a-f]+$")) and .user.blood_group == null' "bank profile"
bank_token="$(jq -r '.token' "$resp")"

step "3/10 mock OTP send + verify (login path)"
code="$(req POST /auth/otp/send "{\"phone\":\"${donor_phone}\"}" "$donor_token")"
expect 200 "$code" "otp send"
jq_ok '.sent == true' "otp send body"
code="$(req POST /auth/verify "{\"phone\":\"${donor_phone}\",\"otp\":\"123456\",\"code\":\"123456\"}")"
expect 200 "$code" "otp verify"
jq_ok --arg id "$donor_id" '.user.id == $id and (.token | length) > 0' "verify body"
code="$(req POST /auth/verify "{\"phone\":\"${donor_phone}\",\"otp\":\"000000\",\"code\":\"000000\"}")"
expect 401 "$code" "wrong otp rejected"

step "4/10 bank stock PUT + GET"
code="$(req PUT /banks/me/stock '{"stock":[{"blood_group":"O-","units":3},{"blood_group":"O+","units":5}]}' "$bank_token")"
expect 200 "$code" "put bank stock"
jq_ok '(.stock | map(select(.blood_group == "O-" and .units == 3)) | length) == 1' "stock body"
code="$(req GET /banks/me/stock "" "$bank_token")"
expect 200 "$code" "get bank stock"
jq_ok '(.stock | map(select(.blood_group == "O-" and .units == 3)) | length) == 1' "stock round-trip"

step "5/10 create request (matches bank stock + donor)"
code="$(req POST /requests '{"blood_group":"O-","units":2,"hospital":"City Hospital","urgency":"critical","lat":21.1458,"lng":79.0882}' "$requester_token")"
expect 201 "$code" "create request"
jq_ok '.request.id | test("^r[0-9a-f]+$")' "request id"
jq_ok '.request.status == "open"' "request status"
jq_ok '.matches.banks >= 1 and .matches.donors >= 1' "match counts"
request_id="$(jq -r '.request.id' "$resp")"
channel_id="$(jq -r '.request.channel_id' "$resp")"
[[ "$channel_id" == "req${request_id}" ]] || fail "channel_id $channel_id != req${request_id}"

step "6/10 donor feed is role-aware and shows the open request"
code="$(req GET /requests "" "$donor_token")"
expect 200 "$code" "donor feed"
jq_ok --arg id "$request_id" '[.requests[] | select(.id == $id)] | length == 1' "feed contains request"
jq_ok --arg id "$request_id" '.requests[] | select(.id == $id) | .joined == false and .distance_km <= 10 and .requester_name == "Smoke Requester"' "feed fields"

step "7/10 donor accepts (idempotent) and joins the room"
code="$(req POST "/requests/${request_id}/accept" '{}' "$donor_token")"
expect 200 "$code" "donor accept"
jq_ok --arg ch "$channel_id" '.channel_id == $ch' "accept channel"
code="$(req POST "/requests/${request_id}/accept" '{}' "$donor_token")"
expect 200 "$code" "donor accept (repeat)"
code="$(req GET /requests "" "$donor_token")"
expect 200 "$code" "feed after accept"
jq_ok --arg id "$request_id" '.requests[] | select(.id == $id) | .joined == true' "joined flag"

step "8/10 /me + donor pledge + /donated + notification read"
code="$(req GET /me "" "$donor_token")"
expect 200 "$code" "donor /me"
jq_ok --arg id "$donor_id" '
  .user.id == $id and (.derived.eligible | type == "boolean") and
  .derived.donation_count == 1 and .derived.rank == null
' "donor /me derived"

# A recent date keeps the waiting period open whenever the smoke runs.
recent_date="$(python3 -c 'import datetime; print((datetime.date.today() - datetime.timedelta(days=10)).isoformat())')"
code="$(req PUT /me "{\"weight_kg\":59,\"last_donated_at\":\"${recent_date}\"}" "$donor_token")"
expect 200 "$code" "PUT /me"
jq_ok '.user.weight_kg == 59 and (.derived.next_eligible_at | type == "string")' "PUT /me round trip"

# Accept writes one donations row per (donor, request). Keep the A9 direct
# SQLite assertion as a guard on the underlying row, then exercise the HTTP
# path added in A11 (which must reuse that same row, not create a second one).
pledges="$(python3 - "$work/bloodline.db" "$request_id" "$donor_id" <<'PY'
import sqlite3, sys
db, request_id, donor_id = sys.argv[1:4]
con = sqlite3.connect(db)
try:
    print(con.execute(
        "SELECT COUNT(*) FROM donations WHERE request_id=? AND donor_id=?",
        (request_id, donor_id),
    ).fetchone()[0])
finally:
    con.close()
PY
)"
[[ "$pledges" == "1" ]] || fail "expected 1 donation row, got $pledges"
code="$(req POST "/requests/${request_id}/donated" '{}' "$donor_token")"
expect 201 "$code" "donated"
jq_ok --arg rid "$request_id" '
  .donation.request_id == $rid and (.donation.id | length) > 0 and
  (.donation.donated_at | length) > 0 and .donation_count == 1
' "donated body"
donation_id="$(jq -r '.donation.id' "$resp")"
code="$(req POST "/requests/${request_id}/donated" '{}' "$donor_token")"
expect 201 "$code" "donated (repeat)"
jq_ok --arg did "$donation_id" '.donation.id == $did and .donation_count == 1' "donated idempotent"
code="$(req GET /me "" "$donor_token")"
expect 200 "$code" "donor /me after donated"
jq_ok '.derived.donation_count == 1 and .derived.rank == null' "donation_count in /me"

code="$(req GET /notifications "" "$requester_token")"
expect 200 "$code" "requester notifications"
jq_ok '(.notifications | length) > 0 and (all(.notifications[]; .read == false))' "notification shape"
notify_id="$(jq -r '[.notifications[] | select(.type == "request.accepted")][0].id // empty' "$resp")"
[[ -n "$notify_id" ]] || fail "no request.accepted notification for requester"
code="$(req POST "/notifications/${notify_id}/read" '{}' "$requester_token")"
expect 204 "$code" "mark notification read"
code="$(req POST "/notifications/${notify_id}/read" '{}' "$requester_token")"
expect 204 "$code" "mark notification read (idempotent)"
code="$(req GET /notifications "" "$requester_token")"
expect 200 "$code" "notifications after read"
jq_ok --arg id "$notify_id" '.notifications[] | select(.id == $id) | .read == true' "read flag"

step "9/10 requester fulfills"
code="$(req POST "/requests/${request_id}/fulfill" '{}' "$requester_token")"
expect 200 "$code" "fulfill"
jq_ok '.request.status == "fulfilled"' "fulfilled status"
code="$(req GET "/requests?status=fulfilled" "" "$requester_token")"
expect 200 "$code" "fulfilled feed"
jq_ok --arg id "$request_id" '.requests[] | select(.id == $id) | .status == "fulfilled"' "fulfilled row"
code="$(req GET /requests "" "$donor_token")"
expect 200 "$code" "open feed after fulfill"
jq_ok --arg id "$request_id" '([.requests[] | select(.id == $id)] | length) == 0' "request left the open feed"

step "10/10 config still reflects FEATURES after the flow"
code="$(req GET /config)"
expect 200 "$code" "config repeat"
jq_ok --arg features "${FEATURES:-}" '
  ($features | split(",") | map(gsub("^\\s+|\\s+$"; "")) | map(select(length > 0))
    | reduce .[] as $f ([]; if index($f) then . else . + [$f] end)) as $want
  | .features == $want and .demo_mode == true
' "features match FEATURES env"

step "SMOKE OK"
