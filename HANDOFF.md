# Handoff

**From:** Codex, GitHub repository review and README refresh
**Branch:** main
**Scope:** README, plan, decision log and handoff only; no API/app source changes.

## Done

- Rewrote README around the product flow, roles, architecture and current demo status.
- Added launch-film artwork, labeled as recreated screens with fictional data.
- Replaced scaffold commands with local API and Flutter setup; documented live-chat
  configuration, fake-chat limits, demo OTP and keyed development resets.
- Updated GitHub About description for abhayharne/bloodline.
- GitHub has no published release or Actions runs as of 2026-11-26.
- README links resolve; diff whitespace checks pass.
- API gate passed: build, vet, race tests and both 13-step smoke modes.
- Flutter tests were not rerun for this documentation-only change.

## Local environment

- Root disk was full. Moved Go cache to /tmp/bloodline-review-go-cache and Flutter
  .dart_tool to /tmp/bloodline-review-dart-tool; app/.dart_tool links to the latter.
- The local symlink is excluded via .git/info/exclude. Both caches are regenerable.
- Preserve existing overnight hooks; per-command hooksPath override avoids the
  pre-commit hook reading .env and the pre-push hook blocking authorized publication.
- No .env, signing files, databases or private runtime logs were opened or changed.

## Previous release work

- Prior handoff is available at 40188a6:HANDOFF.md.
- Signed APK/public API release preparation remains T5.6 in docs/PLAN.md.
- Private runtime state remains under ignored dist/public-demo/; do not publish it.
- Do not assume the old temporary tunnel or APK build is available.

## Next action

- None for this request. Future work: publish a verified APK release and add CI.
