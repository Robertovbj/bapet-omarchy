"""BApet launcher that applies local tweaks in memory.

No file in the BApet clone is changed, so `git pull` stays clean. Each tweak
stands alone: if a new BApet version changes something a tweak relies on, that
tweak is skipped with a warning and the app still opens.

Tweaks:
- Camera angle: -180° to 180° (upstream allows -10° to 45°). Past ±90° the pet is
  upside down, and it stands on its head instead of disappearing below the screen.
- Outline width: down to 0.1 px, in 0.1 steps (upstream stops at 0.5).
"""

from __future__ import annotations

import dataclasses
import functools
import logging
import math
import sys

PITCH_MIN, PITCH_MAX = -180.0, 180.0
OUTLINE_MIN, OUTLINE_MAX, OUTLINE_STEP = 0.1, 6.0, 0.1

log = logging.getLogger("bapet_omarchy")


def _clamp(value: float, lo: float, hi: float) -> float:
    return min(max(float(value), lo), hi)


def _patch_sanitize() -> None:
    """Settings.sanitize() clamps the angle and outline; clamp them again with the new limits."""
    from bapet.config import Settings

    original = Settings.sanitize

    @functools.wraps(original)
    def sanitize(self) -> None:
        pitch, outline = self.pitch_deg, self.outline_width
        original(self)
        self.pitch_deg = _clamp(pitch, PITCH_MIN, PITCH_MAX)
        self.outline_width = _clamp(outline, 0.0, OUTLINE_MAX)

    Settings.sanitize = sanitize


def _patch_frame() -> None:
    """Frame.fit() assumes the angle is between 0° and 90°. Outside that range the
    window comes out the wrong height and clips the pet. Inside it, keep upstream's
    code. Outside it, frame the model by the real extremes of its projection: the
    model spans heights min(y_min, 0)..y_max and depths -radius..radius, and the
    camera maps (y, z) to y*cos + z*sin on screen."""
    from bapet.renderer import Frame

    original = Frame.fit

    @functools.wraps(original)
    def fit(radius, y_min, y_max, ppu, pitch, margin):
        if 0.0 <= pitch <= math.pi / 2:
            return original(radius, y_min, y_max, ppu, pitch, margin)
        c, s = math.cos(pitch), math.sin(pitch)
        heights = (y_max * c, min(y_min, 0.0) * c)
        top = max(heights) + radius * abs(s)
        bottom = min(heights) - radius * abs(s)
        # Width and horizontal anchor don't depend on the angle: take them from an
        # in-range fit and replace only the height and vertical anchor.
        frame = original(radius, y_min, y_max, ppu, 0.0, margin)
        height = max(int(math.ceil((top - bottom) * ppu)) + 2 * margin, 8)
        return dataclasses.replace(frame, height=height, anchor_y=margin + top * ppu, pitch=pitch)

    Frame.fit = staticmethod(fit)


def _upside_down(settings) -> bool:
    return math.cos(math.radians(settings.pitch_deg)) < 0


def _patch_upside_down_bounds() -> None:
    """Pet._bounds_for_anchor() keeps the pet's feet (the anchor) on screen and
    assumes the body is above them; in walk mode the feet go on the bottom edge.
    Upside down the body hangs below the feet, so it would be drawn under the
    screen. Raise the ground by the part of the window below the anchor, so the
    pet stands on its head. Pets already below the new ground snap back up."""
    from PySide6.QtCore import QPointF

    from bapet.pet import Pet

    original_bounds = Pet._bounds_for_anchor
    original_tick = Pet.tick

    @functools.wraps(original_bounds)
    def _bounds_for_anchor(self):
        x0, x1, y0, y1 = original_bounds(self)
        f = self._frame
        if f is None or not _upside_down(self.controller.settings):
            return x0, x1, y0, y1
        area = self._screen_rect()
        bottom = float(area.bottom()) - (f.height - f.anchor_y)
        return x0, x1, min(area.top() + f.anchor_y, bottom), bottom

    @functools.wraps(original_tick)
    def tick(self, dt):
        if (self.lm is not None and self._frame is not None and self.mode in ("idle", "walk")
                and _upside_down(self.controller.settings)):
            ground = self._bounds_for_anchor()[3]
            if self.anchor.y() > ground + 1:
                self.anchor = QPointF(self.anchor.x(), ground)
                if self.mode == "walk":
                    self.target = QPointF(self.target.x(), min(self.target.y(), ground))
        return original_tick(self, dt)

    Pet._bounds_for_anchor = _bounds_for_anchor
    Pet.tick = tick


def _patch_settings_dialog() -> None:
    """The Settings fields enforce the old limits. Widen them and set the saved
    value again, since the field already clamped it when it was created."""
    from bapet.dialogs import SettingsDialog

    original = SettingsDialog.__init__

    @functools.wraps(original)
    def __init__(self, controller, *args, **kwargs) -> None:
        original(self, controller, *args, **kwargs)
        s = controller.settings
        self.pitch.setRange(int(PITCH_MIN), int(PITCH_MAX))
        self.pitch.setWrapping(True)
        self.pitch.setValue(int(round(s.pitch_deg)))
        self.outline_width.setDecimals(2)
        self.outline_width.setRange(OUTLINE_MIN, OUTLINE_MAX)
        self.outline_width.setSingleStep(OUTLINE_STEP)
        self.outline_width.setValue(s.outline_width)

    SettingsDialog.__init__ = __init__


def apply() -> None:
    for patch in (_patch_sanitize, _patch_frame, _patch_upside_down_bounds, _patch_settings_dialog):
        try:
            patch()
        except Exception as exc:  # noqa: BLE001 - a broken tweak must not keep the app from opening
            log.warning("skipped tweak %s (did BApet change?): %s", patch.__name__, exc)


def main() -> int:
    apply()
    from bapet.app import main as bapet_main

    return bapet_main()


if __name__ == "__main__":
    sys.exit(main())
