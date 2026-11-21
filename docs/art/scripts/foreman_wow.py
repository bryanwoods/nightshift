from autoshade import *
from PIL import ImageDraw

EXTRA = {"A": (226, 203, 182, 255), "B": (196, 168, 156, 255), "C": (201, 82, 30, 255), "D": (125, 51, 34, 255)}
P = dict(L); P.update(EXTRA)

def drawp(rows):
    im = Image.new("RGBA", (len(rows[0]), len(rows))); p = im.load()
    for y, r in enumerate(rows):
        for x, c in enumerate(r):
            if c != ".": p[x, y] = P[c]
    return im

BAYER = [[0, 2], [3, 1]]
def tone(I, x, y, ramp):
    n = len(ramp)
    t = I * (n - 1)
    return ramp[max(0, min(n - 1, int(round(t))))]

fr, _ = frames("foreman")
g = [list(r) for r in fr["down_0"]]
O = [r[:] for r in g]
def S(x, y, c): g[y][x] = c

# hard hat dome rows 3..5, ridge, glint, headlamp, brim on row 6
HAT = ["D", "C", "e", "l", "b"]
for y in range(3, 6):
    for x in range(9, 23):
        u, v = (x - 9) / 13, (y - 3) / 2
        I = 0.95 - 0.8 * u - 0.15 * v
        g[y][x] = tone(max(0, min(1, I)), x, y, HAT)
for y in range(3, 6):
    S(15, y, "b" if y < 5 else "l"); S(16, y, "C")
S(11, 3, "m"); S(12, 3, "b"); S(10, 3, "b"); S(10, 4, "b"); S(11, 4, "b")
S(14, 2, "l"); S(15, 2, "m"); S(16, 2, "m"); S(17, 2, "l")
S(7, 6, "k"); S(24, 6, "k")
for x in range(8, 24):
    u = (x - 8) / 15
    g[6][x] = "b" if u < 0.15 else "l" if u < 0.45 else "e" if u < 0.8 else "C"
S(7, 7, "."); S(24, 7, ".")

# face: brim shadow on the top row, skin ramp left to right, nose, mouth, cheeks
for y in range(7, 12):
    for x in range(9, 23):
        if O[y][x] not in "ml":
            continue
        if O[y][x] == "l":
            g[y][x] = ("b" if y < 9 else "l") if x < 15 else ("e" if y < 9 else "C")
            continue
        u = (x - 10) / 11
        if y == 7:
            g[y][x] = "A" if u < 0.7 else "B"
        else:
            g[y][x] = "m" if u < 0.6 else "A" if u < 0.88 else "B"
S(16, 10, "A")
S(15, 11, "A"); S(16, 11, "A")
S(11, 10, "h"); S(20, 10, "h")

# neck and collar under the chin
for x in range(12, 20):
    g[12][x] = "A" if x < 17 else "B"
for x in range(14, 18):
    g[13][x] = "A" if x < 16 else "B"

# coat: a rounded body, dithered, lit from the top left
COAT = ["n", "d", "s", "f"]
for y in range(13, 28):
    for x in range(4, 28):
        if O[y][x] != "d":
            continue
        u, v = (x - 4) / 23, (y - 13) / 14
        cyl = max(0, 1 - abs(u - 0.26) * 1.7)
        I = 0.55 * cyl + 0.3 * (1 - v)
        g[y][x] = tone(max(0, min(1, I)), x, y, COAT)

def coat(x, y): return O[y][x] == "d"
# cool rim light down the shadow side
for y in range(15, 27):
    for x in range(27, 3, -1):
        if coat(x, y):
            g[y][x] = "s"; break
# shoulder tops catch the moon
for x in range(6, 14): g[13][x] = "f" if x < 11 else "s"
for x in range(18, 26): g[13][x] = "s" if x < 22 else "d"
g[14][6] = "f"; g[14][7] = "f"
# arm crease on the left, with a lit edge
for y in range(16, 26):
    S(8, y, "n"); S(7, y, "f" if y < 21 else "s")
# placket and buttons
for y in range(14, 28):
    if coat(15, y): S(15, y, "n")
for y in (16, 19, 25):
    S(14, y, "f")
# reflective silver stripe across the chest
for x in range(4, 18):
    if coat(x, 21):
        u = (x - 4) / 13
        g[21][x] = "m" if u < 0.35 else "f" if u < 0.75 else "s"
        g[22][x] = "s" if u < 0.6 else "d"
# pocket flap
# hem shadow
for x in range(6, 26):
    if coat(x, 27): g[27][x] = "n"
    if coat(x, 26) and x > 17: g[26][x] = "n"
for y in range(23, 27):
    for x in range(4, 15):
        if coat(x, y) and g[y][x] == "n" and x not in (8,): g[y][x] = "d"

# clipboard: honey board, metal clip, paper with ruled lines, a cast shadow on the coat
for y in range(16, 25):
    for x in range(18, 25):
        edge = x in (18, 24) or y in (16, 24)
        if edge:
            g[y][x] = "y" if (x == 18 or y == 16) else "r"
        else:
            g[y][x] = "m" if x < 22 else "A"
            if y in (18, 20, 22) and 19 <= x <= 23: g[y][x] = "s" if x < 22 else "d"
for x in range(20, 23): S(x, 15, "f")
S(20, 15, "m"); S(21, 16, "f"); S(22, 16, "s")
for y in range(17, 26): S(17, y, "n")
for x in range(19, 26):
    if coat(x, 25): S(x, 25, "n")
S(18, 23, "m"); S(18, 22, "A"); S(17, 23, "A"); S(17, 22, "m")

# trousers and boots
for y in range(28, 32):
    for x0 in (10, 18):
        for k in range(4):
            if O[y][x0 + k] == "n":
                g[y][x0 + k] = ("d" if k == 0 else "n") if y < 30 else ("r" if k == 0 and y == 30 else "j")
S(10, 31, "o"); S(18, 31, "o")

after = ["".join(r) for r in g]
open("foreman_wow.txt", "w").write("\n".join(after))

Z = 14
auto = shade(fr["down_0"])
W = 3 * (32 * Z + 30) + 30
img = Image.new("RGBA", (W, 32 * Z + 90), (14, 14, 18, 255)); d = ImageDraw.Draw(img)
for i, (lab, rows) in enumerate((("NOW", fr["down_0"]), ("LAST DEMO", auto), ("HAND-PAINTED", after))):
    x = 30 + i * (32 * Z + 30)
    d.rounded_rectangle([x - 8, 40, x + 32 * Z + 8, 48 + 32 * Z], 14, fill=P["n"])
    img.alpha_composite(drawp(rows).resize((32 * Z, 32 * Z), Image.NEAREST), (x, 44))
    d.text((x, 15), lab, fill=P["m"] if i == 2 else P["f"])
img.save("foreman_wow.png")
small = Image.new("RGBA", (3 * 40 * 3, 40 * 3), P["d"])
for i, rows in enumerate((fr["down_0"], auto, after)):
    small.alpha_composite(drawp(rows).resize((96, 96), Image.NEAREST), (i * 120 + 12, 12))
small.save("foreman_wow_small.png")
