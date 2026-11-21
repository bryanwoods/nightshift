import json, random, sys
from PIL import Image, ImageDraw
R = "/Users/bryan/workspace/nightshift/"
A = "/private/tmp/claude-501/-Users-bryan-workspace-nightshift/4d7bec5d-bb8e-428c-ab10-4e6fc01d4442/scratchpad/art/"
pal = json.load(open(R + "data/palette.json"))
P = {}
for g in ("night", "morning"):
    for v in pal[g].values():
        P[v["letter"]] = tuple(int(v["hex"][i:i+2], 16) for i in (1, 3, 5)) + (255,)
TS = json.load(open(R + "data/tilesets.json"))["tilesets"]
TDIR = R + "assets/px/tiles/town_night/"

def read_tile(name, d=TDIR):
    L = open(d + name + ".txt").read().splitlines()
    i = L.index("@tile")
    return L, [list(r) for r in L[i + 1:i + 17]]

def lum(c):
    r, g, b, _ = P[c]; return 0.3 * r + 0.59 * g + 0.11 * b

UP = {"k": "n", "n": "d", "d": "s", "s": "f", "o": "y", "r": "o", "j": "r", "y": "b",
      "v": "w", "w": "i", "e": "l", "l": "b", "C": "e", "D": "C", "u": "x", "q": "u", "h": "h"}
DN = {"n": "k", "d": "n", "s": "d", "f": "s", "m": "f", "o": "r", "r": "j", "y": "o", "j": "k",
      "w": "v", "v": "n", "e": "C", "l": "e", "u": "f", "q": "s", "C": "D", "i": "w"}

def H(x, y, s=0):
    return ((x * 73856093) ^ (y * 19349663) ^ (s * 83492791)) % 1000 / 1000

def bevel(g, wrap=False, flecks=True, seed=1):
    out = [r[:] for r in g]
    def at(x, y):
        if wrap: return g[y % 16][x % 16]
        if 0 <= x < 16 and 0 <= y < 16: return g[y][x]
        return None
    for y in range(16):
        for x in range(16):
            c = g[y][x]
            if c in "k.mlbtxch":
                continue
            u, l, dn, rt = at(x, y - 1), at(x - 1, y), at(x, y + 1), at(x + 1, y)
            darker = lambda n: n is not None and n != c and n in P and lum(n) < lum(c)
            if (darker(u) or darker(l)) and c in UP:
                out[y][x] = UP[c]
            elif (darker(dn) or darker(rt)) and c in DN:
                out[y][x] = DN[c]
    if flecks:
        for y in range(16):
            for x in range(16):
                c = g[y][x]
                if out[y][x] != c or c in "k.mlbtxch":
                    continue
                nb = [at(x + dx, y + dy) for dx in (-1, 0, 1) for dy in (-1, 0, 1)]
                if not all(n == c for n in nb):
                    continue
                h = H(x, y, seed)
                if h < 0.035 and c in UP: out[y][x] = UP[c]
                elif h > 0.955 and c in DN: out[y][x] = DN[c]
    return out

def canvas(c): return [[c] * 16 for _ in range(16)]
def rect(g, x0, y0, x1, y1, c):
    for y in range(y0, y1 + 1):
        for x in range(x0, x1 + 1): g[y % 16][x % 16] = c

T = {}
rnd = random.Random(11)

# sidewalk: big slabs, lit top-left lip, grout shadow, worn speckle, one hairline crack
g = canvas("s")
rect(g, 0, 15, 15, 15, "d"); rect(g, 15, 0, 15, 15, "d")
rect(g, 0, 0, 14, 0, "f"); rect(g, 0, 0, 0, 14, "f")
for x, y in [(4, 4), (9, 3), (12, 9), (3, 11), (7, 13), (11, 6)]: g[y][x] = "d"
for x, y in [(6, 7), (2, 6), (13, 12)]: g[y][x] = "f"
for x, y in [(9, 9), (10, 10), (10, 11), (11, 12)]: g[y][x] = "d"
g[14][14] = "n"; g[15][15] = "n"
T["sidewalk"] = g

# road: asphalt with clustered grit, light flecks on top of stones, dark pits under them
g = canvas("d")
for _ in range(14):
    x, y = rnd.randrange(16), rnd.randrange(16)
    g[y][x] = "s"; g[(y + 1) % 16][x] = "n"
