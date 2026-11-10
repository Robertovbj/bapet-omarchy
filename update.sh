#!/usr/bin/env bash
# Pulls this repo, then runs ./install.sh, which also updates BApet and
# reapplies the integration. Restarts the app at the end if it was open.
set -euo pipefail
HERE="$(cd "$(dirname "$0")" && pwd)"
BAPET_HOME="${BAPET_HOME:-$HOME/.local/share/bapet}"
APP_PATTERN="^$BAPET_HOME/venv/bin/python -m bapet"

cd "$HERE"
if [ -n "$(git status --porcelain)" ]; then
  echo "This repo has local changes. Commit or stash them before updating." >&2
  git status --short >&2
  exit 1
fi
if git remote | grep -q .; then
  before=$(git rev-parse HEAD)
  git pull --ff-only
  [ "$before" != "$(git rev-parse HEAD)" ] && git log --oneline "$before..HEAD"
else
  echo "No remote configured, skipping git pull."
fi

running=0
pgrep -f "$APP_PATTERN" >/dev/null && running=1

# Run the freshly pulled install.sh.
"$HERE/install.sh"

if [ "$running" = 1 ]; then
  echo "Restarting the app"
  pkill -f "$APP_PATTERN" || true
  for _ in $(seq 1 20); do pgrep -f "$APP_PATTERN" >/dev/null || break; sleep 0.25; done
  setsid -f "$HOME/.local/bin/BlueArchiveDesktopPet" >/dev/null 2>&1 < /dev/null
fi
