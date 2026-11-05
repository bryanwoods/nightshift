#!/usr/bin/env python3
"""Check that compile_px names the file and line of each problem, and that frame copies work.
Run from the repo root:  uv run --with pillow python tools/test_compile_px.py
"""
import tempfile
from pathlib import Path

import compile_px as c

colors = c.palette()
with tempfile.TemporaryDirectory(dir=c.ROOT) as d:
    p = Path(d) / "bad.txt"
    p.write_text("# bad 3x2\n@a\nkkk\nkzk\n@b\nkk\nkkk\n")
    errors = []
    c.read(p, colors, errors)
    assert any(":4: letter 'z' is not in data/palette.json" in e for e in errors), errors
    assert any(":2: frame @a has 1 rows, it needs 2" in e for e in errors), errors
    assert any(":6: row is 2 wide, it needs 3" in e for e in errors), errors
    p.write_text("# good 2x2\n@a\nkk\n.k\n\n@b = flip a\n")
    errors = []
    name, size, frames = c.read(p, colors, errors)
    assert not errors and size == (2, 2) and [f for f, _ in frames] == ["a", "b"], errors
    assert frames[1][1].getpixel((0, 1))[3] == 255 and frames[1][1].getpixel((1, 1))[3] == 0
print("compile_px ok")
