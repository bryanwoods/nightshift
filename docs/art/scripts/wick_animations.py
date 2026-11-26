"""Draw every Wick fight animation as text sprites in assets/px/sprites/wick_animations/.

Wick's town sprite at double size is the base. On top go the head flames, horns, the angry
face, the burning cloak and the staff fire, then each pose's extras. Every sheet has 4 frames.
Run from the repo root:  python3 docs/art/scripts/wick_animations.py
Then build the PNGs:     uv run --with pillow python tools/compile_px.py
"""
import math
from pathlib import Path

W, H, DX, DY = 44, 76, 6, 12
OUT = Path("assets/px/sprites/wick_animations")
town = open("assets/px/sprites/wick.txt").read().split("\n")

FLAME_A = [
 "........kk..........",
 ".......khhk.........",
 ".......khek......k..",
 "..k...kheek.....khk.",
 ".khk..khleek...khek.",
 ".khk.kheleek...khek.",
 "khek.khellek..kheek.",
 "khek.khelmlek.khlek.",
 "kheekhellmlek.khlek.",
 "khlehellmmlekkhelek.",
 ".khleelmmmmleehllek.",
 ".khlllmmmmmmllllek..",
 "..khlllmmmmlllleek..",
 "..kheellmmllleeehk..",
 ".khheeellllleeehhk..",
 ".khhheeeeeeeeehhhk..",
 "kkhhhhheeeehhhhhhkk.",
]
FLAME_B = [
 "...........kk.......",
 "..........khhk......",
 "....k.....kehk......",
 "...khk....keehk..k..",
 "...khk...keelhk.khk.",
 "..khek...keelehkkhk.",
 "..khek..keellehkhek.",
 ".kheek..kelmllehhek.",
 ".khlek.kellmlleehek.",
 ".khlehkelmmllleelek.",
 ".khlleeelmmmmleellk.",
 "..khllllmmmmmmlllk..",
 "..khellllmmmmllllk..",
 "..khheelllmmlleeek..",
 ".khhheeellllleeehk..",
 ".khhhheeeeeeeehhhk..",
 "kkhhhhhheeeehhhhhkk.",
]
# left horn, read top to bottom; the right horn is its mirror
HORN = [
 "kk......",
 "khk.....",
 "khhk....",
 "kChk....",
 "kChhk...",
 ".kChhk..",
 ".kCChhk.",
 "..kCChhk",
 "...kCChk",
 "....kCCk",
]
STAFF_A = [
 ".....k........",
 "..p.kqk....u..",
 "....kuqk......",
 ".k..kuuqk..k..",
 "kpk.kquxqkkpk.",
 "kpEkquxxqkpEk.",
 ".kpEqxxxqkpk..",
 "..kpqqxuqpk..q",
 "u.kEpquqpEk...",
 "...kEpqpEk....",
 "....kkkkk.....",
]
STAFF_B = [
 "..u.....k.....",
 "......kqk...p.",
 ".k...kquk.....",
 "kpk..kqqk..k..",
 "kpEkkquuqk.kpk",
 ".kpEquxuqkkpEk",
 "..kpqxxxqkpEk.",
 "p.kEqxxuqpEk..",
 "...kEqqqpEk..u",
 "...kEppqEk....",
 "....kkkkk.....",
]


def base(bob):
    i = town.index("@" + ("down_1" if bob else "down_0"))
    g = []
    for r in town[i + 1:i + 33]:
        row = "".join(c * 2 for c in r)
        g += [list(row), list(row)]
    for x, y in [(9, 19), (10, 19), (11, 20), (12, 20), (13, 21), (22, 19), (21, 19), (20, 20), (19, 20), (18, 21)]:
        g[y + bob][x] = "k"
    return ["".join(r) for r in g]


def put(g, x, y, c):
    if 0 <= x < W and 0 <= y < H and c != ".":
        g[y][x] = c


def frame(k, bob, flame=None, tall=0, eyes=("l", "e"), staff=None, phase=0.0, extra=None):
    """One frame. k picks the flicker, bob (0 or 2) is the breath, tall stretches the head fire."""
    src = base(bob)
    g = [["."] * W for _ in range(H)]
    top = 12 + DY + bob
    fl = flame or (FLAME_A if k % 2 == 0 else FLAME_B)
    if k >= 2:
        fl = [r[::-1] for r in fl]
    rows = []
    for i, r in enumerate(fl):
        rows += [r, r] if i < tall else [r]
    for i, row in enumerate(rows):
        for j, c in enumerate(row):
            put(g, 12 + j, top - len(rows) + 3 + i, c)
    for i, row in enumerate(HORN):
        for j, c in enumerate(row):
            put(g, 7 + j, top - 9 + i, c)
    for y in range(12, 64):
        for x, c in enumerate(src[y]):
            if c != "." and not (y < 15 and x >= 24):
                put(g, x + DX, y + DY, c)
    for y in range(22 + bob, 26 + bob):
        for x in range(10, 22):
            c = src[y][x]
            if c == "m":
                put(g, x + DX, y + DY, eyes[0])
            elif c == "k":
                put(g, x + DX, y + DY, eyes[1])
    for x in range(12, 20):
        put(g, x + DX, 27 + DY + bob, "k")
        put(g, x + DX, 28 + DY + bob, "m" if x % 2 else "k")
    put(g, 11 + DX, 26 + DY + bob, "k")
    put(g, 20 + DX, 26 + DY + bob, "k")
    t = phase
    for x in range(W):
        h = 17 + 5 * math.sin(x * 0.9 + t * 2.4) + 3 * math.sin(x * 2.3 - t * 1.7)
        for y in range(H - 1, H - 2 - int(h), -1):
            d = (H - 1 - y) / h
            if g[y][x] in "dsnf":
                g[y][x] = "l" if d < 0.3 else "e" if d < 0.65 else "h"
    sx = 24 + DX
    for y in range(12 + bob // 2, top + 3):
        for x, c in zip(range(sx + 1, sx + 5), "kddk"):
            put(g, x, y, c)
    sf = STAFF_A if k % 2 == 0 else STAFF_B
    if staff:
        sf = [r.translate(staff) for r in sf]
    for i, row in enumerate(sf):
        for j, c in enumerate(row):
            put(g, sx - 4 + j, 13 - len(sf) + i + bob // 2, c)
    for i, row in enumerate(HORN):
        for j, c in enumerate(row):
            put(g, 36 - j, top - 9 + i, c)
    if extra:
        extra(g, k, bob, top)
    return ["".join(r) for r in g]


ANIMATIONS = {
    "wick_battle": dict(note="Resting: breathing, head fire and staff fire flickering."),
}


def main():
    OUT.mkdir(exist_ok=True)
    for name, a in ANIMATIONS.items():
        opts = {k: v for k, v in a.items() if k != "note"}
        lines = [f"# {name} {W}x{H}", f"# {a['note']}", "# Drawn by docs/art/scripts/wick_animations.py.", "# rules: viewpoint, outline, characters", ""]
        for k in range(4):
            lines += [f"@idle_{k}"] + frame(k, 2 if k in (1, 2) else 0, phase=k * 0.8, **opts) + [""]
        (OUT / f"{name}.txt").write_text("\n".join(lines))
    print(f"wrote {len(ANIMATIONS)} Wick animations")


if __name__ == "__main__":
    main()
