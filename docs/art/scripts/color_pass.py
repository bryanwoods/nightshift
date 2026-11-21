"""Add soft cool colors here and there. Scenery stays cool: no new lamp or moon clusters."""
R = "/Users/bryan/workspace/nightshift/assets/px/tiles/"

def load(path):
    L = open(R + path).read().splitlines()
    i = L.index("@tile")
    return L, i, [list(r) for r in L[i + 1:i + 17]]

def save(path, L, i, g):
    L[i + 1:i + 17] = ["".join(r) for r in g]
    open(R + path, "w").write("\n".join(L) + "\n")

def edit(path, fn):
    L, i, g = load(path)
    fn(g)
    save(path, L, i, g)

def flower(g, x, y, petal, center="x", leaf="v"):
    for dx, dy in ((0, -1), (-1, 0), (1, 0), (0, 1)):
        if 0 <= x + dx < 16 and 0 <= y + dy < 16 and g[y + dy][x + dx] not in "k":
            g[y + dy][x + dx] = petal
    g[y][x] = center
    if y + 2 < 16 and g[y + 2][x] not in "k":
        g[y + 2][x] = leaf

def flowerbed(g):
    flower(g, 4, 4, "F", "x", "i")
    flower(g, 10, 5, "E", "x", "v")
    flower(g, 6, 9, "E", "x", "i")
    flower(g, 11, 10, "F", "x", "v")
    for x, y in [(3, 7), (8, 6), (12, 8), (4, 12), (9, 12)]:
        if g[y][x] == "n": g[y][x] = "v"
    for x, y in [(3, 8), (9, 7)]:
        if g[y][x] == "n": g[y][x] = "i"

def grass(g):
    for x, y in [(7, 1), (10, 8)]:
        if g[y][x] == "f": g[y][x] = "i"
    for x, y in [(4, 9), (14, 12)]:
        if g[y][x] == "f": g[y][x] = "i"
    g[6][5] = "F"; g[7][5] = "v"
    g[12][11] = "E"; g[13][11] = "v"
    g[3][14] = "u"

def hedge(g):
    for x, y, c in [(3, 2, "F"), (9, 4, "x"), (13, 1, "E"), (6, 7, "F"), (11, 9, "E")]:
        g[y][x] = c

def house_window(g):
    for y in range(16):
        for x in range(16):
            if g[y][x] == "m":
                g[y][x] = "x" if y < 12 else "f"
    for y in range(4, 12):
        for x in range(4, 12):
            if g[y][x] == "d": g[y][x] = "u" if (x + y) % 3 == 0 else "q" if (x + y) < 9 else "d"
    g[13][2] = "x"

def puddle(g):
    for y in range(16):
        for x in range(16):
            if g[y][x] == "f" and (x + y) % 3 == 0: g[y][x] = "u"
    for x, y in [(5, 8), (10, 6), (8, 10)]:
        if g[y][x] == "n": g[y][x] = "q"

def fountain(g):
    for y in range(4, 13):
        for x in range(2, 14):
            if g[y][x] in "fs" and (x + y) % 2 == 0: g[y][x] = "u"
            elif g[y][x] == "n" and (x * 3 + y) % 7 == 0: g[y][x] = "q"

def roof(g):
    for x, y, c in [(3, 2, "v"), (4, 2, "v"), (4, 1, "i"), (11, 10, "v"), (12, 10, "v"), (12, 9, "i")]:
        g[y][x] = c

def sidewalk(g):
    g[14][13] = "v"; g[15][12] = "v"; g[15][13] = "i"

def cobble(g):
    for x, y in [(7, 3), (11, 11), (3, 15)]:
        if g[y][x] == "d": g[y][x] = "v"

def tree(g):
    for x, y, c in [(5, 3, "F"), (10, 5, "x"), (7, 8, "E"), (12, 2, "F")]:
        if g[y][x] in "wvdn": g[y][x] = c

def rug(g):
    for y in range(2, 14):
        for x in range(2, 14):
            if g[y][x] == "f": g[y][x] = "u"
            elif g[y][x] == "d" and (x, y) not in ():
                pass
    g[8][3] = "E"; g[3][8] = "x"; g[13][8] = "E"; g[8][13] = "E"
    g[7][7] = "F"; g[8][8] = "E"

def blanket(g):
    k = 0
    for y in range(1, 15):
        for x in range(3, 13):
            if g[y][x] == "f" and all(g[y + dy][x + dx] in "sd" for dx, dy in ((1, 0), (-1, 0), (0, 1), (0, -1))):
                g[y][x] = "uiE"[k % 3]; k += 1

def plant(g):
    for y in range(3, 11):
        for x in range(16):
            if g[y][x] == "s":
                g[y][x] = "w" if (x + y) < 11 else ("v" if (x + y) < 17 else "v")
    for x, y in [(6, 5), (10, 6), (7, 8)]:
        if g[y][x] in "wv": g[y][x] = "i"
    g[5][9] = "F"

for path, fn in [("town_night/flowerbed.txt", flowerbed), ("town_night/grass.txt", grass),
                 ("town_night/hedge.txt", hedge), ("town_night/house_window.txt", house_window),
                 ("town_night/puddle.txt", puddle), ("town_night/fountain.txt", fountain),
                 ("town_night/roof.txt", roof), ("town_night/sidewalk.txt", sidewalk),
                 ("town_night/lamp_post.txt", sidewalk), ("town_night/cobble.txt", cobble),
                 ("town_night/tree.txt", tree), ("home_night/rug.txt", rug),
                 ("home_night/bed_head.txt", blanket), ("home_night/bed_foot.txt", blanket),
                 ("home_night/plant.txt", plant)]:
    edit(path, fn)
print("done")
