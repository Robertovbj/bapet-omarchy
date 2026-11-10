#!/usr/bin/env bash
# Atualiza este repo (git pull), o BApet e reaplica a integração com ./install.sh.
# Se o app estiver aberto, reinicia ele no fim para carregar a versão nova.
set -euo pipefail
HERE="$(cd "$(dirname "$0")" && pwd)"
BAPET_HOME="${BAPET_HOME:-$HOME/.local/share/bapet}"
APP_PATTERN="^$BAPET_HOME/venv/bin/python -m bapet"

cd "$HERE"
if [ -n "$(git status --porcelain)" ]; then
  echo "Há mudanças locais neste repo; faça commit ou stash antes de atualizar." >&2
  git status --short >&2
  exit 1
fi
if git remote | grep -q .; then
  before=$(git rev-parse HEAD)
  git pull --ff-only
  [ "$before" != "$(git rev-parse HEAD)" ] && git log --oneline "$before..HEAD"
else
  echo "Repo sem remote configurado; pulando git pull."
fi

running=0
pgrep -f "$APP_PATTERN" >/dev/null && running=1

# Roda o install.sh já atualizado, que também atualiza o BApet.
"$HERE/install.sh"

if [ "$running" = 1 ]; then
  echo "Reiniciando o app"
  pkill -f "$APP_PATTERN" || true
  for _ in $(seq 1 20); do pgrep -f "$APP_PATTERN" >/dev/null || break; sleep 0.25; done
  setsid -f "$HOME/.local/bin/BlueArchiveDesktopPet" >/dev/null 2>&1 < /dev/null
fi