for _ in range(10):
    x, y = rnd.randrange(16), rnd.randrange(16)
    if g[y][x] == "d": g[y][x] = "n"
T["road"] = g

# road_line: the painted dash, worn, lit on top, on top of the road texture
g = [r[:] for r in T["road"]]
_, old = read_tile("road_line")
for y in range(16):
    for x in range(16):
        if old[y][x] in "mf":
            g[y][x] = "m" if H(x, y, 3) > 0.12 else "f"
            if y + 1 < 16 and old[y + 1][x] not in "mf": g[y + 1][x] = "n"
T["road_line"] = g

# grass: tufts lit at the tips, shadowed at the roots
g = canvas("s")
tufts = [(2, 3), (7, 1), (12, 4), (4, 9), (10, 8), (14, 12), (1, 14), (7, 13), (13, 1)]
for x, y in tufts:
    g[y][x] = "f"; g[(y + 1) % 16][x] = "s"; g[(y + 1) % 16][(x - 1) % 16] = "f"; g[(y + 1) % 16][(x + 1) % 16] = "f"
    g[(y + 2) % 16][x] = "d"; g[(y + 2) % 16][(x - 1) % 16] = "d"; g[(y + 2) % 16][(x + 1) % 16] = "d"
for _ in range(8):
    x, y = rnd.randrange(16), rnd.randrange(16)
    if g[y][x] == "s": g[y][x] = "d"
T["grass"] = g

# cobble: rounded stones, each lit top-left and shaded bottom-right, dark mortar
g = canvas("d")
stones = [(0, 0, 6, 3), (8, 0, 14, 3), (4, 4, 10, 7), (12, 4, 18, 7), (0, 8, 6, 11), (8, 8, 14, 11), (4, 12, 10, 15), (12, 12, 18, 15)]
for x0, y0, x1, y1 in stones:
    for y in range(y0, y1):
        for x in range(x0, x1):
            corner = (x in (x0, x1 - 1)) and (y in (y0, y1 - 1))
            if corner: continue
            c = "s"
            if y == y0 and x < x0 + 4: c = "f"
            if (x, y) == (x1 - 2, y1 - 1): c = "n"
            g[y % 16][x % 16] = c
T["cobble"] = g

# roof: overlapping shingle rows, lit lip, deep shadow under each row, staggered seams
g = canvas("n")
for row in range(4):
    y0 = row * 4
    off = 0 if row % 2 == 0 else 4
    rect(g, 0, y0, 15, y0, "s")
    rect(g, 0, y0 + 1, 15, y0 + 2, "d")
    rect(g, 0, y0 + 3, 15, y0 + 3, "k")
    for sx in range(off, 16 + off, 8):
        g[y0 + 1][sx % 16] = "n"; g[y0 + 2][sx % 16] = "n"; g[y0][sx % 16] = "d"
        g[y0 + 1][(sx + 1) % 16] = "s"
    g[y0 + 2][(off + 5) % 16] = "n"
T["roof"] = g

# house_wall: clapboard siding, each board lit on top and shadowed under the lip
g = canvas("d")
rect(g, 0, 0, 15, 0, "f"); rect(g, 0, 1, 15, 1, "s")
for y0 in (2, 5, 8, 11):
    rect(g, 0, y0, 15, y0, "s")
    rect(g, 0, y0 + 2, 15, y0 + 2, "n")
for x, y in [(5, 3), (12, 6), (3, 9), (9, 12)]: g[y][x] = "n"
rect(g, 0, 14, 15, 14, "n"); rect(g, 0, 15, 15, 15, "k")
T["house_wall"] = g

# house_window: siding around a lit-frame window with moonlit glass and a sill
g = [r[:] for r in T["house_wall"]]
rect(g, 3, 3, 12, 12, "f"); rect(g, 12, 3, 12, 12, "d"); rect(g, 3, 12, 12, 12, "d")
rect(g, 4, 4, 11, 11, "n")
for y in range(4, 12):
    for x in range(4, 12):
        if x + y < 12: g[y][x] = "d"
