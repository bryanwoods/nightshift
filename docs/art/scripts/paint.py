"""Paint characters like the hand-painted Foreman.

Each flat color becomes a ramp. Big shapes are shaded as rounded forms lit from the
top left, with clean bands (no dither), a cool rim on the shadow side, and a cast
shadow under heads and hat brims. Small details (eyes, buttons, sparks) stay as drawn.
"""
import json
from PIL import Image

R = "/Users/bryan/workspace/nightshift/"
pal = json.load(open(R + "data/palette.json"))
P = {}
for g in ("night", "morning"):
    for v in pal[g].values():
        P[v["letter"]] = tuple(int(v["hex"][i:i+2], 16) for i in (1, 3, 5)) + (255,)

RAMP = {
    "d": "ndsf", "n": "nnds", "s": "dsf", "f": "sfm",
    "m": "BAm", "y": "oyyb", "o": "roy", "e": "DCel", "l": "Celb",
    "u": "fuu", "w": "vwi", "i": "wix", "v": "nvw", "q": "squ",
    "j": "njr", "r": "jro", "A": "BAm",
}
SKIN = set("mA")
FRONT = set("myoljeA")


def outside(g):
    h, w = len(g), len(g[0])
    e = [[False] * w for _ in range(h)]
    for y in range(h):
        for x in range(w):
            if g[y][x] == ".":
                e[y][x] = True
            elif g[y][x] == "k":
                for dx, dy in ((1, 0), (-1, 0), (0, 1), (0, -1)):
                    nx, ny = x + dx, y + dy
                    if not (0 <= nx < w and 0 <= ny < h) or g[ny][nx] == ".":
                        e[y][x] = True
    return e


def comps(g):
    h, w = len(g), len(g[0])
    seen = [[False] * w for _ in range(h)]
    out = []
    for sy in range(h):
        for sx in range(w):
            c = g[sy][sx]
            if seen[sy][sx] or c in ".k":
                continue
            st, cs = [(sx, sy)], []
            seen[sy][sx] = True
            while st:
                x, y = st.pop(); cs.append((x, y))
                for dx, dy in ((1, 0), (-1, 0), (0, 1), (0, -1)):
                    nx, ny = x + dx, y + dy
                    if 0 <= nx < w and 0 <= ny < h and not seen[ny][nx] and g[ny][nx] == c:
                        seen[ny][nx] = True; st.append((nx, ny))
            out.append((c, cs))
    return out


def paint(rows, skin=None, keep=()):
    skin = SKIN if skin is None else skin
    g = [list(r) for r in rows]
    h, w = len(g), len(g[0])
    ed = outside(g)
    out = [r[:] for r in g]
    for c, cs in comps(g):
        if c not in RAMP or c in keep or len(cs) < 10:
            continue
        ramp = RAMP[c] if c not in skin else "BAm"
        xs = [p[0] for p in cs]; ys = [p[1] for p in cs]
        x0, x1, y0, y1 = min(xs), max(xs), min(ys), max(ys)
        cw, chh = x1 - x0 + 1, y1 - y0 + 1
        cset = set(cs)
        for x, y in cs:
            u = (x - x0 + 0.5) / cw
            v = (y - y0 + 0.5) / chh
            if c in skin:
                I = 1.0 if u < 0.76 else (0.5 if (u < 0.93 or cw < 10) else 0.1)
                if cw <= 4: I = 1.0 if u < 0.7 else 0.5
            else:
                cyl = max(0.0, 1 - abs(u - 0.28) * 1.7)
                I = 0.6 * cyl + 0.32 * (1 - v) + 0.04
                if cw <= 3: I = 0.85 - 0.5 * v
            n = len(ramp)
            k = max(0, min(n - 1, int(I * n)))
            if c not in skin and n >= 3:
                base = ramp.index(c) if c in ramp else 1
                k = max(0, min(n - 1, k)) if cw > 3 else max(base - 1, min(base + 1, k))
            out[y][x] = ramp[k]
        if c not in skin and cw >= 6 and chh >= 6:
            for y in range(y0 + chh // 4, y1 + 1):
                row = [x for x in range(x0, x1 + 1) if (x, y) in cset]
                if row:
                    xr = max(row)
                    if xr + 1 >= w or ed[y][xr + 1]:
                        out[y][xr] = ramp[min(len(ramp) - 1, 1 + (ramp[0] == ramp[1]))]
    big = set()
    for c, cs in comps(g):
        if len(cs) >= 10: big.update(cs)
    for y in range(1, h):
        for x in range(w):
            c = g[y][x]; up = g[y - 1][x]
            if (x, y) not in big: continue
            if c in RAMP and c not in FRONT and up in FRONT and up != c and not ed[y - 1][x]:
                out[y][x] = RAMP[c][0]
            elif c in skin and up in "yoljeCD" and not ed[y - 1][x] and out[y][x] == "m":
                out[y][x] = "A"
    return ["".join(r) for r in out]


def carry(orig_base, painted_base, frame, painter):
    """Reuse painted rows of the front frame where a walking frame repeats them."""
    fresh = painter(frame)
    out, j = [], 0
    for i, r in enumerate(frame):
        hit = None
        for jj in range(j, len(orig_base)):
            if orig_base[jj] == r and r.strip("."):
                hit = jj; break
        if hit is not None:
            out.append(painted_base[hit]); j = hit + 1
        else:
            out.append(fresh[i])
    return out


def draw(rows):
    im = Image.new("RGBA", (len(rows[0]), len(rows)))
    p = im.load()
    for y, r in enumerate(rows):
        for x, c in enumerate(r):
            if c != ".":
                p[x, y] = P[c]
    return im


def read(name):
    lines = open(R + f"assets/px/sprites/{name}.txt").read().splitlines()
    fw, fh = map(int, lines[0].split()[-1].split("x"))
    fr = {}
    for i, l in enumerate(lines):
        if l.startswith("@") and "=" not in l:
            fr[l[1:].strip()] = lines[i + 1:i + 1 + fh]
    return lines, fr, (fw, fh)


def write(name, new, note):
    lines, fr, (fw, fh) = read(name)
    out, i = [], 0
    while i < len(lines):
        l = lines[i]
        key = l[1:].strip() if l.startswith("@") and "=" not in l else None
        if key in new:
            out.append(l); out += new[key]; i += 1 + fh; continue
        out.append(l); i += 1
    if len(out) > 1 and out[1].startswith("#"):
        out.insert(2, "# " + note) if not out[2].startswith("# Painted") else None
    open(R + f"assets/px/sprites/{name}.txt", "w").write("\n".join(out) + "\n")
