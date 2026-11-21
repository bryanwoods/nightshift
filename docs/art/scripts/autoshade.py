"""Shade pixel-art letter grids the way the tree is shaded.

Light comes from the top left. A pixel just inside the outline on the top or left
gets one step lighter. A pixel just inside the outline on the bottom or right gets
one step darker, and the right side gets a second, softer step in its lower half.
Interior ink (eyes, seams) is not treated as an edge.
"""
import json
from PIL import Image

R = "/Users/bryan/workspace/nightshift/"
pal = json.load(open(R + "data/palette.json"))
L = {}
for g in ("night", "morning"):
    for v in pal[g].values():
        L[v["letter"]] = tuple(int(v["hex"][i:i+2], 16) for i in (1, 3, 5)) + (255,)

LIGHT = {"l": "b", "e": "l", "f": "m", "d": "s", "s": "f", "n": "d", "y": "m", "o": "y", "u": "x", "w": "i",
         "i": "x", "v": "w", "q": "u", "j": "r", "r": "o", "m": "t", "a": "t", "g": "c"}
DARK = {"l": "o", "e": "r", "f": "s", "d": "n", "s": "d", "n": "k", "y": "o", "o": "r", "u": "f", "w": "v",
        "i": "w", "v": "n", "q": "f", "j": "k", "r": "j", "m": "f", "a": "s", "g": "v"}
SKIN_DARK = None
skip_cast = ("l", "e", "h", "p", "b", "c", "t")


def outside_mask(g):
    h, w = len(g), len(g[0])
    out = [[False] * w for _ in range(h)]
    for y in range(h):
        for x in range(w):
            if g[y][x] == ".":
                out[y][x] = True
    edge = [[False] * w for _ in range(h)]
    for y in range(h):
        for x in range(w):
            if out[y][x]:
                edge[y][x] = True
            elif g[y][x] == "k":
                for dx, dy in ((1, 0), (-1, 0), (0, 1), (0, -1)):
                    nx, ny = x + dx, y + dy
                    if not (0 <= nx < w and 0 <= ny < h) or out[ny][nx]:
                        edge[y][x] = True
    return edge


def shade(g, skin=("m",), skip=("k", ".", "h", "p", "b", "c", "t", "m")):
    g = [list(r) for r in g]
    h, w = len(g), len(g[0])
    edge = outside_mask(g)
    def E(x, y):
        return not (0 <= x < w and 0 <= y < h) or edge[y][x]
    ys = [y for y in range(h) if any(c != "." for c in g[y])]
    top, bot = (min(ys), max(ys)) if ys else (0, h)
    out = [r[:] for r in g]
    count = {}
    for r in g:
        for ch in r: count[ch] = count.get(ch, 0) + 1
    xs = [x for x in range(w) if any(g[y][x] != "." for y in range(h))]
    left, right = (min(xs), max(xs)) if xs else (0, w)
    for y in range(h):
        for x in range(w):
            c = g[y][x]
            if c in skip or edge[y][x] or count.get(c, 0) < 10:
                continue
            dark = DARK.get(c)
            if c in skin:
                dark = SKIN_DARK
            lit = E(x, y - 1) or (E(x - 1, y) and c != "y")
            shd = E(x + 1, y) or E(x, y + 1)
            up = g[y - 1][x] if y > 0 else "."
            under = up in ("m", "y", "j", "o") and c in "dsnfuqwiva" and not edge[y - 1][x]
            if shd and dark:
                out[y][x] = dark
            elif under and dark:
                out[y][x] = dark
            elif lit and c in LIGHT and not (c in skin) and not E(x, y - 1) or (lit and E(x, y - 1) and c in LIGHT and (x - left) < (right - left) * 0.6 and c not in skin):
                out[y][x] = LIGHT[c]
    seen = [[False] * w for _ in range(h)]
    for sy in range(h):
        for sx in range(w):
            c = g[sy][sx]
            if seen[sy][sx] or c in skip or edge[sy][sx] or c not in LIGHT or c in skin:
                continue
            comp, st = [], [(sx, sy)]; seen[sy][sx] = True
            while st:
                x, y = st.pop(); comp.append((x, y))
                for dx, dy in ((1, 0), (-1, 0), (0, 1), (0, -1)):
                    nx, ny = x + dx, y + dy
                    if 0 <= nx < w and 0 <= ny < h and not seen[ny][nx] and g[ny][nx] == c:
                        seen[ny][nx] = True; st.append((nx, ny))
            if len(comp) < 30:
                continue
            x0 = min(p[0] for p in comp); x1 = max(p[0] for p in comp)
            y0 = min(p[1] for p in comp); y1 = max(p[1] for p in comp)
            cs = set(comp)
            for x, y in comp:
                if out[y][x] != c:
                    continue
                fx, fy = (x - x0) / max(1, x1 - x0), (y - y0) / max(1, y1 - y0)
                if fx + fy < 0.38 and (x + 2 * y) % 3 != 0 and (x - 1, y) in cs and (x, y - 1) in cs:
                    out[y][x] = LIGHT[c]
                elif x1 - x0 >= 6 and fy > 0.35 and E(x + 2, y) and (x + 1, y) in cs and DARK.get(c):
                    out[y][x] = DARK[c]
    return ["".join(r) for r in out]


def draw(rows):
    im = Image.new("RGBA", (len(rows[0]), len(rows)))
    p = im.load()
    for y, r in enumerate(rows):
        for x, c in enumerate(r):
            if c != ".":
                p[x, y] = L[c]
    return im


def frames(name):
    lines = open(R + f"assets/px/sprites/{name}.txt").read().splitlines()
    hdr = lines[0].split()[-1]
    fw, fh = map(int, hdr.split("x"))
    out = {}
    for i, l in enumerate(lines):
        if l.startswith("@") and "=" not in l:
            out[l[1:].strip()] = lines[i + 1:i + 1 + fh]
    return out, (fw, fh)
