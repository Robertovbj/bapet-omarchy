#!/usr/bin/env bash
# Instala o BApet (Blue Archive Desktop Pet) integrado ao Omarchy.
#
#   ./install.sh               instala ou atualiza (pode rodar de novo à vontade)
#   ./install.sh --uninstall   remove a integração (mantém pets, settings e modelos)
#
# O código do BApet é clonado sem modificações; tudo que é específico do
# Omarchy/Hyprland mora neste repo.
set -euo pipefail

HERE="$(cd "$(dirname "$0")" && pwd)"
BAPET_REPO="${BAPET_REPO:-https://github.com/kagdakj/BApet}"
BAPET_REF="${BAPET_REF:-}"              # tag/branch/commit opcional; vazio = branch padrão
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
STAMP="$(date +%s)"

say() { printf '\033[1;35m==>\033[0m %s\n' "$*"; }
warn() { printf '\033[1;33m!!\033[0m %s\n' "$*" >&2; }
die() { printf '\033[1;31mxx\033[0m %s\n' "$*" >&2; exit 1; }

backup() { [ -f "$1" ] && cp "$1" "$1.bak.$STAMP" && echo "   backup: $1.bak.$STAMP"; return 0; }

stop_app() {
  pkill -f "^$BAPET_HOME/venv/bin/python -m bapet" 2>/dev/null || true
}

