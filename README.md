# bapet-omarchy

Integrates [BApet (Blue Archive Desktop Pet)](https://github.com/kagdakj/BApet) with
[Omarchy](https://omarchy.org/) / Hyprland, without modifying BApet's code.

```sh
git clone https://github.com/Robertovbj/bapet-omarchy && cd bapet-omarchy
./install.sh
```

To update everything later, run `./update.sh`. It pulls this repo, runs `install.sh` (which also updates
BApet) and restarts the app if it is open. Running `./install.sh` again also works, just without the pull
and the restart. `./install.sh --uninstall` removes everything but keeps your pets, settings and downloaded
models.

## What the installer does

| Step | Destination |
| --- | --- |
| Installs missing packages (`git jq libnotify mesa xcb-util-* libxkbcommon-x11`, plus `uv` if it is not on the PATH) | via `omarchy pkg add` |
| Clones BApet, unmodified | `~/.local/share/bapet/src` |
| Creates a Python 3.12 venv and installs `requirements.txt` | `~/.local/share/bapet/venv` |
| Local tweaks applied in memory (see below) | `~/.local/share/bapet/overrides` |
| `BlueArchiveDesktopPet`, `bapet-ghost` and `bapet-update` commands | `~/.local/bin/` |
| Launcher entry and icon | `~/.local/share/applications/`, `~/.local/share/icons/` |
| Window rules and keybinding | `~/.config/hypr/bapet.lua` + `require("hypr.bapet")` in `hyprland.lua` |
| Bar plugin (in the tray drawer), hiding the app's raw tray icon | `~/.config/omarchy/plugins/bapet.desktop-pets/`, `shell.json` |

Before editing `hyprland.lua` or `shell.json`, the installer saves a `.bak.<timestamp>` copy.

You can pin a BApet version, use a fork or change the install folder:

```sh
BAPET_REF=v1.0.0 BAPET_REPO=https://github.com/you/BApet BAPET_HOME=~/apps/bapet ./install.sh
```

## Usage

Open it from the launcher, from the paw icon in the bar's tray drawer, or with
`BlueArchiveDesktopPet --add "Hina"`. Left-clicking the paw starts the app, or opens Add Pet if it's
already running. Right-clicking it shows the app's own menu (add, pause, hide, settings, quit) plus
*Drag pets*.

Pets start out click-through: clicks land on whatever is under them. Press `SUPER + ALT + P` (or pick
*Drag pets*) to make them interactive so you can drag them, click them and open their menu. Press it
again to go back.

To resize one pet, right-click it in interactive mode and pick *Size*. *Settings → Pet size* changes
all of them.

`bapet-update` updates only BApet. Restart the app afterwards.

## Local tweaks

The wrapper starts BApet through `overrides/bapet_omarchy.py`, which patches a few functions in memory
first. The clone itself is never edited, so `git pull` never conflicts. If an update changes one of the
patched functions, that tweak is skipped with a warning and the app still opens.

| Tweak | Upstream | Here |
| --- | --- | --- |
| Camera angle (Settings) | -10° to 45° | -180° to 180° (past ±90° the pet is upside down) |
| Outline width (Settings) | 0.5 to 6 px, 0.25 steps | 0.1 to 6 px, 0.1 steps |
| Window framing | only correct from 0° to 90°, clips the pet elsewhere | correct at any angle |

The limits are constants at the top of the file. The outline change was also proposed upstream in
[kagdakj/BApet#1](https://github.com/kagdakj/BApet/pull/1).

## Why each piece exists

The release binary doesn't start on Arch. The OpenBLAS bundled in the PyInstaller build is rejected by
the newer glibc (`ELF load command address/offset not page-aligned`), so this runs BApet from source.

The wrapper sets `QT_QPA_PLATFORM=xcb` because the app needs XWayland to place its own windows. BApet
switches to it by itself only when the variable is unset, and Omarchy exports `wayland;xcb`.

Click-through is a workaround. BApet limits its clickable area with X11 SHAPE, but Hyprland ignores it,
so the whole pet window would catch clicks, transparent corners included. The rules give pets `no_focus`
by default, and `bapet-ghost` adds a `bapet-touch` tag that hands them the mouse back.

The bar plugin talks to BApet only through the tray item (StatusNotifierItem) the app already publishes.
It draws that menu itself, so new menu items in BApet show up without changes here.

## Limitations

- A pet added while interactive mode is on starts out click-through. Press `SUPER+ALT+P` twice.
- Pets always stay above tiled windows, because Hyprland keeps floating windows on top. "Keep pets above
  other windows" doesn't change this.
- If `SUPER+ALT+P` is already taken, edit `hypr/bapet.lua`.
