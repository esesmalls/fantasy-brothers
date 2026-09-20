"""Package real Godot hand-comparison captures for the offline review page.

Copies source pixels byte-for-byte. It does not crop, redraw, or recompress art.
"""
from __future__ import annotations

import argparse
import hashlib
import shutil
from pathlib import Path


ROOT = Path(__file__).resolve().parents[1]
DEFAULT_SOURCE = ROOT / "builds" / "hand-style-review" / "export-final"
DEFAULT_DEST = ROOT / "art" / "validation" / "2026-09-20-hand-comparison" / "previews"
ACTIONS = ("slash", "shield_bash")


def sha256(path: Path) -> str:
    digest = hashlib.sha256()
    with path.open("rb") as handle:
        for block in iter(lambda: handle.read(1024 * 1024), b""):
            digest.update(block)
    return digest.hexdigest()


def png_size(path: Path) -> tuple[int, int] | None:
    data = path.read_bytes()[:24]
    if len(data) >= 24 and data[:8] == b"\x89PNG\r\n\x1a\n":
        return int.from_bytes(data[16:20], "big"), int.from_bytes(data[20:24], "big")
    return None


def collect(source: Path) -> tuple[list[Path], list[str]]:
    files: list[Path] = []
    missing: list[str] = []
    for action in ACTIONS:
        for index in range(16):
            name = f"strip-{action}-{index:02d}.png"
            candidate = source / name
            if candidate.is_file():
                files.append(candidate)
            else:
                missing.append(name)

    # Capture names can evolve; copy only review PNGs outside the two exact sequences.
    for candidate in sorted(source.glob("*.png")):
        if candidate not in files:
            files.append(candidate)

    # Runtime-exported, pre-recorded sound cues. Keep original names.
    for pattern in ("*.wav", "audio/*.wav", "sounds/*.wav"):
        for candidate in sorted(source.glob(pattern)):
            if candidate.is_file() and candidate not in files:
                files.append(candidate)
    return files, missing


def main() -> int:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--source", type=Path, default=DEFAULT_SOURCE)
    parser.add_argument("--dest", type=Path, default=DEFAULT_DEST)
    parser.add_argument("--allow-incomplete", action="store_true", help="package available files even if sequence frames are missing")
    args = parser.parse_args()
    source = args.source.resolve()
    dest = args.dest.resolve()
    if not source.is_dir():
        raise SystemExit(f"Capture directory does not exist: {source}")

    files, missing = collect(source)
    if missing and not args.allow_incomplete:
        sample = ", ".join(missing[:6])
        raise SystemExit(f"Missing {len(missing)} required sequence frames ({sample}). Use --allow-incomplete to package a partial export.")
    dest.mkdir(parents=True, exist_ok=True)

    rows: list[str] = ["file\tbytes\tdimensions\tsha256"]
    for src in files:
        target = dest / src.name
        shutil.copy2(src, target)
        dimensions = png_size(target)
        dims = f"{dimensions[0]}x{dimensions[1]}" if dimensions else "audio"
        rows.append(f"{target.name}\t{target.stat().st_size}\t{dims}\t{sha256(target)}")

    packaged_targets = [dest / src.name for src in files]
    for existing_audio in sorted(dest.glob("*.wav")):
        if existing_audio not in packaged_targets:
            packaged_targets.append(existing_audio)
            rows.append(
                f"{existing_audio.name}\t{existing_audio.stat().st_size}\taudio\t{sha256(existing_audio)}"
            )

    manifest = dest / "MANIFEST.tsv"
    manifest.write_text("\n".join(rows) + "\n", encoding="utf-8", newline="\n")
    print(f"Packaged {len(files)} captures to {dest}")
    print(f"Required sequence frames missing: {len(missing)}")
    print(f"Manifest: {manifest}")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
