import json, random
from PIL import Image, ImageDraw
R = "/Users/bryan/workspace/nightshift/"
pal = json.load(open(R + "data/palette.json"))
L = {}
for g in ("night", "morning"):
    for v in pal[g].values():
        L[v["letter"]] = tuple(int(v["hex"][i:i+2], 16) for i in (1, 3, 5)) + (255,)
ts = json.load(open(R + "data/tilesets.json"))["tilesets"]["home_night"]
sheet = Image.open(R + "assets/tiles/home_night.png").convert("RGBA")
def old_tile(name):
    i = ts["tiles"].index(name)
    return sheet.crop(((i % 8) * 16, (i // 8) * 16, (i % 8) * 16 + 16, (i // 8) * 16 + 16))

def canvas(c="s"): return [[c] * 16 for _ in range(16)]
def rect(g, x0, y0, x1, y1, c):
    for y in range(y0, y1 + 1):
        for x in range(x0, x1 + 1): g[y][x] = c
def put(g, pts, c):
    for x, y in pts: g[y][x] = c
def rows(g): return ["".join(r) for r in g]

T = {}
rnd = random.Random(7)

# floor: planks lit from the top left, dark gaps, grain flecks, joints lit on the left
g = canvas()
joints = [10, 3, 12, 7]
for p in range(4):
    y0 = p * 4; j = joints[p]
    for x in range(16):
        g[y0][x] = "f" if rnd.random() < 0.12 else "s"
        g[y0 + 3][x] = "d"
    for yy in (1, 2):
        x = 0
        while x < 16:
            if rnd.random() < 0.05:
                for k in range(rnd.randint(2, 4)): g[y0 + yy][(x + k) % 16] = "d"
                x += 5
            elif rnd.random() < 0.015:
                g[y0 + yy][x] = "f"; x += 1
            else: x += 1
    for yy in range(3):
        g[y0 + yy][j] = "d"; g[y0 + yy][(j + 1) % 16] = "f" if yy == 0 else "s"
T["floor"] = rows(g)

# wall_face: lit top trim, vertical boards (lit left edge, shadow gap), baseboard
g = canvas("d")
for x in range(16):
    g[0][x] = "f"
    g[1][x] = "f" if x % 3 else "s"
    g[2][x] = "n"
    g[12][x] = "n"; g[13][x] = "s" if x % 4 else "f"; g[14][x] = "d"; g[15][x] = "k"
for y in range(3, 12):
    for b in range(4):
        g[y][b * 4] = "s"; g[y][b * 4 + 3] = "n"
        if y == 3: g[y][b * 4 + 1] = "n"; g[y][b * 4 + 2] = "n"
put(g, [(2, 7), (10, 5)], "n")
put(g, [(1, 4), (9, 4)], "s")
T["wall_face"] = rows(g)

# rug: each square slightly raised, a diamond with lit and shaded edges, woven flecks
g = canvas("s")
for i in range(16):
    g[0][i] = "d"; g[15][i] = "n"; g[i][0] = "d"; g[i][15] = "n"
for i in range(1, 15):
    g[1][i] = "f"; g[i][1] = "f"; g[14][i] = "d"; g[i][14] = "d"
g[1][1] = "m"
put(g, [(4, 4), (12, 4), (4, 12), (12, 12)], "d")
cx, cy = 8, 8
for k in range(5):
    put(g, [(3 + k, 8 - k), (8 + k, 3 + k)], "f")
    put(g, [(3 + k, 8 + k), (13 - k, 8 + k)], "d")
put(g, [(8, 3)], "m"); put(g, [(13, 8)], "s"); put(g, [(8, 13)], "n")
g[7][7] = "f"; g[8][8] = "d"
T["rug"] = rows(g)

# bed_head: lit headboard, round pillow, folded sheet, blanket with sparks
g = canvas("s")
for y in range(16): g[y][0] = "k"; g[y][15] = "k"; g[y][1] = "s"; g[y][14] = "n"
rect(g, 1, 0, 14, 0, "f"); rect(g, 2, 1, 13, 1, "d"); g[1][1] = "s"; g[1][14] = "n"
rect(g, 2, 2, 13, 7, "d")
pil = ["..nnnnnnnnnn..",
       ".nmmmfffffffn.",
       ".nmffffffffsn.",
       ".nfffffffssdn.",
       "..nsssssssdn..",
       "...nnnnnnnn..."]
for y, r in enumerate(pil):
    for x, c in enumerate(r):
        if c != ".": g[2 + y][1 + x] = c
for x in range(2, 14):
    g[8][x] = "m" if x < 6 else "f"
    g[9][x] = "f" if x < 11 else "s"
    g[10][x] = "d"
for y in range(11, 16):
    for x in range(2, 14):
        g[y][x] = "f" if x == 2 else ("d" if x >= 12 else "s")
put(g, [(5, 12), (9, 14)], "f")
T["bed_head"] = rows(g)

# bed_foot: blanket drapes with soft folds, lit footboard
g = canvas("s")
for y in range(16): g[y][0] = "k"; g[y][15] = "k"; g[y][1] = "s"; g[y][14] = "n"
for y in range(0, 11):
    for x in range(2, 14):
        g[y][x] = "f" if x == 2 else ("d" if x >= 12 else "s")
put(g, [(6, 1), (10, 3), (4, 5), (8, 7), (11, 9)], "f")
rect(g, 3, 4, 11, 4, "d"); rect(g, 3, 3, 9, 3, "f"); g[4][12] = "n"
rect(g, 2, 10, 13, 10, "d"); rect(g, 2, 11, 13, 11, "n")
rect(g, 1, 12, 14, 12, "f"); g[12][1] = "m"
rect(g, 1, 13, 14, 14, "d"); g[13][1] = "s"; g[14][1] = "s"; g[13][14] = "n"; g[14][14] = "n"
rect(g, 0, 15, 15, 15, "k")
T["bed_foot"] = rows(g)

# window: lit frame, moonlit panes with a glow in the top left, a crescent, a sill
g = canvas("d")
rect(g, 0, 0, 15, 0, "k")
rect(g, 1, 1, 14, 1, "f"); rect(g, 1, 1, 1, 12, "f"); rect(g, 14, 1, 14, 12, "n")
rect(g, 2, 2, 13, 2, "s"); rect(g, 2, 2, 2, 11, "s"); rect(g, 13, 2, 13, 11, "n"); rect(g, 2, 12, 13, 12, "n")
rect(g, 3, 3, 12, 11, "n")
for y in range(3, 12):
    for x in range(3, 13):
        if (x + y) < 10 and (x + y) % 2 == 0: g[y][x] = "d"
        if (x + y) < 8: g[y][x] = "d"
rect(g, 7, 3, 7, 11, "s"); rect(g, 8, 3, 8, 11, "k"); rect(g, 3, 7, 12, 7, "s"); rect(g, 3, 8, 12, 8, "k")
g[7][7] = "f"
put(g, [(10, 4), (11, 4), (11, 5), (11, 6), (10, 6)], "m"); g[5][12] = "f"
put(g, [(4, 10), (10, 10), (5, 5)], "f")
rect(g, 0, 13, 15, 13, "m"); rect(g, 0, 13, 0, 13, "f"); rect(g, 0, 14, 15, 14, "s"); rect(g, 0, 15, 15, 15, "n")
T["window"] = rows(g)

# closet: two doors, recessed panels (shadow inside top-left, light inside bottom-right), warm knobs
g = canvas("d")
rect(g, 0, 0, 15, 0, "k")
for x0, x1 in ((0, 6), (8, 15)):
    rect(g, x0, 1, x0, 15, "s"); rect(g, x0, 1, x1, 1, "s")
    for py0, py1 in ((3, 7), (9, 14)):
        rect(g, x0 + 2, py0, x1 - 1, py0, "n"); rect(g, x0 + 2, py0, x0 + 2, py1, "n")
        rect(g, x0 + 2, py1, x1 - 1, py1, "s"); rect(g, x1 - 1, py0 + 1, x1 - 1, py1, "s")
        g[py0 + 1][x0 + 3] = "n"
rect(g, 7, 1, 7, 15, "k")
put(g, [(6, 8), (8, 8)], "l"); put(g, [(6, 9), (8, 9)], "o"); put(g, [(5, 8)], "d")
T["closet"] = rows(g)

# nightstand: lit top with a front edge, two drawers, warm knob, a shadow on the floor behind
g = canvas("n")
for y in range(3): g[y][5] = "k"
rect(g, 1, 3, 14, 3, "k"); rect(g, 2, 3, 13, 3, "f"); g[3][2] = "m"
rect(g, 2, 4, 13, 5, "s"); put(g, [(3, 4), (4, 4), (10, 5)], "f"); rect(g, 2, 6, 13, 6, "f")
rect(g, 2, 7, 13, 15, "d"); rect(g, 2, 7, 2, 15, "s"); rect(g, 13, 7, 13, 15, "n")
for dy in (7, 11):
    rect(g, 3, dy, 12, dy, "s"); rect(g, 3, dy + 3, 12, dy + 3, "n")
put(g, [(7, 9), (8, 9)], "l"); put(g, [(7, 13), (8, 13)], "l"); put(g, [(8, 9), (8, 13)], "o")
for y in (7, 11, 15): g[y][0] = "k"; g[y][15] = "k"
T["nightstand"] = rows(g)

for k, v in T.items():
    assert len(v) == 16 and all(len(r) == 16 for r in v), k

def draw(r):
    im = Image.new("RGBA", (16, 16)); p = im.load()
    for y, row in enumerate(r):
        for x, c in enumerate(row): p[x, y] = L[c]
    return im
NEW = {k: draw(v) for k, v in T.items()}

room = json.load(open(R + "data/rooms/bedroom.json"))
def build(use_new):
    lay = room["layout"]; out = Image.new("RGBA", (16 * len(lay[0]), 16 * len(lay)))
    for y, row in enumerate(lay):
        for x, ch in enumerate(row):
            n = room["legend"][ch]
            out.alpha_composite(old_tile("floor") if n == "door" else Image.new("RGBA", (16, 16)), (x * 16, y * 16))
            t = NEW.get(n) if use_new else None
            out.alpha_composite(t or old_tile(n), (x * 16, y * 16))
    sp = Image.open(R + "assets/sprites/tadzio.png").convert("RGBA").crop((0, 0, 16, 32))
    out.alpha_composite(sp, (5 * 16, 4 * 16))
    return out

S = 5
before, after = build(False), build(True)
W, H = before.size
page = Image.new("RGBA", (W * S * 2 + 60, H * S + 70), (14, 14, 18, 255))
d = ImageDraw.Draw(page)
page.alpha_composite(before.resize((W * S, H * S), Image.NEAREST), (20, 50))
page.alpha_composite(after.resize((W * S, H * S), Image.NEAREST), (W * S + 40, 50))
d.text((20, 18), "NOW", fill=L["f"]); d.text((W * S + 40, 18), "SHADED LIKE THE TREE", fill=L["m"])
page.save("shade_room.png")

Z = 14; names = list(T)
close = Image.new("RGBA", (len(names) * (16 * Z + 20) + 20, 2 * (16 * Z + 50) + 20), (14, 14, 18, 255))
d = ImageDraw.Draw(close)
for i, n in enumerate(names):
    x = 20 + i * (16 * Z + 20)
    close.alpha_composite(old_tile(n).resize((16 * Z, 16 * Z), Image.NEAREST), (x, 40))
    close.alpha_composite(NEW[n].resize((16 * Z, 16 * Z), Image.NEAREST), (x, 16 * Z + 90))
    d.text((x, 15), n + " (now)", fill=L["f"]); d.text((x, 16 * Z + 65), n + " (shaded)", fill=L["m"])
close.save("shade_close.png")
json.dump(T, open("shaded_tiles.json", "w"), indent=1)
