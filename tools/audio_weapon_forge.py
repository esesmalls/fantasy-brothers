"""Cut short weapon cues from credited field recordings; no sound synthesis.

Run from the repository root after extracting the listed OpenGameArt 7z members.
The tiny Kenney OGG cues are copied without transcoding. See the production README.
"""

from pathlib import Path
import shutil

import numpy as np
from scipy.io import wavfile
from scipy.signal import resample_poly


ROOT = Path(__file__).resolve().parents[1]
PRODUCTION = ROOT / "art/production/audio-20260923"
RECORDINGS = PRODUCTION / "sources/recordings"
GAME = ROOT / "game/assets/audio/weapon"

# Input seconds refer to the unchanged original 192 kHz / 24-bit field recordings.
CUTS = {
    "blade_light_release": ("Dagger Swing.wav", 0.82, 1.27, 0.48),
    "blade_heavy_release": ("Axe Swing.wav", 1.39, 1.98, 0.55),
    "spear_release": ("Spear Swing.wav", 2.08, 2.61, 0.48),
    "bow_prepare": ("English Longbow Nock Arrow.wav", 0.58, 1.05, 0.36),
    "bow_draw": ("English Longbow Draw.wav", 2.62, 3.48, 0.32),
    "bow_release": ("English Longbow Shoot.wav", 1.03, 1.50, 0.48),
    "blade_light_recover": ("Dagger Draw Fast.wav", 0.36, 0.83, 0.29),
    "miss_result": ("Dagger Swing.wav", 2.41, 2.86, 0.26),
}

KENNEY = {
    "cloth_prepare": ("kenney-rpg", "cloth1.ogg"),
    "cloth_recover": ("kenney-rpg", "cloth2.ogg"),
    "blade_prepare": ("kenney-rpg", "drawKnife1.ogg"),
    "metal_recover": ("kenney-rpg", "metalClick.ogg"),
    "flesh_light": ("kenney-impact", "impactSoft_medium_000.ogg"),
    "flesh_heavy": ("kenney-impact", "impactSoft_heavy_000.ogg"),
    "armor_light": ("kenney-impact", "impactMetal_light_000.ogg"),
    "armor_heavy": ("kenney-impact", "impactMetal_heavy_000.ogg"),
    "shield_contact": ("kenney-impact", "impactWood_medium_000.ogg"),
}


def cut_wav(name: str, source: str, start: float, end: float, peak: float) -> None:
    rate, samples = wavfile.read(RECORDINGS / source)
    if samples.ndim != 1:
        raise ValueError(f"Expected mono source: {source}")
    if samples.dtype != np.int32:
        raise ValueError(f"Expected original 24-bit PCM in int32 container: {source}")
    segment = samples[round(start * rate) : round(end * rate)].astype(np.float64) / 2147483648.0
    if segment.size == 0:
        raise ValueError(f"Empty segment: {name}")
    segment = resample_poly(segment, 1, 4)  # 192 kHz to 48 kHz, preserving real timbre.
    segment -= np.mean(segment)
    max_abs = np.max(np.abs(segment))
    if max_abs == 0:
        raise ValueError(f"Silent segment: {name}")
    segment *= min(1.0, peak / max_abs)
    fade = min(round(0.008 * 48000), len(segment) // 6)
    segment[:fade] *= np.linspace(0, 1, fade)
    segment[-fade:] *= np.linspace(1, 0, fade)
    wavfile.write(GAME / f"{name}.wav", 48000, np.round(segment * 32767).astype(np.int16))


def main() -> None:
    GAME.mkdir(parents=True, exist_ok=True)
    for name, (source, start, end, peak) in CUTS.items():
        cut_wav(name, source, start, end, peak)
    for name, (package, source) in KENNEY.items():
        shutil.copyfile(PRODUCTION / "sources" / package / "Audio" / source, GAME / f"{name}.ogg")
    print(f"Exported {len(CUTS) + len(KENNEY)} real-recording cues to {GAME}")


if __name__ == "__main__":
    main()
