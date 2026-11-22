# API-agent decisions (append only; newest at bottom)

This file is the overnight-loop decision log for the `api` agent. Earlier
decisions D1-D12 live in `docs/DECISIONS.md` (append-only, shared).

## D11 (backfill) — Extension architecture
Events bus (`internal/events`, panic-safe synchronous subscribers), `DonorFilter`
pipeline with pure `Compatible`/`Eligible`, `notify.Notifier` writing to
`notifications`, and `FEATURES` flags from env. Full text in `docs/DECISIONS.md`.

## D12 (backfill) — NEXCONN_MOCK=1
Dev-only no-op chat client for offline smoke runs; never a `GET /config` flag.
Full text in `docs/DECISIONS.md`. Kept working for older scripts.

## D13 — NEXCONN_FAKE=1 in-memory Nexconn client (task A2)
Real SDK mode remains the default. `NEXCONN_FAKE=1` selects a stateful in-memory
`nexconn.FakeClient`; the legacy `NEXCONN_MOCK=1` no-op stays for older scripts.
If both flags are set, fake wins. Both offline flags skip Nexconn credential
validation, but still require `JWT_SECRET`.

The fake implements the whole `nexconn.Client` interface: deterministic token
`fake-chat-token-<userID>`, room create (owner + initial members), join,
message send and freeze. It tracks users, room members, message contents and
frozen state; join/freeze are idempotent, unknown channels, duplicate creates,
empty ids, >100-member joins and messages to frozen rooms are rejected, and a
cancelled context is honoured. `Channel(id)` exposes a copy for tests.

Rationale: the offline loop can exercise request lifecycle and room behaviour
without network or credentials, and A9's smoke script can assert real fake
state later. State is per-process and lost on restart; no credentials or tokens
are stored or logged. This is a dev env switch, never a `GET /config` flag and
never enabled in production.

## D14 — A3 notification read state and config shape (task A3)
`POST /notifications/{id}/read` (auth required, 204) marks one notification read
via `Store.MarkNotificationRead`. It is owner-scoped and idempotent: re-marking
an already-read row keeps the original `read_at` and still returns 204. A missing
row or a row owned by someone else both map to 404 (`ErrNotFound`), deliberately
not 403, so the endpoint cannot be used to probe another user's inbox.

`GET /notifications` now also returns a `read` boolean per row (derived from
`read_at`) per addendum v2; the legacy `read_at`, `user_id` and `request_id`
fields remain as additive extras that clients ignore. `GET /config` adds the
fixed `demo_mode: true` marker from the addendum. docs/API.md still describes the
older v1 shape; reconciling it is deferred to task A14 (doc pass) because the
overnight-loop rules restrict this iteration's edits to api/ + handoff/tasks/
decisions files. The bus, notifier, config and notifications code already had
tests; added race-free concurrent pub/sub, partial notifier write-failure,
mark-read store/HTTP owner-scoping and `read`/`demo_mode` shape tests.

## D15 — Duplicate loop processes on iteration 1 (operational)
Two `scripts/loop.sh opencode api ...` invocations were running the identical
"iteration 1" prompt against the same working tree at once (two `opencode run`
PIDs). The parallel process authored and committed A3 (`ca676a3`) while this
process verified the gate and deferred further writes to avoid racing it. No
code was duplicated or reverted. Decision: when a parallel api loop is detected,
let the in-flight process finish its commit, verify gate + task box + handoff,
and record the anomaly here instead of competing on the same task.

## D16 — A9 self-contained smoke script
`scripts/smoke.sh` no longer expects an externally running server. It builds
`./cmd/server` into a temp dir, asks the OS for a free ephemeral port with a
tiny Python socket helper, starts the server with `NEXCONN_FAKE=1`, an explicit
`JWT_SECRET`, `DEMO_OTP=123456`, `MATCH_RADIUS_KM=10`, a temp `DB_PATH` and the
inherited `FEATURES`, then kills it in an EXIT trap. Explicit env values win
over any local `.env` the server loads, so runs are deterministic.

The script asserts health, config, three signups (requester/donor/bank), the
mock OTP send/verify pair, bank stock PUT/GET, request creation with match
counts and `channel_id == "req"+id`, the donor feed's `joined`/`distance_km`
fields, idempotent accept, notification read, fulfill and feed transitions.
Auth bodies include both `otp` (addendum v2) and `code` (what the current
`/auth/verify` handler actually reads); unknown fields are ignored, so the one
script keeps working when the handler is reconciled in A14.

