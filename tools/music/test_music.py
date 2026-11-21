"""uv run --with numpy --with scipy --with soundfile python tools/music/test_music.py"""
import sys
import tempfile
from pathlib import Path

import numpy as np

sys.path.insert(0, str(Path(__file__).parent))
import midi  # noqa: E402
import score  # noqa: E402
import synth  # noqa: E402
import theory  # noqa: E402

ROOT = Path(__file__).resolve().parents[2]


def write(text):
    f = tempfile.NamedTemporaryFile("w", suffix=".song", delete=False)
    f.write(text)
    f.close()
    return f.name


BASE = """tempo 120
meter 4/4
grid 4
voice lead inst=pulse role=melody
voice bass inst=tri role=bass
section A
chords | C | G |
lead   | {lead} |
bass   | C2 . . . | G1 . . . |
"""

# a clash on a strong beat that never resolves is a rule error
s = score.parse(write(BASE.format(lead="E4 . F#4 . | D4 . . .")))
errors, _ = theory.check(s)
assert any("F#4 clashes with C" in e for e in errors), errors

# the same note marked as intended passes
s = score.parse(write(BASE.format(lead="E4 . F#4! . | D4 . . .")))
assert not theory.check(s)[0]

# a leaning note that steps into a chord tone passes
s = score.parse(write(BASE.format(lead="E4 . A4 G4 | D4 . . .")))
assert not theory.check(s)[0], theory.check(s)[0]

# holds and rests make the right lengths
s = score.parse(write(BASE.format(lead="E4 . - G4 | D4 . . .")))
assert [(n.step, n.length) for n in s.voices["lead"].notes] == [(0, 2), (3, 1), (4, 4)]

# a bar with the wrong number of steps names the line
try:
    score.parse(write(BASE.format(lead="E4 . G4 | D4 . . .")))
    raise AssertionError("short bar was accepted")
except score.SongError as e:
    assert "has 3 steps, needs 4" in str(e)

# a loop has no jump at the seam: the last sample leads into the first
x = synth.render(s)
assert x.shape[0] == 2 and np.isfinite(x).all()
step = np.abs(np.diff(x, axis=1)).max()
assert np.abs(x[:, 0] - x[:, -1]).max() <= step * 1.5 + 1e-3

# MIDI round trip keeps every melody note
out = Path(tempfile.mkdtemp()) / "t.mid"
midi.write(s, out)
back = midi.read_notes(out)
assert [n[2] for n in back["lead"]] == [64, 67, 62], back

# every sketch and every game song passes its rules
for p in list((ROOT / "docs/music/sketches").glob("*.song")) + list((ROOT / "assets/music/src").glob("*.song")):
    errors, _ = theory.check(score.parse(p))
    assert not errors, (p.name, errors)

print("music ok")
