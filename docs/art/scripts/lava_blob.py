"""Draws the Lava Blob: its fight sheet, its town sheet and its two projectiles.
Run from the repo root: python3 docs/art/scripts/lava_blob.py"""
import math
from pathlib import Path

SP = Path("assets/px/sprites")


def blob(w, h, cx, base, rx, ry, squish, eye, scale):
    g = [["." for _ in range(w)] for _ in range(h)]
    rx = rx * (1 + squish * 0.08)
    ry = ry * (1 - squish * 0.08)
    top = base - ry
    hx, hy = cx - rx * 0.5, top + ry * 0.16
    for y in range(h):
        for x in range(w):
            fy = (base - y - 0.5) / ry
            if fy < 0 or fy > 1:
                continue
            spread = rx * math.sqrt(max(0.0, 1 - fy ** 2.2))
            if fy < 0.18:
                spread += (0.18 - fy) * rx * 1.6 * (1 + 0.25 * math.sin(x * 1.7 + squish * 3))
            if abs(x + 0.5 - cx) > spread:
                continue
            d = math.hypot((x + 0.5 - hx) / rx, (y + 0.5 - hy) / ry)
            c = "m" if d < 0.1 else "y" if d < 0.2 else "l" if d < 0.5 else "e" if d < 0.95 else "C"
            if fy < 0.1:
                c = "D" if c in "Ce" else "C"
            g[y][x] = c
    for k, (fx, length) in enumerate(((-0.55, 0.35), (-0.15, 0.22), (0.3, 0.3), (0.62, 0.2))):
        x = int(cx + fx * rx)
        y0 = None
        for y in range(h):
            if g[y][x] != ".":
                y0 = y
                break
        if y0 is None:
            continue
        for y in range(y0 + 1, min(h - 1, y0 + 1 + int(length * ry * (1 + squish * 0.3)))):
            g[y][x] = "l" if fx < 0 else "e"
    edge = [[False] * w for _ in range(h)]
    for y in range(h):
        for x in range(w):
            if g[y][x] != ".":
                for dx, dy in ((1, 0), (-1, 0), (0, 1), (0, -1)):
                    nx, ny = x + dx, y + dy
                    if not (0 <= nx < w and 0 <= ny < h) or g[ny][nx] == ".":
                        edge[y][x] = True
    for y in range(h):
        for x in range(w):
            if edge[y][x]:
                g[y][x] = "k"
    ey = int(base - ry * 0.62)
    if scale == 1:
        for sx in (-1, 1):
            ex = int(cx + sx * 2.5)
            g[ey][ex] = "k"
            g[ey + 1][ex] = "k"
        g[ey + 3][int(cx) - 1] = "k"
        g[ey + 3][int(cx)] = "k"
        g[ey + 2][int(cx) - 3] = "F"
        g[ey + 2][int(cx) + 3] = "F"
        return g
    for sx in (-1, 1):
        ex = int(cx + sx * rx * 0.33) - eye[0] // 2
        for dy in range(eye[1]):
            for dx in range(eye[0]):
                g[ey + dy][ex + dx] = "m"
        for dy in (2, 3):
            for dx in (1, 2):
                g[ey + dy][ex + dx] = "k"
        g[ey + 2][ex + 1] = "m"
    my = ey + eye[1] + 2
    for dx in range(-3, 4):
        g[my + (1 if abs(dx) < 3 else 0)][int(cx) + dx] = "k"
    g[my + 2][int(cx)] = "h"
    g[my + 2][int(cx) - 1] = "h"
    for sx in (-1, 1):
        g[my][int(cx + sx * 6)] = "F"
        g[my][int(cx + sx * 6) + (1 if sx > 0 else -1)] = "F"
    return g


def bubbles(g, pts):
    for (x, y, r) in pts:
        for yy in range(y - r, y + r + 1):
            for xx in range(x - r, x + r + 1):
                d = math.hypot(xx - x, yy - y)
                if 0 <= yy < len(g) and 0 <= xx < len(g[0]) and d <= r + 0.3:
                    g[yy][xx] = "k" if d > r - 0.7 else ("l" if xx < x else "e")


def rows(g):
    return ["".join(r) for r in g]


def frame(name, g):
    return f"@{name}\n" + "\n".join(rows(g)) + "\n"


big = []
for i, (sq, bub) in enumerate(((0.0, [(9, 27, 2), (21, 22, 1)]), (1.0, [(10, 23, 2), (22, 17, 1)]))):
    g = blob(32, 64, 16, 63, 14, 30, sq, (4, 5), 2)
    bubbles(g, bub)
    big.append(frame(f"idle_{i}", g))
(SP / "lava_blob_battle.txt").write_text(
    "# lava_blob_battle 32x64\n# A gooey blob of lava. Glowing on top, cooling dark at the bottom, bubbles popping off its head.\n"
    "# rules: viewpoint, outline, characters\n\n" + "\n".join(big))

small = []
for i, sq in enumerate((0.0, 1.0)):
    g = blob(16, 32, 8, 31, 7, 14, sq, (2, 2), 1)
    bubbles(g, [(4 + i, 15 - i * 2, 1)])
    small.append(frame(f"down_{i}", g))
alias = "@down_2 = down_0\n@down_3 = down_1\n" + "".join(f"@{d}_{k} = down_{k % 2}\n" for d in ("up", "left", "right") for k in range(4))
(SP / "lava_blob.txt").write_text(
    "# lava_blob 16x32\n# The town sheet: lava_blob_battle at half size.\n# rules: viewpoint, outline, characters\n\n" + "\n".join(small) + alias)

(SP / "lava_drop.txt").write_text("""# lava_drop 8x8
# A drip of lava from the Lava Blob. It falls and glows.

@sprite
...kk...
...kek..
..kelk..
..kylek.
.keyleCk
.kelleCk
..kCCCk.
...kk...
""")
(SP / "lava_bubble.txt").write_text("""# lava_bubble 8x8
# A hot bubble the Lava Blob blows. It wanders toward you and pops.

@sprite
..kkkk..
.kyleek.
kylleeCk
kleeeeCk
keeeeeCk
kCeeeCCk
.kCCCCk.
..kkkk..
""")