There is no donation read endpoint until A11, so the "donated" step checks the
`donations` row written on donor accept directly in the throwaway SQLite DB
with Python's stdlib `sqlite3`; it also asserts the requester's
`request.accepted` notification. When A11 lands, add an HTTP assertion rather
than removing the DB check. The gate now runs the script twice (`FEATURES=`
and `FEATURES=ranks,reminders`); both passed. Requires curl, jq, python3 and go.

## D17 — Duplicate api loops again on iteration 2 (operational)
Two `opencode run` api loops for iteration 2 were live on the same tree again
(D15 recurrence). Two independently written smoke scripts raced: this session's
version was committed first (`6377709`), then the parallel process overwrote
the working tree with its own, broader version whose `jq_ok` helper dropped the
`--arg` options and whose failure path printed raw responses (including a JWT).
Rather than revert the other version, we fixed it in place (`e9b2286`): `jq_ok`
forwards every argument except the trailing label to jq, and failures redact
`token`, `otp` and `phone` fields. Kept the parallel version's extra coverage
(OTP send/verify, idempotent mark-read, SQLite donation-row check, post-flow
config check). Rule retained: with duplicate loops, commit small atomic changes,
re-read files before each write, verify the gate, and never revert a peer's work.

## D18 — A10 duplicate-loop convergence (operational)
Iteration 3 had two api loops writing A10 at once (D15/D17 recurrence). The
peer's `db/seed.sql` (extra `request_members` rows, full donor profiles) and
`db/embed.go` Seed embed were kept; my duplicate Seed declaration was removed
in place, never reverted. The store method raced between `Reset` and `Reseed`,
so `api/internal/store/seed.go` now defines `Reset` plus a `Reseed` alias,
which keeps every caller compiling regardless of which name a loop used.
The dev route is registered only via `httpapi.WithDevRoutes()` when `DEV=1`;
`POST /dev/reset` is unauthenticated so the demo can reset before login.
The transaction wipes notifications, donations, request_members, requests,
bank_stock and users before inserting the seed, so resets are repeatable.

## D19 — A11 profile and donation recording
`GET /me` and `PUT /me` return `{"user":...,"derived":{eligible,next_eligible_at,
donation_count,rank}}`. `rank` is typed (`{key,label}`) but always null until A12
lands, so clients can rely on the shape now. `PUT /me` applies only the six
addendum fields: pointers mean "unchanged", an empty `last_donated_at` clears the
column, and lat/lng/weight/height/date are validated before any write.

Derived eligibility reuses the tested `matching.Eligible` unchanged. Two details
bridge it to addendum v2: (1) the addendum says unknown age/weight count as
eligible while the D11 pure function requires them known, so /me fills only
unknown values with known-eligible defaults (age 30, weight 60) before calling
it; (2) `next_eligible_at` comes from a new pure `matching.NextEligibleAt` using
the same 90/120-day interval, formatted as `YYYY-MM-DD`, null when no last
donation is stored or the wait has elapsed. Non-donors always report
`eligible:false` and `next_eligible_at:null`.

`POST /requests/{id}/donated` is donor-only and requires room membership (403
otherwise; missing request 404). Because A8 already writes one donations row on
accept, the endpoint reuses that row via `Store.DonationFor` and only creates a
row when none exists; the (request, donor) unique key and `INSERT OR IGNORE`
make it idempotent. `donation_count` counts all donation rows for the donor, so
accept + donated + repeat all report the same number. The response maps the
stored `created_at` to the contract's `donated_at`.

`donation.recorded` is published on every successful /donated call, including
repeats: without a new marker column there is no way to distinguish "first
record" from "already recorded on accept". Subscribers (A12 ranks, future
messages) must therefore be idempotent; the rank subscriber only emits on an
actual rank change. Smoke keeps its A9 SQLite row assertion and adds HTTP
assertions for /me, /donated, idempotency and donation_count. docs/API.md is
still deliberately untouched; A14 owns the doc reconciliation.

## D20 — A12 ranks feature behind flag

