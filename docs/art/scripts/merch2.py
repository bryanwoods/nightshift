import json, random, math
from PIL import Image, ImageDraw
R = "/Users/bryan/workspace/nightshift/"
pal = json.load(open(R + "data/palette.json"))
C, L = {}, {}
for g in ("night", "morning"):
    for n, v in pal[g].items():
        rgb = tuple(int(v["hex"][i:i+2], 16) for i in (1, 3, 5)) + (255,)
        C[n] = rgb; L[v["letter"]] = rgb
C["pinklite"] = (240, 138, 152, 255)
C["shadow"] = (58, 52, 120, 255)
W, H, SCALE = 280, 284, 10
BG = (14, 14, 18, 255)

def grid(name, frame):
    lines = open(R + f"assets/px/sprites/{name}.txt").read().splitlines()
    i = lines.index("@" + frame)
    out = []
    for l in lines[i + 1:]:
        if not l or l.startswith("@") or l.startswith("#"): break
        out.append(list(l))
    return out

def render(g):
    im = Image.new("RGBA", (len(g[0]), len(g)), (0, 0, 0, 0)); p = im.load()
    for y, row in enumerate(g):
        for x, ch in enumerate(row):
            if ch != ".": p[x, y] = L[ch]
    return im

def paint(g, x, y, rows):
    for dy, row in enumerate(rows):
        for dx, ch in enumerate(row):
            if ch != " ": g[y + dy][x + dx] = ch

def scale2x(im):
    w, h = im.size; p = im.load()
    out = Image.new("RGBA", (w * 2, h * 2)); o = out.load()
    g = lambda x, y: p[min(max(x, 0), w - 1), min(max(y, 0), h - 1)]
    for y in range(h):
        for x in range(w):
            E = p[x, y]; B = g(x, y - 1); D = g(x - 1, y); F = g(x + 1, y); Hh = g(x, y + 1)
            if B != Hh and D != F:
                e0 = D if D == B else E; e1 = F if B == F else E
                e2 = D if D == Hh else E; e3 = F if Hh == F else E
            else:
                e0 = e1 = e2 = e3 = E
            o[2*x, 2*y] = e0; o[2*x+1, 2*y] = e1; o[2*x, 2*y+1] = e2; o[2*x+1, 2*y+1] = e3
    return out

def pad(im, left=0, right=0, top=0):
    out = Image.new("RGBA", (im.width + left + right, im.height + top), (0, 0, 0, 0))
    out.paste(im, (left, top)); return out

def stamp(im, x, y, rows, cmap):
    p = im.load()
    for dy, row in enumerate(rows):
        for dx, ch in enumerate(row):
            if ch in cmap: p[x + dx, y + dy] = cmap[ch]