rect(g, 7, 4, 7, 11, "s"); rect(g, 4, 7, 11, 7, "s")
g[5][9] = "m"; g[5][10] = "m"; g[6][10] = "m"; g[9][5] = "f"
rect(g, 2, 13, 13, 13, "m"); rect(g, 2, 14, 13, 14, "n")
T["house_window"] = g

# hedge: leaf clusters like the tree, moonlit on top, dark at the roots
g = [r[:] for r in read_tile("hedge")[1]]
for y in range(0, 13):
    for x in range(16):
        if g[y][x] in "fdns":
            h = H(x, y, 5)
            depth = y / 12
            if h < 0.45 - depth * 0.4: g[y][x] = "s" if h < 0.1 - depth * 0.1 else "v"
            elif h < 0.8 - depth * 0.3: g[y][x] = "v" if depth < 0.4 else "d"
            else: g[y][x] = "n"
for x in range(16):
    if g[0][x] in "f": g[0][x] = "s"
T["hedge"] = g

# tree (tile): crown in the tree sprite's greens, lit top-left, honey trunk lit on the left
g = [r[:] for r in read_tile("tree")[1]]
for y in range(16):
    for x in range(16):
        c = g[y][x]
        if c == "d" and y < 12:
            h = H(x, y, 9)
            lit = (x + y) < 14
            g[y][x] = ("w" if h < 0.12 else "v") if (lit and h < 0.6) else ("d" if h < 0.75 else "n")
        if c == "o": g[y][x] = "y" if x < 7 else "o"
        if c == "n" and y >= 12: g[y][x] = "r" if x > 8 else "n"
T["tree"] = g

ts = TS["town_night"]["tiles"]
T["lamp_post"] = [r[:] for r in T["sidewalk"]]
for name in ts:
    if name in T: continue
    _, g0 = read_tile(name)
    wrap = name in ("path", "puddle", "porch", "alley_gap")
    T[name] = bevel(g0, wrap=wrap, seed=ts.index(name))

for k, v in T.items():
    assert len(v) == 16 and all(len(r) == 16 for r in v), k
json.dump({k: ["".join(r) for r in v] for k, v in T.items()}, open(A + "town_tiles.json", "w"), indent=0)

def draw(g):
    im = Image.new("RGBA", (16, 16)); p = im.load()
    for y, r in enumerate(g):
        for x, c in enumerate(r): p[x, y] = P[c]
    return im
NEW = {k: draw(v) for k, v in T.items()}
OLD = {n: draw(read_tile(n)[1]) for n in ts}

def room_img(rid, use_new):
    r = json.load(open(R + f"data/rooms/{rid}.json"))
    lay = r["layout"]; out = Image.new("RGBA", (16 * len(lay[0]), 16 * len(lay)), (11, 14, 31, 255))
    for y, row in enumerate(lay):
        for x, ch in enumerate(row):
            n = r["legend"].get(ch)
            if n in OLD:
                out.alpha_composite((NEW if use_new else OLD)[n], (x * 16, y * 16))
    return out

if __name__ == "__main__":
    for rid in sys.argv[1:] or ["street_maple", "square"]:
        a, b = room_img(rid, False), room_img(rid, True)
        S = 3
        page = Image.new("RGBA", (a.width * S, a.height * S * 2 + 30), (14, 14, 18, 255))
        page.alpha_composite(a.resize((a.width * S, a.height * S), Image.NEAREST), (0, 0))
        page.alpha_composite(b.resize((b.width * S, b.height * S), Image.NEAREST), (0, a.height * S + 30))
        page.save(A + f"town_{rid}.png")
    Z = 8; names = ts
    sheet = Image.new("RGBA", (10 * (16 * Z + 10) + 10, 8 * (16 * Z + 10) + 10), (14, 14, 18, 255))
    for i, n in enumerate(names):
        x, y = 10 + (i % 10) * (16 * Z + 10), 10 + (i // 10) * 2 * (16 * Z + 10)
        sheet.alpha_composite(OLD[n].resize((16 * Z, 16 * Z), Image.NEAREST), (x, y))
        sheet.alpha_composite(NEW[n].resize((16 * Z, 16 * Z), Image.NEAREST), (x, y + 16 * Z + 6))
    sheet.save(A + "town_sheet.png")