`ranks` is a client-safe feature flag. When enabled, `GET/PUT /me` fill
`derived.rank` from pure `matching.RankForCount(donation_count)` (thresholds per
addendum v2: 1 First Drop, 3 Helper, 5 Silver Lifeline, 10 Gold Lifeline, 25
Lifesaver). Rank is computed on the fly from `donation_count`; no rank column is
persisted because the count is the source of truth and recomputation is cheap.

A new `internal/ranks` package subscribes to `events.DonationRecorded` only when
`FEATURES` contains `ranks` (wired in `cmd/server/main.go`). The handler emits a
`rank_up` notification using COPY.md: `"{n} donations. You're now a {rank}."`
with type `rank_up` and title `Rank up`. Because D19 publishes
`donation.recorded` on every successful /donated call (including repeats), the
handler is idempotent: it ignores non-threshold counts and dedupes by checking
`store.HasNotification(userID,"rank_up",body)` before insert.

Smoke script was updated to accept rank in `/me` when `FEATURES` includes
`ranks`, preserving the old null-rank assertion when the flag is off.

## D21 — Gate fix: deterministic "newest first" ordering (iteration 6 entry)

Entry gate failed in `ranks.TestHandleEmitsRankUpOncePerThreshold`: two rank_up
notifications inserted in the same second both had identical `created_at`
(`datetime('now')` has second precision), so the `ORDER BY created_at DESC, id DESC`
tiebreaker fell back to random alphanumeric IDs and returned insertion order
backwards. This was a real contract bug ("newest first"), not just a flaky test.

Fix: both `Store.Notifications` and `Store.Requests` now order by
`ORDER BY created_at DESC, rowid DESC`. SQLite's implicit, monotonically
increasing `rowid` is a stable insertion-order tiebreaker for these rowid tables
(rows are never hard-deleted), so tied timestamps now sort newest-first. No
schema change and no change to clients when timestamps already differ. Verified
with `-race -count=10` and the full gate (both smoke modes).

## D22 — Duplicate api loops again, deterministic tie-break (iteration 5/6)

Two `loop.sh opencode api ...` processes ran against this same tree at once
(D15/D17/D18 recurrence): the pts/6 loop entered "iteration 6" with gate FAIL and
committed the rowid ordering fix `3d17bce` (D21), then began A13; the pts/4 loop
entered "iteration 5" with gate PASS (this session). To avoid two agents writing
the same A13 files, this session deferred the task to the in-flight sibling and
kept its own writes to this decision log and the handoff only. No code was
duplicated or reverted.

Tie-break rule for future duplicate-loop iterations: the session whose prompt
names the LOWER iteration number records the deferral and owns no task letter;
the HIGHER-numbered session owns the current unchecked task and the handoff
rewrite. Both loops cannot be stopped from inside an agent iteration (do not
edit `loop.sh` or kill a peer), so a human must stop the extra loop; until then
re-read files before every write, commit atomically, and never revert peer work.

## D23 — Both api loops now on iteration 6 (operational)
The D15/D17/D18/D22 duplicate recurred with both `opencode run` api processes
naming iteration 6: pts/6 (gate-FAIL prompt, started 03:47) and pts/4 (gate-PASS
prompt, started 03:52, this session). The iteration-number tie-break in D22 no
longer distinguishes them, so refine it: when iteration numbers are equal, the
EARLIER-started loop owns the current unchecked task and the LATER-started loop
records the deferral. By that rule the pts/6 loop keeps A13 (as the handoff and
D22 already assign it). At check time it had uncommitted A13 work in
`api/internal/store/notifications.go` (`HasNotificationForRequest`,
`HasNotificationSince` for idempotent reminders), confirming it was mid-task;
writing A13 here would have clobbered that work. This session therefore owns no
task letter, re-verified the entry gate PASS on committed HEAD, and did not
touch api/ code. Only docs/decisions-api.md and docs/handoff/api.md were edited,
committed with explicit pathspec so the peer's uncommitted file is never staged.
A human still needs to stop one `scripts/loop.sh opencode api ...` process.
Postscript: this session's two doc edits were swept into the peer's `c850325`
commit (the peer commits with `-a`) before my own explicit-pathspec commit could
run; the peer's in-flight `request.go` was NOT included. Net tree state is correct
and nothing is left uncommitted by this session.

