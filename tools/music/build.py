#!/usr/bin/env python3
"""Check and build the game's music from text scores.

    uv run --with numpy --with scipy --with soundfile python tools/music/build.py            # every game song
    uv run ... tools/music/build.py check                                                   # rules only
    uv run ... tools/music/build.py preview docs/music/sketches/theme_a.song                # listening copy (.m4a)

Game songs live in assets/music/src/<name>.song and build to assets/music/<name>.ogg as
seamless loops. A preview plays the loop twice with a fade, and writes a .mid beside it
for GarageBand.
"""
import subprocess
import sys
from pathlib import Path

import numpy as np
import soundfile as sf

sys.path.insert(0, str(Path(__file__).parent))
import midi  # noqa: E402
import score  # noqa: E402
import synth  # noqa: E402
import theory  # noqa: E402

ROOT = Path(__file__).resolve().parents[2]
SRC = ROOT / "assets/music/src"
OUT = ROOT / "assets/music"


def load_checked(path):
    song = score.parse(path)
    errors, hints = theory.check(song)
    for h in hints:
        print(f"  hint: {h}")
    for e in errors:
        print(f"  RULE: {e}")
    return song, errors


def write_ogg(path, x):
    """libsndfile's Vorbis encoder crashes on one big write, so feed it small blocks."""
    data = np.ascontiguousarray(x.T, dtype=np.float32)
    with sf.SoundFile(str(path), "w", synth.SR, 2, format="OGG", subtype="VORBIS") as f:
        for i in range(0, len(data), 4096):
            f.write(data[i:i + 4096])


def write_m4a(path, x):
    """A listening copy that opens with a double-click on a Mac."""
    wav = path.with_suffix(".wav")
    sf.write(str(wav), np.ascontiguousarray(x.T, dtype=np.float32), synth.SR, subtype="PCM_16")
    subprocess.run(["ffmpeg", "-y", "-loglevel", "error", "-i", str(wav), "-c:a", "aac", "-b:a", "192k", str(path)], check=True)
    wav.unlink()


def main(argv):
    cmd = argv[0] if argv else "build"
    if cmd == "preview":
        bad = False
        for p in argv[1:]:
            p = Path(p)
            print(p.name)
            song, errors = load_checked(p)
            bad |= bool(errors)
            x = synth.fade_tail(synth.render(song, loops=2))
            write_m4a(p.with_suffix(".m4a"), x)
            midi.write(song, p.with_suffix(".mid"))
        return 1 if bad else 0
    songs = sorted(SRC.glob("*.song"))
    if len(argv) > 1:
        songs = [s for s in songs if s.stem in argv[1:]]
    bad = False
    for p in songs:
        print(p.name)
        song, errors = load_checked(p)
        bad |= bool(errors)
        if cmd == "build" and not errors:
            write_ogg(OUT / f"{p.stem}.ogg", synth.render(song))
            midi.write(song, p.with_suffix(".mid"))
    print("music ok" if not bad else "music has rule errors")
    return 1 if bad else 0


if __name__ == "__main__":
    sys.exit(main(sys.argv[1:]))
