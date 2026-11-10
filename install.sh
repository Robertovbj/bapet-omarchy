#!/usr/bin/env bash
# Installs BApet (Blue Archive Desktop Pet) and its Omarchy integration.
#
#   ./install.sh               install or update (safe to run again)
#   ./install.sh --uninstall   remove the integration (keeps pets, settings and models)
#
# BApet is cloned unmodified. Everything specific to Omarchy/Hyprland lives in this repo.
set -euo pipefail

HERE="$(cd "$(dirname "$0")" && pwd)"
BAPET_REPO="${BAPET_REPO:-https://github.com/kagdakj/BApet}"
BAPET_REF="${BAPET_REF:-}"              # optional tag/branch/commit; empty = default branch
BAPET_HOME="${BAPET_HOME:-$HOME/.local/share/bapet}"
BIN_DIR="$HOME/.local/bin"
DATA_DIR="${XDG_DATA_HOME:-$HOME/.local/share}"
CONFIG_DIR="${XDG_CONFIG_HOME:-$HOME/.config}"
HYPR_DIR="$CONFIG_DIR/hypr"
PLUGIN_ID="bapet.desktop-pets"
PLUGIN_DIR="$CONFIG_DIR/omarchy/plugins/$PLUGIN_ID"
SHELL_JSON="$CONFIG_DIR/omarchy/shell.json"
TRAY_ID="BlueArchiveDesktopPet"
REQUIRE_LINE='require("hypr.bapet")'
REQUIRE_COMMENT='-- BApet: pet window rules.'
STAMP="$(date +%s)"

say() { printf '\033[1;35m==>\033[0m %s\n' "$*"; }
warn() { printf '\033[1;33m!!\033[0m %s\n' "$*" >&2; }
die() { printf '\033[1;31mxx\033[0m %s\n' "$*" >&2; exit 1; }

backup() { [ -f "$1" ] && cp "$1" "$1.bak.$STAMP" && echo "   backup: $1.bak.$STAMP"; return 0; }

stop_app() {
  pkill -f "^$BAPET_HOME/venv/bin/python -m bapet" 2>/dev/null || true
}