## D24 — Iteration 7 duplicate loop; defer A13 to actively-editing peer (operational)
This session is the "iteration 7, gate PASS" loop (PID 191522, started 03:56:04,
loop.sh 127627). The sibling "iteration 6, gate FAIL" loop (PID 177280, started
03:47:54, loop.sh 126314) is still alive and mid-flight on A13: at check time it
had uncommitted edits to api/cmd/server/main.go (reminders subscription, hourly
ticker, dev route), api/internal/httpapi/dev.go (devRunReminders) and
api/internal/httpapi/server.go (reminders field + route). Its last commits are
c850325 (store helpers), 40c073d (filters behind flag) and 89550b6 (handler tests).

D22's "higher iteration owns the task" rule is refined: its purpose is to stop
two agents racing on the same files, so it yields when the lower-numbered loop is
demonstrably editing those files right now. Following it literally here would
clobber the peer's uncommitted A13 work (the exact failure D15/D17/D18 guard
against). Decision: re-verified the entry gate PASS, deferred A13 to the in-flight
peer, touched no api/ code, did not tick A13, and limited writes to this decision
log and the handoff, committed with an explicit pathspec. No task box changed.
A human still needs to stop one of the two `scripts/loop.sh opencode api` loops.

## D25 — A13 reminders feature implementation (iteration 6, gate-FAIL loop)

A13 is complete and the task box is ticked. Design decisions worth remembering:

* **Flag-gated filters.** `CreateRequest` keeps the core path exactly as before
  (`Store.DonorsByGroup`, which already excludes `available=0` in SQL). With
  `reminders` on it instead uses the new `Store.DonorsByGroupAll` and runs
  `matching.NewPipeline(ByAvailability(), ByEligibility())` before distance
  ranking and the top-10 cap, so `matches.donors` and the `request.created`
  recipients reflect the filters. Unknown age/weight are filled with the same
  known-eligible defaults (30 / 60 kg) that `/me` uses, so the pure strict
  `Eligible` does not contradict the addendum's permissive unknown rule. The
  store's built-in availability check means "enable isAvailable" is explicit in
  the pipeline but not a behavioural change for the core path; flipping that
  would need a separate decision.
* **match_nearby.** A new `internal/reminders` handler subscribes to
  `request.created`. It looks up each recipient (banks are recipients too) and
  only notifies donors, computing distance from the stored request coordinates
  with `matching.DistanceKM`. Body follows COPY.md with one decimal for km to
  avoid a nonsense "0 km away". Dedupe is per (user, type, request) through
  `Store.HasNotificationForRequest`, so duplicate event delivery is harmless.
  Title is `Nearby match`.
* **eligible_again / once per period.** `RunEligibilityChecks` scans `Store.Donors`,
  skips anyone with no (or unparseable) last donation date and anyone still
  waiting, and uses COPY.md's exact body. "Once per eligibility period" is
  deduped with `Store.HasNotificationSince(user, type, last_donated_at)`: an
  existing reminder written at or after the current donation cycle suppresses a
  new one; a later donation starts a new cycle. No schema or event-payload
  change was needed. Title is `Ready again?`.
* **Wiring.** `main.go` always builds the runner so `POST /dev/run-reminders`
  works in DEV=1 even when the flag is off; the `request.created` subscription
  and the hourly `RunTicker` are gated on the flag. `httpapi` declares a small
  `ReminderRunner` interface, so it never imports the feature package. The dev
  route is registered only with `WithDevRoutes()` (DEV=1), is unauthenticated
  like `/dev/reset`, and returns `{"status":"ok","sent":N}`. Keeping
  `devRoutes(bool)` unchanged preserved `main_test.go` option-count assertions.
* Gate `scripts/gate-api.sh` passes: build, vet, `-race -count=1 ./...` and both
  smoke modes. No fixed ports, no `.env`, no docs/PLAN.md, no `app/` edits.

## D26 — Iteration 7 (pts/6) defers A14; doc reconciliation checklist (operational)

This session is the `api` iteration-7 loop on pts/6 (loop.sh 126314, PID 199868,
started 03:59). The sibling `api` iteration-8 loop on pts/4 (loop.sh 127627,
PID 197313, started 03:58) is live on the same tree. D22 assigns the current
unchecked task to the higher-numbered loop, so iteration 8 owns A14 and this
session owns no task letter. D24's exception does not apply: the tree was clean
at the 04:00 check, so there was no in-flight A14 edit to protect. Re-verified
`scripts/gate-api.sh` PASS on committed HEAD; did not touch `api/`, docs/API.md
or README.md, did not tick A14. Only this log and the handoff were edited.