def arm(im, a, b, sleeve, w=4):
    d = ImageDraw.Draw(im)
    d.line([a, b], fill=C["ink"], width=w + 2)
    for pt in (a, b):
        d.ellipse([pt[0] - (w + 2) // 2, pt[1] - (w + 2) // 2, pt[0] + (w + 1) // 2, pt[1] + (w + 1) // 2], fill=C["ink"])
    d.line([a, b], fill=sleeve, width=w)

# ---------------- the cast, with new poses
jar = grid("jar_keeper_wave", "idle_0")
for y, x in [(20, 12), (20, 13), (20, 26), (20, 27), (21, 14), (21, 15), (21, 24), (21, 25)]:
    jar[y][x] = "s"
jar[30][16] = "k"; jar[30][23] = "k"

unb = grid("unbaker_battle", "idle_0")
for x in (9, 10, 15, 16): unb[17][x] = "m"
paint(unb, 19, 32, [
 "  kkkkkkk  ",
 " kyoyoyoyk ",
 "kyyoyyoyyok",
 "kyoyoyoyook",
 "koooooooook",
 " krrrrrrrk ",
 "  kkkkkkk  "])

wash = render(grid("window_washer_battle", "idle_0"))
puddle = render(grid("puddle_keeper_battle", "idle_0"))
nojob = render(grid("no_job_battle", "idle_0"))
curfew = render(grid("curfew_battle", "idle_0"))
foreman = scale2x(render(grid("foreman", "down_0")))
wg = grid("wick", "down_0")
FLAME = next((x, y) for y, r in enumerate(wg) for x, c in enumerate(r) if c == "e")
wick = scale2x(render(wg))

taz = pad(scale2x(render(grid("tadzio", "down_0"))), right=10, top=10)
arm(taz, (24, 40), (31, 27), C["seafoam"])
stamp(taz, 27, 15, [
 "...kkk.",
 "..kmmmk",
 ".kfmmmk",
 "kffffk.",
 "kfffk..",
 "kffk...",
 ".kk....",
], {"k": C["ink"], "m": C["moon"], "f": C["fog"]})
stamp(taz, 28, 23, [".kkkk.", "kmmmmk", "kmmmmk", ".kkkk."], {"k": C["ink"], "m": C["moon"]})
TAZ_LENS = (32, 17)

post = scale2x(render(grid("postman", "down_0")))
stamp(post, 2, 34, [
 "kkkkkkkkkkkk",
 "kmffmmmmffmk",
 "kmmmffmffmmk",
 "kmmmmmhmmmmk",
 "kmmmmhhhmmmk",
 "kmmmmmhmmmmk",
 "kkkkkkkkkkkk"], {"k": C["ink"], "m": C["moon"], "f": C["fog"], "h": C["hush"]})
stamp(post, 12, 36, ["kk", "mk", "mk", "kk"], {"k": C["ink"], "m": C["moon"]})
LETTER = (8, 37)

cast = {
 "foreman": foreman, "nojob": nojob, "washer": wash, "jar": render(jar), "curfew": curfew,
 "unbaker": render(unb), "puddle": puddle, "postman": post, "tadzio": taz, "wick": wick,
 "dad": None,
}
dg = ["".join(r) for r in grid("dad", "down_0")]
assert dg[7][5] == "q" and len(dg) == 35
cast["dad"] = scale2x(render([list(r) for r in dg]))
_dp = cast["dad"].load()
_dp[11, 15] = C["ink"]; _dp[20, 15] = C["ink"]
_dp[10, 14] = C["froth"]; _dp[21, 14] = C["froth"]

# ---------------- canvas
img = Image.new("RGBA", (W, H), BG)
px = img.load()
X0, Y0, X1, Y1, RAD = 14, 68, 266, 266, 18
mask = Image.new("L", (W, H), 0)
ImageDraw.Draw(mask).rounded_rectangle([X0, Y0, X1, Y1], RAD, fill=255)
scene = Image.new("RGBA", (W, H), C["night"])
sp = scene.load()
BAYER = [[0, 8, 2, 10], [12, 4, 14, 6], [3, 11, 1, 9], [15, 7, 13, 5]]
def dith(x, y): return (BAYER[y % 4][x % 4] + 0.5) / 16

for y in range(Y0, Y1 + 1):
    t = (y - Y0) / 120
    for x in range(X0, X1 + 1):
        if t < 0.33: sp[x, y] = C["night"] if dith(x, y) < (t / 0.33) ** 2 * 0.9 else C["ink"]
        else: sp[x, y] = C["dusk"] if dith(x, y) < max(0, (t - 0.45) / 0.55) else C["night"]

def glow(cx, cy, rx, ry, col, dens, only=None, area=None):
    x0, y0, x1, y1 = area or (X0, Y0, X1, Y1)
    for y in range(max(Y0, int(cy - ry)), min(Y1, int(cy + ry)) + 1):
        for x in range(max(X0, int(cx - rx)), min(X1, int(cx + rx)) + 1):
            dd = ((x - cx) / rx) ** 2 + ((y - cy) / ry) ** 2
            if dd < 1 and (only is None or sp[x, y] in only) and dith(x, y) < (1 - dd) * dens:
                sp[x, y] = col

rnd = random.Random(11)
for _ in range(90):
    x, y = rnd.randint(X0 + 4, X1 - 4), rnd.randint(Y0 + 4, Y0 + 84)
    sp[x, y] = C["moon"] if rnd.random() < 0.45 else C["fog"] if rnd.random() < 0.7 else C["slate"]
def twinkle(x, y, big=False):
    for dx, dy in [(0, 0), (1, 0), (-1, 0), (0, 1), (0, -1)]: sp[x + dx, y + dy] = C["moon"]
    for dx, dy in [(2, 0), (-2, 0), (0, 2), (0, -2)]: sp[x + dx, y + dy] = C["fog"]
    if big:
        for dx, dy in [(3, 0), (-3, 0), (0, 3), (0, -3)]: sp[x + dx, y + dy] = C["slate"]
for x, y in [(36, 84), (58, 122), (92, 92), (250, 140), (128, 78)]: twinkle(x, y)

# moon with halo
mx, my = 224, 104
glow(mx, my, 34, 34, C["dusk"], 1.2, only=[C["ink"], C["night"]])
glow(mx, my, 24, 24, C["slate"], 0.7, only=[C["dusk"]])
d = ImageDraw.Draw(scene)
for x in range(mx - 14, mx + 15):
    for y in range(my - 14, my + 15):
        if (x - mx) ** 2 + (y - my) ** 2 <= 13.5 ** 2 and (x - mx - 6) ** 2 + (y - my + 5) ** 2 > 12 ** 2:
            sp[x, y] = C["moon"]
for (x, y) in [(214, 100), (217, 110), (212, 106)]: sp[x, y] = C["straw"]

# skyline
SKY = 190
rnd = random.Random(3)
x = X0
while x < X1:
    w = rnd.randint(14, 26); h = rnd.randint(14, 38)
    a, b, c, e = x, SKY - h, x + w, SKY
    d.rectangle([a, b, c, e], fill=C["night"])
    d.rectangle([a, b, c, b], fill=C["slate"])
    if rnd.random() < 0.4:
        d.rectangle([a + w // 2 - 1, b - 5, a + w // 2 + 1, b - 1], fill=C["night"])
        sp[a + w // 2, b - 5] = C["slate"]
    for wy in range(b + 5, e - 4, 7):
        for wx in range(a + 3, c - 3, 6):
            r_ = rnd.random()
            if r_ < 0.32: d.rectangle([wx, wy, wx + 1, wy + 2], fill=C["lamp"])
            elif r_ < 0.5: d.rectangle([wx, wy, wx + 1, wy + 2], fill=C["dusk"])
    x += w + rnd.randint(0, 3)
d.rectangle([X0, SKY, X1, Y1], fill=C["dusk"])
for y in range(SKY, Y1 + 1, 5):
    off = 0 if (y // 5) % 2 else 4
    for x in range(X0 + off, X1, 8):
        d.line([x, y, x + 6, y], fill=C["slate"])
d.rectangle([X0, SKY, X1, SKY], fill=C["fog"])

# the warm pool the crew stands in
GX, GY = 140, 240
glow(GX, GY - 34, 112, 72, C["dusk"], 1.4, only=[C["night"]])
glow(GX, GY + 14, 124, 30, C["slate"], 1.2, only=[C["dusk"]])
glow(GX, GY + 16, 74, 16, C["fog"], 0.45, only=[C["slate"]])

# sheep leaping past the moon, with a dotted hop trail
SHEEP = grid("sheep", "sprite")
sx, sy = 180, 76
for i in range(0, 40, 3):
    t = i / 40
    tx = int(sx - 44 + t * 44); ty = int(sy + 26 - math.sin(t * math.pi) * 22)
    if (tx, ty) and 0 < ty: sp[tx, ty + 4] = C["fog"]
scene.alpha_composite(render(SHEEP), (sx - 2, sy))

def zed(x, y, s, col):
    for i in range(s): sp[x + i, y] = col; sp[x + i, y + s - 1] = col; sp[x + s - 1 - i, y + i] = col
zed(118, 128, 5, C["moon"]); zed(110, 116, 6, C["moon"]); zed(101, 103, 7, C["moon"])

BUB = render(grid("bubble", "sprite"))
for bx, by in [(76, 132), (86, 118), (70, 108)]:
    scene.alpha_composite(BUB, (bx, by))
NOTE = render(grid("note", "sprite"))
for nx, ny in [(178, 138), (190, 126)]:
    scene.alpha_composite(NOTE, (nx, ny))

# ---------------- place the crew, back to front
def place(name, cx, base, dx=0, shadow=True):
    im = cast[name]; w, h = im.size
    left = cx - w // 2 + dx
    if shadow:
        ImageDraw.Draw(scene).ellipse([cx - 13, base - 2, cx + 13, base + 1], fill=C["night"])
    scene.alpha_composite(im, (left, base - h))
    return left, base - h

def at(name, vis_left, base, shadow=True):
    x0, _, x1, _ = cast[name].getbbox()
    return place(name, vis_left - x0 + cast[name].width // 2, base, shadow=shadow)

cast["unbaker"] = cast["unbaker"].transpose(Image.FLIP_LEFT_RIGHT)
ImageDraw.Draw(scene).ellipse([28, 253, 246, 267], fill=C["night"])
at("nojob", 32, 213)
at("washer", 59, 216)
at("curfew", 95, 212)
at("jar", 158, 216)
at("foreman", 196, 213)
at("unbaker", 32, 259)
d = ImageDraw.Draw(scene)
d.ellipse([204, 256, 238, 262], fill=C["moss"]); d.ellipse([207, 257, 235, 261], fill=C["seafoam"])
d.line([211, 258, 217, 258], fill=C["froth"])
at("puddle", 206, 259, shadow=False)
pl, pt = at("postman", 82, 262)
dl, dt = at("dad", 115, 264)
wl, wt = at("wick", 175, 263)
tl, tt = cast["tadzio"].width, None

# light: the letter, Wick's flame, Tadzio's flashlight beam
def soft(cx, cy, r, col, a):
    lay = Image.new("RGBA", (W, H), (0, 0, 0, 0)); lp = lay.load()
    for y in range(int(cy - r), int(cy + r) + 1):
        for x in range(int(cx - r), int(cx + r) + 1):
            dd = math.hypot(x - cx, y - cy) / r
            if dd < 1 and 0 <= x < W and 0 <= y < H:
                lp[x, y] = col[:3] + (int(255 * a * (1 - dd) ** 1.6),)
    scene.alpha_composite(lay)
soft(pl + LETTER[0], pt + LETTER[1], 14, C["lamp"], 0.55)
soft(wl + FLAME[0] * 2 + 1, wt + FLAME[1] * 2 + 1, 15, C["lamp"], 0.6)

TL = 142 - cast["tadzio"].getbbox()[0]
TT = 265 - cast["tadzio"].height
ox, oy = TL + TAZ_LENS[0], TT + TAZ_LENS[1]
tx, ty = 196, Y0 + 4
beam = Image.new("RGBA", (W, H), (0, 0, 0, 0)); bp = beam.load()
ang = math.atan2(ty - oy, tx - ox); length = math.hypot(tx - ox, ty - oy)
for y in range(Y0, oy + 1):
    for x in range(X0, X1):
        vx, vy = x - ox, y - oy
        along = vx * math.cos(ang) + vy * math.sin(ang)
        if along <= 0 or along > length: continue
        across = abs(-vx * math.sin(ang) + vy * math.cos(ang))
        half = 1.5 + along * 0.2
        if across < half:
            k = (1 - across / half) ** 0.7 * (1 - along / length) ** 0.6
            bp[x, y] = C["moon"][:3] + (int(120 * k),)
scene.alpha_composite(beam)
rnd = random.Random(5)
for _ in range(18):
    s = rnd.uniform(0.25, 0.95); a = rnd.uniform(-1, 1)
    along = s * length; half = 1.5 + along * 0.2
    x = int(ox + along * math.cos(ang) - a * half * math.sin(ang))
    y = int(oy + along * math.sin(ang) + a * half * math.cos(ang))
    if Y0 + 3 < y < 170: sp[x, y] = C["moon"]
twinkle(186, 96, True); twinkle(204, 132)

ImageDraw.Draw(scene).ellipse([140 - 13, 264, 140 + 13, 267], fill=C["night"])
scene.alpha_composite(cast["tadzio"], (TL, TT))
soft(ox, oy, 7, C["moon"], 0.9)
ds = (dl + 25, dt + 36)
arm(scene, ds, (TL + 6, TT + 37), C["dusk"], w=4)
stamp(scene, TL + 3, TT + 33, [
 ".kkkkk..",
 "kmmmmmk.",
 "kmmmmmmk",
 "kmkmkmmk",
 "kmkmkmk.",
 ".kkkkk..",
], {"k": C["ink"], "m": C["moon"]})

img.paste(scene, (0, 0), mask)
fd = ImageDraw.Draw(img)
fd.rounded_rectangle([X0 - 1, Y0 - 1, X1 + 1, Y1 + 1], RAD + 1, outline=C["ink"], width=1)
fd.rounded_rectangle([X0 - 4, Y0 - 4, X1 + 4, Y1 + 4], RAD + 4, outline=C["slate"], width=2)
stitch = Image.new("L", (W, H), 0)
ImageDraw.Draw(stitch).rounded_rectangle([X0 - 7, Y0 - 7, X1 + 7, Y1 + 7], RAD + 7, outline=255, width=1)
st = stitch.load()
for y in range(H):
    for x in range(W):
        if st[x, y] and (x + y) % 4 < 2: px[x, y] = C["moon"]

# ---------------- title
G = {
 "N": ["##...##","###..##","####.##","##.####","##..###","##...##","##...##","##...##","##...##"],
 "i": ["##","##","..","##","##","##","##","##","##"],
 "G": [".#####.","##...##","##.....","##.....","##.####","##...##","##...##","##...##",".######"],
 "h": ["##.....","##.....","##.....","######.","##...##","##...##","##...##","##...##","##...##"],
 "T": ["######","######","..##..","..##..","..##..","..##..","..##..","..##..","..##.."],
 "s": ["......","......",".#####","##....","##....",".####.","....##","....##","#####."],
 "H": ["##...##","##...##","##...##","##...##","#######","##...##","##...##","##...##","##...##"],
 "F": ["######","######","##....","##....","#####.","##....","##....","##....","##...."],
 "t": [".##..",".##..","#####",".##..",".##..",".##..",".##..",".##..","..###"],
}
WORD = "NiGhTsHiFt"; S = 3
widths = [max(len(r) for r in G[c]) for c in WORD]
total = sum(w * S for w in widths) + (len(WORD) - 1) * S
x = (W - total) // 2; TY = 12
layers = {}
for k, ch in enumerate(WORD):
    bob = -2 if k % 2 == 0 else 1
    for ry, row in enumerate(G[ch]):
        for rx, c in enumerate(row):
            if c == "#":
                for yy in range(S):
                    for xx in range(S):
                        layers[(x + rx * S + xx, TY + bob + ry * S + yy)] = ry
    x += widths[k] * S + S
for dx in range(-1, 5):
    for dy in range(-1, 5):
        for (a, b) in layers: px[a + dx, b + dy] = C["ink"]
for dx in range(1, 4):
    for (a, b) in layers: px[a + dx, b + dx] = C["shadow"]
for (a, b), ry in layers.items():
    px[a, b] = C["pinklite"] if ry == 0 else C["hush"]
for (a, b) in [(28, 16), (256, 30), (20, 40), (262, 12)]:
    for dx, dy in [(0, 0), (1, 0), (-1, 0), (0, 1), (0, -1)]: px[a + dx, b + dy] = C["moon"]
    for dx, dy in [(2, 0), (-2, 0), (0, 2), (0, -2)]: px[a + dx, b + dy] = C["slate"]

F = {
 "T": ["###",".#.",".#.",".#.",".#."], "H": ["#.#","#.#","###","#.#","#.#"], "E": ["###","#..","##.","#..","###"],
 "O": ["###","#.#","#.#","#.#","###"], "U": ["#.#","#.#","#.#","#.#","###"], "R": ["##.","#.#","##.","#.#","#.#"],
 "S": ["###","#..","###","..#","###"], "K": ["#.#","#.#","##.","#.#","#.#"], "I": ["###",".#.",".#.",".#.","###"],
 "D": ["##.","#.#","#.#","#.#","##."], "N": ["#..#","##.#","##.#","#.##","#..#"], "'": ["#","#",".",".","."],
 ".": [".",".",".",".","#"], " ": [".."],
 "M": ["#...#","##.##","#.#.#","#...#","#...#"], "A": [".#.","#.#","###","#.#","#.#"],
 "V": ["#.#","#.#","#.#","#.#",".#."], "Y": ["#.#","#.#",".#.",".#.",".#."],
 "G": ["###","#..","#.#","#.#","###"], "C": ["###","#..","#..","#..","###"],
}
LINE = "ONE HOUR. EVERY NIGHT. MAKE IT COUNT."
wsum = sum(len(F[c][0]) + 1 for c in LINE) - 1
x = (W - wsum) // 2; y = 50
for c in LINE:
    for ry, row in enumerate(F[c]):
        for rx, ch in enumerate(row):
            if ch == "#": px[x + rx, y + ry] = C["fog"]
    x += len(F[c][0]) + 1

big = img.resize((W * SCALE, H * SCALE), Image.NEAREST)
big.save("nightshift_cast_v2.png")
clear = big.copy(); cp = clear.load()
for yy in range(clear.height):
    for xx in range(clear.width):
        if cp[xx, yy] == BG: cp[xx, yy] = (0, 0, 0, 0)
clear.save("nightshift_cast_v2_clear.png")