uninstall() {
  say "Stopping the app"
  stop_app

  say "Removing commands, launcher entry and icon"
  rm -f "$BIN_DIR/BlueArchiveDesktopPet" "$BIN_DIR/bapet-ghost" "$BIN_DIR/bapet-update" \
        "$DATA_DIR/applications/bluearchive-desktop-pet.desktop" \
        "$DATA_DIR/icons/hicolor/256x256/apps/bluearchive-desktop-pet.png"

  say "Removing Hyprland rules"
  if [ -f "$HYPR_DIR/hyprland.lua" ] && grep -qF "$REQUIRE_LINE" "$HYPR_DIR/hyprland.lua"; then
    backup "$HYPR_DIR/hyprland.lua"
    # Older installs wrote the comment in Portuguese; remove either version.
    sed -i "/^-- BApet: pet window rules\.$/d; /^-- BApet: regras das janelas dos pets\.$/d; /^require(\"hypr\.bapet\")$/d" "$HYPR_DIR/hyprland.lua"
  fi
  rm -f "$HYPR_DIR/bapet.lua"
  command -v hyprctl >/dev/null && hyprctl reload >/dev/null || true

  say "Removing the bar plugin"
  if [ -f "$SHELL_JSON" ]; then
    backup "$SHELL_JSON"
    jq --arg id "$PLUGIN_ID" --arg tray "$TRAY_ID" '
      .bar.layout |= with_entries(.value |= (if type == "array" then map(select(.id != $id)) else . end))
      | (.bar.layout.right[]? | select(.id == "omarchy.tray") | .hidden) |= ((. // []) - [$tray])
    ' "$SHELL_JSON" > "$SHELL_JSON.tmp" && mv "$SHELL_JSON.tmp" "$SHELL_JSON"
  fi
  rm -rf "$PLUGIN_DIR"

  say "Removing the clone and venv ($BAPET_HOME)"
  rm -rf "$BAPET_HOME"

  echo
  echo "Uninstalled. Your pets, settings and downloaded models are still in"
  echo "  $CONFIG_DIR/bluearchive-desktop-pet and $DATA_DIR/bluearchive-desktop-pet"
}

[ "${1:-}" = "--uninstall" ] && { uninstall; exit 0; }
[ $# -gt 0 ] && die "usage: ./install.sh [--uninstall]"

# --------------------------------------------------------------------------- checks

command -v hyprctl >/dev/null || die "Hyprland not found. This installer is for Omarchy."
command -v omarchy >/dev/null || die "The 'omarchy' command was not found. This installer is for Omarchy."
[ -f "$HYPR_DIR/hyprland.lua" ] || die "$HYPR_DIR/hyprland.lua not found. This needs Omarchy with the Lua Hyprland config."

# --------------------------------------------------------------------------- dependencies

say "Checking system packages"
# git/jq/libnotify: installer and scripts. xcb-util-*/libxkbcommon-x11: Qt on XWayland.
# mesa: OpenGL 3.3 for the renderer. libxcb: the app's click-through shape.
PKGS=(git jq libnotify mesa libxcb xcb-util-cursor xcb-util-wm xcb-util-keysyms
      xcb-util-image xcb-util-renderutil libxkbcommon-x11)
# uv may come from outside pacman (mise, pipx...), so only install it if it's not on the PATH.
command -v uv >/dev/null || PKGS+=(uv)
missing=()
for p in "${PKGS[@]}"; do pacman -Qq "$p" >/dev/null 2>&1 || missing+=("$p"); done
if [ ${#missing[@]} -gt 0 ]; then
  echo "   installing: ${missing[*]}"
  omarchy pkg add "${missing[@]}"
fi
command -v uv >/dev/null || die "uv is still not on the PATH."

# --------------------------------------------------------------------------- BApet

say "Fetching BApet into $BAPET_HOME/src"
mkdir -p "$BAPET_HOME"
if [ -d "$BAPET_HOME/src/.git" ]; then
  git -C "$BAPET_HOME/src" fetch --tags --quiet
  if [ -n "$BAPET_REF" ]; then
    git -C "$BAPET_HOME/src" checkout --quiet "$BAPET_REF"
  else
    git -C "$BAPET_HOME/src" pull --ff-only --quiet
  fi
else
  git clone --quiet "$BAPET_REPO" "$BAPET_HOME/src"
  [ -n "$BAPET_REF" ] && git -C "$BAPET_HOME/src" checkout --quiet "$BAPET_REF"
fi
echo "   version: $(git -C "$BAPET_HOME/src" describe --tags --always)"

say "Setting up Python 3.12 and dependencies"
# BApet's own builds use 3.12. uv downloads it if the system doesn't have it.
[ -x "$BAPET_HOME/venv/bin/python" ] || uv venv --quiet --python 3.12 "$BAPET_HOME/venv"
VIRTUAL_ENV="$BAPET_HOME/venv" uv pip install --quiet -r "$BAPET_HOME/src/requirements.txt"

# --------------------------------------------------------------------------- files

say "Installing local tweaks (camera angle, outline)"
mkdir -p "$BAPET_HOME/overrides"
install -m 644 "$HERE/overrides/bapet_omarchy.py" "$BAPET_HOME/overrides/"

say "Installing commands into $BIN_DIR"
mkdir -p "$BIN_DIR"
install -m 755 "$HERE/bin/BlueArchiveDesktopPet" "$HERE/bin/bapet-ghost" "$HERE/bin/bapet-update" "$BIN_DIR/"
case ":$PATH:" in *":$BIN_DIR:"*) ;; *) warn "$BIN_DIR is not on your PATH. The SUPER+ALT+P shortcut needs it." ;; esac

say "Adding the launcher entry"
mkdir -p "$DATA_DIR/applications" "$DATA_DIR/icons/hicolor/256x256/apps"
install -m 644 "$BAPET_HOME/src/bapet/assets/icon.png" "$DATA_DIR/icons/hicolor/256x256/apps/bluearchive-desktop-pet.png"
sed "s|@BIN_DIR@|$BIN_DIR|g" "$HERE/applications/bluearchive-desktop-pet.desktop" \
  > "$DATA_DIR/applications/bluearchive-desktop-pet.desktop"
command -v update-desktop-database >/dev/null && update-desktop-database "$DATA_DIR/applications" 2>/dev/null || true

say "Installing Hyprland rules"
install -m 644 "$HERE/hypr/bapet.lua" "$HYPR_DIR/bapet.lua"
if ! grep -qF "$REQUIRE_LINE" "$HYPR_DIR/hyprland.lua"; then
  backup "$HYPR_DIR/hyprland.lua"
  printf '\n%s\n%s\n' "$REQUIRE_COMMENT" "$REQUIRE_LINE" >> "$HYPR_DIR/hyprland.lua"
fi
hyprctl reload >/dev/null
sleep 1
errors="$(hyprctl configerrors | tr -d '[:space:]')"
[ -z "$errors" ] || warn "Hyprland reported config errors: $(hyprctl configerrors)"

say "Installing the bar plugin ($PLUGIN_ID)"
mkdir -p "$(dirname "$PLUGIN_DIR")"
rm -rf "$PLUGIN_DIR"
cp -r "$HERE/plugin/$PLUGIN_ID" "$PLUGIN_DIR"
omarchy-shell shell rescanPlugins >/dev/null 2>&1 || true
if [ -f "$SHELL_JSON" ] && jq -e --arg id "$PLUGIN_ID" '[.bar.layout[]? | arrays | .[] | .id] | index($id)' "$SHELL_JSON" >/dev/null; then
  echo "   already on the bar"
else
  omarchy bar put "$PLUGIN_ID" --section tray
fi
# Hide the app's own tray icon. The plugin already shows it, menu included.
if [ -f "$SHELL_JSON" ] && jq -e '.bar.layout.right[]? | select(.id == "omarchy.tray")' "$SHELL_JSON" >/dev/null; then
  if ! jq -e --arg tray "$TRAY_ID" '.bar.layout.right[] | select(.id == "omarchy.tray") | (.hidden // []) | index($tray)' "$SHELL_JSON" >/dev/null; then
    backup "$SHELL_JSON"
    jq --arg tray "$TRAY_ID" '(.bar.layout.right[] | select(.id == "omarchy.tray") | .hidden) |= ((. // []) + [$tray])' \
      "$SHELL_JSON" > "$SHELL_JSON.tmp" && mv "$SHELL_JSON.tmp" "$SHELL_JSON"
  fi
fi

echo
say "Done."
cat <<EOF
   Open:    the launcher (Blue Archive Desktop Pet), the paw icon in the bar's tray,
            or BlueArchiveDesktopPet --add "Hina"
   Drag:    SUPER+ALT+P switches pets between click-through and interactive
   Update:  ./update.sh (this repo, BApet and the app), or bapet-update (BApet only)
EOF