**A14 scope call for the owning loop.** A14 explicitly names docs/API.md and a
README section, but per-iteration rule 5 lists only `api/` plus the three handoff
docs. AGENTS.md gives opencode ownership of docs/API.md and the task wording
explicitly authorizes both files, so the specific authorization overrides the
general folder guardrail for those two files (lex specialis). Root README.md is
shared with the app agent: add only a short "Running the API" block and leave
app content untouched, or put it in `api/README.md` (unambiguously in scope).

**Verified doc/code gaps (read from handlers, not guessed):**
- `GET /config` actually returns `{"features":[...],"demo_mode":true}` from
  comma-separated `FEATURES` (empty default); doc says only `features` and
  mentions `notifications`, which is not a flag the code reads.
- `POST /auth/otp/send` returns `{"sent":true}` with no `demo` key (addendum's
  `"demo":true` is not implemented); OTP is `DEMO_OTP`, never in the response.
- `POST /auth/verify` reads `code`, NOT `otp`; unknown phone is 404 "user not
  found", wrong code 401 "invalid otp", and the response is the plain
  `{user,token,nexconn_token}` — no `is_new` (the addendum's `{"is_new":true}`
  for unknown phones is not implemented).
- `POST /auth/signup` has no OTP field in the request struct; consent is a
  `*bool` and a duplicate phone is 409 "user already exists".
- `GET /notifications` rows include a `read` boolean plus legacy `read_at`,
  `user_id`, `request_id`; there IS a `POST /notifications/{id}/read` -> 204
  (owner-scoped, idempotent) which docs/API.md says does not exist.
- `GET /me`, `PUT /me`, `POST /requests/{id}/donated` and `POST /dev/run-reminders`
  are shipped but undocumented. `POST /requests/{id}/cancel` is documented as
  optional and is NOT implemented — mark it as such.
- Dev notes should name `DEV=1` as the gate for `/dev/reset` and
  `/dev/run-reminders`, and `NEXCONN_FAKE=1` (fake preferred over the legacy
  `NEXCONN_MOCK=1` no-op) for offline runs.

A human still needs to stop one of the two `scripts/loop.sh opencode api` loops
(D15/D17/D18/D22/D23/D24 recurrence). Until then re-read before every write,
commit atomically with explicit pathspecs, and never revert peer work.

## D27 — A14 final doc pass (iteration 8)

A14 is complete and ticked; the gate passes (build, vet, `-race -count=1 ./...`,
both smoke modes). Scope decision: rule 5 normally limits edits to `api/` plus
the handoff/tasks/decisions docs, but A14 is the human's own task wording and
explicitly asks for a README section and an exact `docs/API.md` reconciliation.
That specific instruction overrides the general folder limit for those two
files, so this pass edited root `README.md` and `docs/API.md` directly; no code,
no `.env`, no docs/PLAN.md and no `app/` files were touched.

`docs/API.md` is now a v2 contract describing the shipped code, not just the
older v1 shape: phone auth, `/me`, notifications with `read` + mark-read, donated,
dev routes, feature flags, offline modes and the full response shapes. Where the
code diverges from `docs/API-addendum-v2.md` it is documented in a
"Deviations from addendum v2" section rather than silently changed: `/auth/verify`
reads `code` (not `otp`) and has no `is_new` pre-signup path, signup does not read
`otp` and only rejects an explicit `consent:false`, `/auth/otp/send` omits `demo`,
notifications carry additive fields, and `/config` defaults `features` to `[]`.
Deliberate choice: this is a doc pass, so the code was left unchanged; reconciling
the auth wire to the addendum is left for a future task/human decision. The smoke
script already sends both `otp` and `code`, so both paths keep working. The README
gained a "Running the API" section covering offline `NEXCONN_FAKE=1` startup,
env knobs and the self-contained gate/smoke script.

Operational: the two api loops recurred (D15/D17/D18/D22/D24) — this is iteration
8 (PID 197313, loop.sh 127627, started 03:58:45) and the sibling is iteration 7
(PID 199868, loop.sh 126314, started 03:59:26). Per D22 the higher-numbered loop
owns the current task and handoff, so this session owned A14. The tree was clean
at every write, edits were committed with explicit pathspecs, and no peer work
was reverted. A human still needs to stop one of the duplicate `loop.sh opencode
api` processes.

