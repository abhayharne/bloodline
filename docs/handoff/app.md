# App Handoff
**From:** antigravity (app agent)  **To:** next agent / human  **Time:** 2026-11-22 17:40 IST
**Branch:** feat/app

## Done this iteration
1. **Profile Save Route Pop Fix:**
   - Fixed black screen issue when saving profile from bottom-nav Profile tab.
   - Profile edit mode stays on screen, refreshes user in AuthProvider, displays "Profile saved" SnackBar, and only pops if running as a standalone route where `canPop()` is true and not inside HomeScreen.
   - Registration mode (`Complete Profile`, `isNewUser == true`) uses `pushAndRemoveUntil` to navigate to `HomeScreen` with a clean back stack.
2. **Navigation Stack & Route Audit:**
   - Replaced `pushReplacement` in `LoginScreen` with `pushAndRemoveUntil` to `HomeScreen`.
   - Audited all route pops: logout, broadcast, donate, fulfill, and hospital picker. All dialog pops safely scope to dialog context.
   - Added `PopScope(canPop: false)` on `HomeScreen` and `RootGate` to guard against unintended root pops.
   - Added `onGenerateRoute` and `onUnknownRoute` fallbacks in `MaterialApp` to always restore `RootGate` / `HomeScreen` instead of a blank screen.
3. **Verification & Tests:**
   - Added widget tests in `core_screens_test.dart`:
     - ProfileScreen inside bottom-nav shell saves profile, displays SnackBar, and stays on screen without going blank.
     - ProfileScreen in registration mode navigates to HomeScreen via clean back stack.
   - All tests passing in `scripts/gate-app.sh`.

## State of the code
- Gate: `scripts/gate-app.sh` GREEN, `scripts/gate-api.sh` GREEN.
- Working tree clean.

## Next action
- Live demo rehearsal with backend: execute demo flows as described in `docs/DEMO_SCRIPT.md`.