uninstall() {
  say "Parando o app"
  stop_app

  say "Removendo binários, atalho e ícone"
  rm -f "$BIN_DIR/BlueArchiveDesktopPet" "$BIN_DIR/bapet-ghost" "$BIN_DIR/bapet-update" \
        "$DATA_DIR/applications/bluearchive-desktop-pet.desktop" \
        "$DATA_DIR/icons/hicolor/256x256/apps/bluearchive-desktop-pet.png"

  say "Removendo regras do Hyprland"
  if [ -f "$HYPR_DIR/hyprland.lua" ] && grep -qF "$REQUIRE_LINE" "$HYPR_DIR/hyprland.lua"; then
    backup "$HYPR_DIR/hyprland.lua"
    sed -i "/^-- BApet: regras das janelas dos pets\.$/d; /^require(\"hypr\.bapet\")$/d" "$HYPR_DIR/hyprland.lua"
  fi
  rm -f "$HYPR_DIR/bapet.lua"
  command -v hyprctl >/dev/null && hyprctl reload >/dev/null || true

  say "Removendo plugin da barra"
  if [ -f "$SHELL_JSON" ]; then
    backup "$SHELL_JSON"
    jq --arg id "$PLUGIN_ID" --arg tray "$TRAY_ID" '
      .bar.layout |= with_entries(.value |= (if type == "array" then map(select(.id != $id)) else . end))
      | (.bar.layout.right[]? | select(.id == "omarchy.tray") | .hidden) |= ((. // []) - [$tray])
    ' "$SHELL_JSON" > "$SHELL_JSON.tmp" && mv "$SHELL_JSON.tmp" "$SHELL_JSON"
  fi
  rm -rf "$PLUGIN_DIR"

  say "Removendo clone e venv ($BAPET_HOME)"
  rm -rf "$BAPET_HOME"

  echo
  echo "Desinstalado. Pets, settings e modelos baixados continuam em"
  echo "  $CONFIG_DIR/bluearchive-desktop-pet e $DATA_DIR/bluearchive-desktop-pet"
}

[ "${1:-}" = "--uninstall" ] && { uninstall; exit 0; }
[ $# -gt 0 ] && die "uso: ./install.sh [--uninstall]"

# --------------------------------------------------------------------------- checagens

command -v hyprctl >/dev/null || die "Hyprland não encontrado. Este instalador é para o Omarchy."
command -v omarchy >/dev/null || die "Comando 'omarchy' não encontrado. Este instalador é para o Omarchy."
[ -f "$HYPR_DIR/hyprland.lua" ] || die "$HYPR_DIR/hyprland.lua não existe (Omarchy com config Lua é necessário)."

# --------------------------------------------------------------------------- dependências

say "Conferindo pacotes do sistema"
# git/jq/libnotify: instalador e scripts. xcb-util-*/libxkbcommon-x11: Qt no XWayland.
# mesa: OpenGL 3.3 para o renderizador. libxcb: recorte de clique do app.
PKGS=(git jq libnotify mesa libxcb xcb-util-cursor xcb-util-wm xcb-util-keysyms
      xcb-util-image xcb-util-renderutil libxkbcommon-x11)
# uv pode vir de fora do pacman (mise, pipx...): só instala se não estiver no PATH.
command -v uv >/dev/null || PKGS+=(uv)
missing=()
for p in "${PKGS[@]}"; do pacman -Qq "$p" >/dev/null 2>&1 || missing+=("$p"); done
if [ ${#missing[@]} -gt 0 ]; then
  echo "   instalando: ${missing[*]}"
  omarchy pkg add "${missing[@]}"
fi
command -v uv >/dev/null || die "uv não ficou disponível no PATH."

# --------------------------------------------------------------------------- BApet

say "Baixando o BApet em $BAPET_HOME/src"
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
echo "   versão: $(git -C "$BAPET_HOME/src" describe --tags --always)"

say "Criando ambiente Python 3.12 e instalando dependências"
# 3.12 é a versão que o projeto usa nos builds; o uv baixa se o sistema não tiver.
[ -x "$BAPET_HOME/venv/bin/python" ] || uv venv --quiet --python 3.12 "$BAPET_HOME/venv"
VIRTUAL_ENV="$BAPET_HOME/venv" uv pip install --quiet -r "$BAPET_HOME/src/requirements.txt"

# --------------------------------------------------------------------------- arquivos

say "Instalando comandos em $BIN_DIR"
mkdir -p "$BIN_DIR"
install -m 755 "$HERE/bin/BlueArchiveDesktopPet" "$HERE/bin/bapet-ghost" "$HERE/bin/bapet-update" "$BIN_DIR/"
case ":$PATH:" in *":$BIN_DIR:"*) ;; *) warn "$BIN_DIR não está no PATH; o atalho SUPER+ALT+P depende dele." ;; esac

say "Instalando atalho no launcher"
mkdir -p "$DATA_DIR/applications" "$DATA_DIR/icons/hicolor/256x256/apps"
install -m 644 "$BAPET_HOME/src/bapet/assets/icon.png" "$DATA_DIR/icons/hicolor/256x256/apps/bluearchive-desktop-pet.png"
sed "s|@BIN_DIR@|$BIN_DIR|g" "$HERE/applications/bluearchive-desktop-pet.desktop" \
  > "$DATA_DIR/applications/bluearchive-desktop-pet.desktop"
command -v update-desktop-database >/dev/null && update-desktop-database "$DATA_DIR/applications" 2>/dev/null || true

say "Instalando regras do Hyprland"
install -m 644 "$HERE/hypr/bapet.lua" "$HYPR_DIR/bapet.lua"
if ! grep -qF "$REQUIRE_LINE" "$HYPR_DIR/hyprland.lua"; then
  backup "$HYPR_DIR/hyprland.lua"
  printf '\n-- BApet: regras das janelas dos pets.\n%s\n' "$REQUIRE_LINE" >> "$HYPR_DIR/hyprland.lua"
fi
hyprctl reload >/dev/null
sleep 1
errors="$(hyprctl configerrors | tr -d '[:space:]')"
[ -z "$errors" ] || warn "O Hyprland reportou erros de config: $(hyprctl configerrors)"

say "Instalando plugin da barra ($PLUGIN_ID)"
mkdir -p "$(dirname "$PLUGIN_DIR")"
rm -rf "$PLUGIN_DIR"
cp -r "$HERE/plugin/$PLUGIN_ID" "$PLUGIN_DIR"
omarchy-shell shell rescanPlugins >/dev/null 2>&1 || true
if [ -f "$SHELL_JSON" ] && jq -e --arg id "$PLUGIN_ID" '[.bar.layout[]? | arrays | .[] | .id] | index($id)' "$SHELL_JSON" >/dev/null; then
  echo "   já está na barra"
else
  omarchy bar put "$PLUGIN_ID" --section tray
fi
# Esconde o ícone cru do app na bandeja: o plugin já mostra ele e o menu.
if [ -f "$SHELL_JSON" ] && jq -e '.bar.layout.right[]? | select(.id == "omarchy.tray")' "$SHELL_JSON" >/dev/null; then
  if ! jq -e --arg tray "$TRAY_ID" '.bar.layout.right[] | select(.id == "omarchy.tray") | (.hidden // []) | index($tray)' "$SHELL_JSON" >/dev/null; then
    backup "$SHELL_JSON"
    jq --arg tray "$TRAY_ID" '(.bar.layout.right[] | select(.id == "omarchy.tray") | .hidden) |= ((. // []) + [$tray])' \
      "$SHELL_JSON" > "$SHELL_JSON.tmp" && mv "$SHELL_JSON.tmp" "$SHELL_JSON"
  fi
fi

echo
say "Pronto."
cat <<EOF
   Abrir:     launcher (Blue Archive Desktop Pet), ícone de pata na bandeja da barra,
              ou BlueArchiveDesktopPet --add "Hina"
   Arrastar:  SUPER+ALT+P alterna entre pets atravessáveis e interativos
   Atualizar: bapet-update (só o BApet) ou ./install.sh de novo (BApet + integração)
EOF
