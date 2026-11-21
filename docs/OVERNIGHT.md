# Overnight runbook

## How it works
`scripts/loop.sh` runs one agent in one worktree: gate -> prompt (with gate failures injected) -> agent run -> checkpoint commit -> gate again -> repeat.
The verifier is a script (build, vet, race tests, smoke test / flutter analyze + test), so the agent cannot declare victory on its own.
Stops on: all tasks done, deadline, STOP file, 3 iterations with no commit (stalled), or exhausted quota. The tag `good-api` / `good-app` always points at the last commit where the gate passed.

## One-time setup (about 15 minutes)
1. Put the kit on main: unzip into ~/bloodline, then `git add -A && git commit -m "overnight kit"`; in both worktrees run `git merge main`.
2. Make sure each worktree has a copy of .env, and the agents are CLOSED.
3. Install tmux if needed: `sudo apt install tmux`.
4. Dry run with no AI: in ~/bloodline-api run
   `FAKE_CMD='echo hi' MAX_STALLS=1 bash scripts/loop.sh fake api scripts/gate-api.sh 'A[0-9]+' 3 0`
   It should run the gate and stop as "stalled".
5. Real 1-iteration test per agent (stay and watch):
   `MAX=1`: `bash scripts/loop.sh opencode api scripts/gate-api.sh 'A[0-9]+' 1 0` and the same with `agy app scripts/gate-app.sh 'B[0-9]+' 1 0`.
   If the agy log shows denied actions, rerun with `AGY_FLAGS=--dangerously-skip-permissions` (safety then comes from the guards below). Check `agy --help` for the exact flag names on your version.
6. Free memory: close the browser and Android Studio. Gradle builds are NOT run by the loop.

## Launch
```
tmux new -s night
cd ~/bloodline && bash scripts/night.sh 9     # hours until the hard deadline
```
Detach with Ctrl+b then d. It keeps the laptop awake (lid closed too) while it runs. Keep it plugged in.
Watch: `tail -f ~/bloodline-api/.loop/loop.log ~/bloodline-app/.loop/loop.log`
Stop early: `touch ~/bloodline-api/.loop/STOP ~/bloodline-app/.loop/STOP`

## What the guards do
git push disabled; commits containing the secret or .env refused; `sudo` blocked; `rm` only inside the worktree or /tmp; OpenCode denies curl/wget, .env reads and paths outside the worktree (except ~/go, ~/.pub-cache, /tmp). They are removed automatically when night.sh ends (or run `bash scripts/install-guards.sh remove ~/bloodline-api ~/bloodline-app`).
Not covered: an agent can still read .env through a shell command, and agy's own sandbox flag is unreliable with permission-skipping. Branches and tags are your safety net.

## Morning checklist
1. `cat ~/bloodline-*/.loop/REPORT.md` and read docs/handoff/*.md. Check blocked tasks ([!]).
2. If something is broken: `git checkout good-api` / `good-app` (last passing gate).
3. Merge: in ~/bloodline run `git merge feat/api feat/app`; expect small doc conflicts only.
4. Humans only: real build + run on the phone (`flutter run --dart-define=NEXCONN_APP_KEY=... --dart-define=API_BASE=http://<laptop-ip>:8080`), real Nexconn mode (not FAKE) smoke test, the freeze call ("UNVERIFIED-REAL"), two-phone message test, the ranks/reminders look and feel.
5. Tag `core-demo-v1` once the core path works on two phones.
