#!/usr/bin/env bash
# usage: scripts/install-guards.sh install <api_dir> <app_dir>
#        scripts/install-guards.sh remove  <api_dir> <app_dir>
# Overnight safety: blocks git push, blocks commits containing the Nexconn secret or .env,
# shims for sudo and rm (rm only allowed inside the worktree or /tmp), and OpenCode deny rules.
set -euo pipefail
mode=${1:?install|remove}; API=${2:?api dir}; APP=${3:?app dir}
common=$(git -C "$API" rev-parse --git-common-dir); case "$common" in /*) ;; *) common="$API/$common";; esac
hooks="$common/hooks"; mkdir -p "$hooks"
KIT="$(cd "$(dirname "$0")" && pwd)"

if [ "$mode" = install ]; then
  for h in pre-push pre-commit; do [ -f "$hooks/$h" ] && [ ! -f "$hooks/$h.pre-overnight" ] && mv "$hooks/$h" "$hooks/$h.pre-overnight"; done
  cat > "$hooks/pre-push" <<'H'
#!/usr/bin/env bash
echo "overnight guard: git push is disabled. Run scripts/install-guards.sh remove first." >&2; exit 1
H
  cat > "$hooks/pre-commit" <<'H'
#!/usr/bin/env bash
root=$(git rev-parse --show-toplevel)
if git diff --cached --name-only | grep -qE '(^|/)\.env$'; then echo "guard: .env staged, refusing" >&2; exit 1; fi
for f in "$root/.env" "$HOME/bloodline/.env"; do
  [ -f "$f" ] || continue
  s=$(grep -E '^(NEXCONN_APP_SECRET|JWT_SECRET)=' "$f" | cut -d= -f2-)
  while IFS= read -r v; do
    [ ${#v} -ge 8 ] && git diff --cached | grep -qF -- "$v" && { echo "guard: secret value found in staged diff, refusing" >&2; exit 1; }
  done <<< "$s"
done
exit 0
H
  chmod +x "$hooks/pre-push" "$hooks/pre-commit"
  for d in "$API" "$APP"; do
    s="$d/.loop/shims"; mkdir -p "$s"
    printf '#!/usr/bin/env bash\necho "sudo is disabled overnight" >&2; exit 1\n' > "$s/sudo"
    cat > "$s/rm" <<'R'
#!/usr/bin/env bash
root="${LOOP_ROOT:?LOOP_ROOT not set}"
for a in "$@"; do
  case "$a" in -*) continue;; esac
  p=$(realpath -m -- "$a")
  case "$p" in "$root"/*|/tmp/*) ;; *) echo "rm-guard: refusing to delete $a" >&2; exit 1;; esac
done
exec /bin/rm "$@"
R
    chmod +x "$s/sudo" "$s/rm"
  done
  cp "$KIT/overnight/opencode.json" "$API/opencode.json"
  ex=$(git -C "$API" rev-parse --git-path info/exclude); case "$ex" in /*) ;; *) ex="$API/$ex";; esac
  grep -qxF 'opencode.json' "$ex" 2>/dev/null || echo 'opencode.json' >> "$ex"
  echo "guards installed"
else
  for h in pre-push pre-commit; do rm -f "$hooks/$h"; [ -f "$hooks/$h.pre-overnight" ] && mv "$hooks/$h.pre-overnight" "$hooks/$h"; done
  rm -rf "$API/.loop/shims" "$APP/.loop/shims" "$API/opencode.json"
  echo "guards removed"
fi
