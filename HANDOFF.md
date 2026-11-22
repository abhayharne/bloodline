# Handoff

**From:** Codex, human-requested Android downloads and GitHub publication
**Scope:** app/ Android release configuration (antigravity ownership), release
scripts, deploy/ and docs. No API behavior or contract change.

## Ready

- Added INTERNET permission to the main Android manifest.
- Replaced debug signing for release builds with private persistent signing.
- Generated ignored key.properties and keystores/bloodline-release.jks locally.
- Added signing generator and public-HTTPS-validated APK packaging script.
- Added portable Go container with persistent SQLite disk requirements.
- Documented installation, demo OTP and GitHub release assets in deploy/README.md.
- README links the release instructions and completed launch video.
- App gate passed: 107 tests; analyzer has existing informational issues.
- GitHub CLI is authenticated; origin/main is an ancestor of local HEAD.

## In progress

- Native signed release build is running for compilation/signing validation.
- Final APK needs a public API address; human was asked for hosting or temporary tunnel.
- GitHub source push and downloadable release are still pending.

## Next action

- Finish native build verification (apksigner and merged INTERNET permission).
- Obtain hosting choice, deploy/verify API, rebuild with API_BASE.
- Commit/push source, upload APK/checksum and launch video to GitHub Release.
- Add verified direct-download link to README.

## Notes

- Back up app/android/key.properties and app/android/keystores/ securely.
- These private signing files, .env, databases and dist/ must never be committed.
- A prior debug APK needs uninstalling before this differently signed release.
- The public build is a hackathon demo with mock OTP 123456.
