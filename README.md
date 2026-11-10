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

Optional variables: `BAPET_REF=v1.0.0` pins a BApet version, `BAPET_REPO` points to a fork, and
`BAPET_HOME` changes the install folder.

## Usage

- **Open:** from the launcher, from the paw icon in the bar's tray drawer (left click), or with
  `BlueArchiveDesktopPet --add "Hina"`.
- **Menu:** right-click the paw in the bar. It shows the app's own menu (add, pause, hide, settings, quit)
  plus a **Drag pets** option.
- **`SUPER + ALT + P`:** switches between two modes:
  - **click-through** (default): clicks pass through the pet;
  - **interactive**: you can drag a pet, click it and open its menu.
- **Size:** right-click the pet and pick **Size** (in interactive mode), or use **Settings → Pet size** for
  all pets.
- **Update only BApet:** `bapet-update`, then restart the app.

## Local tweaks

The wrapper doesn't run `python -m bapet` directly. It goes through `overrides/bapet_omarchy.py`, which
adjusts BApet in memory before starting it. No file in the clone is changed, so `git pull` never conflicts.
If a new version changes something a tweak relies on, only that tweak is skipped (with a warning on stderr)
and the app still opens.

| Tweak | Upstream | Here |
| --- | --- | --- |
| Camera angle (Settings) | -10° to 45° | -180° to 180° (past ±90° the pet is upside down) |
| Outline width (Settings) | 0.5 to 6 px, 0.25 steps | 0.1 to 6 px, 0.1 steps |
| Window framing | only correct from 0° to 90°, clips the pet elsewhere | correct at any angle |

The limits are constants at the top of the file. The outline change was also proposed upstream in
[kagdakj/BApet#1](https://github.com/kagdakj/BApet/pull/1).

## Why each piece exists

- **The official binary isn't used:** the OpenBLAS bundled in the PyInstaller build is rejected by Arch's
  glibc (`ELF load command address/offset not page-aligned`). Running from source avoids this.
- **`QT_QPA_PLATFORM=xcb` in the wrapper:** the app needs XWayland to position its own windows. It switches
  on its own, but only when the variable is unset, and Omarchy exports `wayland;xcb`.
- **Click-through mode:** the app limits its clickable area with X11 SHAPE, but Hyprland ignores that. The
  whole pet window would catch clicks, including the transparent area around the pet. So pets get
  `no_focus` by default, and the `bapet-touch` tag (set by `bapet-ghost`) gives them the mouse back.
- **The plugin reads the app's tray:** the widget uses the StatusNotifierItem BApet already publishes, so new
  items in the app's menu show up on their own.

## Limitations

- A pet added while interactive mode is on starts out click-through. Press `SUPER+ALT+P` twice.
- Pets always stay above tiled windows, because Hyprland keeps floating windows on top. "Keep pets above
  other windows" doesn't change this.
- If `SUPER+ALT+P` is already taken, edit `hypr/bapet.lua`.
