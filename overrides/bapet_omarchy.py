"""Lançador do BApet com ajustes locais aplicados em memória.

Nenhum arquivo do clone do BApet é alterado, então `git pull` continua limpo.
Cada ajuste é independente: se uma versão nova do BApet mudar o ponto que ele
toca, o ajuste é pulado com um aviso no log e o app abre normalmente.

Ajustes:
- Ângulo da câmera: -180° a 180° (o original vai de -10° a 45°). Passando de ±90° o pet fica de cabeça para baixo.
- Espessura do contorno: a partir de 0.1 px, em passos de 0.1 (o original começa em 0.5).
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
    """Settings.sanitize() limita pitch e contorno; reaplica com os limites novos."""
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
    """Frame.fit() só acerta a altura da janela com ângulo entre 0° e 90°; fora
    disso corta o pet. Dentro dessa faixa usa o código original. Fora dela,
    enquadra pelos extremos reais da projeção: o modelo ocupa as alturas
    min(y_min, 0)..y_max e as profundidades -radius..radius, e a câmera leva
    (y, z) para y*cos + z*sin na tela."""
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
        # Largura e âncora horizontal não dependem do ângulo: vêm de um fit
        # dentro da faixa, e só a altura e a âncora vertical são trocadas.
        frame = original(radius, y_min, y_max, ppu, 0.0, margin)
        height = max(int(math.ceil((top - bottom) * ppu)) + 2 * margin, 8)
        return dataclasses.replace(frame, height=height, anchor_y=margin + top * ppu, pitch=pitch)

    Frame.fit = staticmethod(fit)


def _patch_settings_dialog() -> None:
    """Os campos da tela de Settings travam os valores; abre os limites e recoloca
    o valor salvo, que o campo já tinha cortado ao ser criado."""
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
    for patch in (_patch_sanitize, _patch_frame, _patch_settings_dialog):
        try:
            patch()
        except Exception as exc:  # noqa: BLE001 - um ajuste quebrado não pode impedir o app de abrir
            log.warning("ajuste %s não aplicado (BApet mudou?): %s", patch.__name__, exc)


def main() -> int:
    apply()
    from bapet.app import main as bapet_main

    return bapet_main()


if __name__ == "__main__":
    sys.exit(main())