## D28 — Canonical urgency, RFC3339 created_at, OTP field aliases (human task)

Human-assigned fixes (docs updated first in `docs/API.md` and
`docs/DATA_MODEL.md`), then code, tests and smoke:

* **Urgency.** Canonical values are `low|medium|high|critical`; the service maps
  `planned`→`low`, `med`→`medium`, `urgent`→`high` (case/whitespace insensitive)
  before the store sees a request. Fresh schema CHECK lists only canonical
  values. Existing databases are rebuilt on boot with `PRAGMA foreign_keys=OFF`
  around a transaction: rows are copied with the alias mapping and the new
  CHECK/default, indexes are recreated, and child FKs stay intact. The request
  feed SQL orders by `CASE urgency` priority then `created_at DESC, rowid DESC`,
  so "matching by urgency" is observable in `GET /requests`. Seed data uses the
  canonical `critical` value plus an explicit RFC3339 `created_at`.
* **Timestamps.** All `created_at` writes (users, requests, notifications,
  donations, plus stock `updated_at` and `fulfilled_at`/`read_at`) use
  `time.Now().UTC().Format(time.RFC3339)` or `strftime('%Y-%m-%dT%H:%M:%SZ')`.
  Reads normalise legacy SQLite `YYYY-MM-DD HH:MM:SS` (and RFC3339 offsets) to
  UTC `Z`; empty/unparseable legacy values become `1970-01-01T00:00:00Z` rather
  than `""`. `User.CreatedAt` is now a JSON field, so `/me` and auth responses
  expose it; `donated_at` is normalised the same way.
* **OTP aliases.** `/auth/verify` accepts `otp` as an alias of `code` and
  `/auth/signup` accepts either field; `code` wins when both are present. Signup
  keeps treating a missing code as legacy-compatible but validates a supplied
  one against `DEMO_OTP` and returns 401 `invalid otp` on a mismatch. `is_new`
  and `demo` from the addendum remain deliberately unimplemented (documented
  deviations).
* No app files, `.env`, `AGENTS.md` or `docs/PLAN.md` were touched. The
  untracked empty `api/data/hospitals.json` predates this task and was left
  alone; it is not part of the commit.

## D29 — Hospital directory, request components, apheresis donors (human task)

Docs were updated first in `docs/API.md` and `docs/DATA_MODEL.md`, then code,
tests and smoke. Decisions:

* **Hospitals.** The previously empty, untracked `api/data/hospitals.json` is
  now a real embedded dataset (package `api/data`, `go:embed`). `GET /hospitals`
  is public like `/config`: substring search over `name`/`area`, nearest-first
  when both `lat` and `lng` are given, default `limit=20` capped at 50. All bad
  query combinations are 400 with a specific `error`.
* **Components.** `requests.component` and `bank_stock.component` default to
  `whole_blood`, accepted values `whole_blood|red_cells|platelets|plasma|cryo|other`.
  `bank_stock`'s PK becomes `(bank_id, blood_group, component)` so one bank can
  hold both whole blood and plasma for the same group; the legacy PK table is
  rebuilt on boot with `whole_blood` on every old row. `requests` gains nullable
  `notes` (<= 500 chars). `hospital_id` is resolved from the embedded directory
  and fills `hospital`/`lat`/`lng`; when present it wins over supplied coordinates.
* **Compatibility.** Whole blood/red cells/other keep the existing red-cell ABO/Rh
  chart and the live exact-group rule (D4). Plasma/cryo use reverse ABO with Rh
  ignored, read literally from the human's `O<-all, A<-A,AB, B<-B,AB, AB<-AB`
  as *patient ← acceptable donor groups*: an `O` patient can receive any plasma
  (universal recipient) and an `AB` patient only `AB` plasma — the inverse of
  the red-cell chart. Platelets treat same-ABO as preferred (ranked, not
  excluded) and give Rh-negative patients Rh-negative donors first. Plasma,
  cryo and platelets also require `users.apheresis_ok=1` (new column, default
  false, set via `PUT /me`) for both matching and donor-feed visibility.
* **Errors.** Every validation failure now returns 400 with a specific
  `{"error":...}` message, including bad hospital ids, missing coordinates,
  bad components and invalid query parameters. The app's urgency values
  (`lib/features/requester/requester_screen.dart`) are already the canonical
  `low|medium|high|critical` set, so no enum/doc change was needed there.
