from paint import *
import sys
from PIL import ImageDraw
B = "/private/tmp/claude-501/-Users-bryan-workspace-nightshift/4d7bec5d-bb8e-428c-ab10-4e6fc01d4442/scratchpad/art/sprites_before/"

def orig(name):
    lines = open(B + name + ".txt").read().splitlines()
    fw, fh = map(int, lines[0].split()[-1].split("x"))
    fr = {}
    for i, l in enumerate(lines):
        if l.startswith("@") and "=" not in l:
            fr[l[1:].strip()] = lines[i + 1:i + 1 + fh]
    return fr

def grid(rows): return [list(r) for r in rows]
def rows(g): return ["".join(r) for r in g]

def tadzio(o):
    g = grid(o)
    def S(x, y, c):
        if g[y][x] not in ".k": g[y][x] = c
    # hair: halo highlight, shadow on the right, strands lit left and shaded right
    for x, y in [(6, 3), (7, 3), (5, 4), (6, 4), (4, 5), (5, 5), (4, 6)]: S(x, y, "b")
    for y in range(4, 13):
        for x in (10, 11):
            if g[y][x] == "y": g[y][x] = "o"
    for y in range(13, 22):
        if g[y][3] == "y": g[y][3] = "b" if y < 17 else "y"
        for x in (11, 12):
            if g[y][x] == "y": g[y][x] = "o"
    S(4, 19, "o"); S(3, 19, "o")
    # face: swoop shadow on the forehead, shaded right cheek and jaw, blush, neck in shadow
    S(6, 8, "A"); S(7, 8, "A")
    for y in range(8, 13): S(10, y, "A")
    for x in (8, 9): S(x, 12, "A")
    S(5, 10, "h"); S(10, 10, "h")
    S(7, 13, "A"); S(8, 13, "B")
    # pajama top: folded collar, shadow side, hem shadow, arms
    S(5, 13, "x"); S(6, 13, "x"); S(9, 13, "f"); S(10, 13, "f")
    for y in range(14, 25):
        for x in (10, 11):
            if g[y][x] == "u": g[y][x] = "f"
        if g[y][5] == "u" and y < 20: g[y][5] = "x" if y % 3 == 0 else "u"
    for x, y in [(8, 19), (8, 20), (9, 21), (9, 22)]:
        if g[y][x] == "u": g[y][x] = "f"
    for x in range(4, 12):
        if g[24][x] == "u": g[24][x] = "f"
    for y in range(13, 24):
        if g[y][12] == "m": g[y][12] = "A"
    # pants: lit left leg edge, shaded right, the gap between the legs
    for y in range(25, 30):
        if g[y][5] == "d": g[y][5] = "s"
        if g[y][10] == "d": g[y][10] = "n"
    for y in range(27, 30): S(7, y, "n"); S(8, y, "n")
    S(5, 30, "f"); S(6, 30, "f"); S(9, 30, "d"); S(10, 30, "d")
    return rows(g)

def dad(o):
    g = grid(o)
    def S(x, y, c):
        if g[y][x] not in ".k": g[y][x] = c
    # hair: moonlit top-left, glint
    for x, y in [(3, 3), (4, 3), (5, 3), (3, 4), (4, 4), (6, 2), (4, 2)]:
        if g[y][x] == "j": g[y][x] = "r"
    S(4, 3, "o")
    # face: shadow under the hairline, shaded right side, nose
    for x in range(5, 11):
        if g[5][x] == "m": g[5][x] = "A"
    for y in range(5, 10): S(11, y, "A") if g[y][11] == "m" else None
    S(10, 8, "A"); S(8, 9, "A")
    # beard: lit strands on the left, mustache top lit
    for x, y in [(3, 9), (3, 10), (4, 11), (3, 12), (4, 12), (4, 13), (5, 14)]:
        if g[y][x] == "j": g[y][x] = "r"
    S(5, 10, "r"); S(6, 10, "r")
    # neck in the beard's shadow
    for x in range(6, 10):
        if g[15][x] == "m": g[15][x] = "A" if x < 8 else "B"
    # shirt: lit pocket and left edge, placket, shadow side with a cool rim
    S(3, 18, "f"); S(4, 18, "f")
    for y in range(20, 26):
        if g[y][3] in "sd": g[y][3] = "s"
    for y in range(18, 26):
        if g[y][8] == "d": g[y][8] = "n"
        if g[y][11] == "d": g[y][11] = "n"
        if g[y][12] == "d": g[y][12] = "s"
    for y in range(16, 18):
        if g[y][12] == "d": g[y][12] = "s"
    S(12, 26, "A")
    # jeans: lit left edges, knees, boots
    for y in range(27, 33):
        if g[y][4] == "n": g[y][4] = "d"
        if g[y][10] == "n" and y > 28: g[y][10] = "d"
    S(5, 30, "d"); S(11, 30, "d")
    S(4, 33, "r"); S(10, 33, "r")
    return rows(g)

def curfew(o):
    g = grid(o)
    O = [r[:] for r in g]
    h, w = len(g), len(g[0])
    # nightcap: lit left edge in froth, shaded right in fog, stripes of light
    for y in range(9, 21):
        xs = [x for x in range(w) if O[y][x] == "a"]
        if not xs: continue
        for x in xs:
            u = (x - min(xs)) / max(1, max(xs) - min(xs))
            g[y][x] = "x" if u < 0.18 else ("a" if u < 0.7 else "f")
    for y in range(14, 17):
        for x in range(w):
            if O[y][x] == "c": g[y][x] = "m" if x < 29 else "f"
    # brim band: lit on the left, shaded on the right
    for y in (19, 20):
        for x in range(w):
            if O[y][x] in "cm": g[y][x] = ("t" if O[y][x] == "m" else "m") if x < 14 else ("m" if O[y][x] == "m" else "f")
    # face: shadow under the brim, round shading toward the right
    for y in range(21, 33):
        xs = [x for x in range(w) if O[y][x] == "m"]
        if not xs: continue
        x0, x1 = min(xs), max(xs)
        for x in xs:
            u = (x - x0) / max(1, x1 - x0)
            c = "m" if u < 0.8 else ("A" if u < 0.95 else "B")
            if y in (21, 22): c = "A"
            g[y][x] = c
    # quilt: every patch puffy, lit where it meets a patch above or left, shaded below or right
    UPq = {"s": "f", "d": "s", "n": "d", "y": "b"}
    DNq = {"s": "d", "d": "n", "n": "n", "f": "s", "y": "o"}
    for y in range(21, 38):
        for x in range(w):
            c = O[y][x]
            if c not in UPq or c == "m": continue
            up = O[y - 1][x]; lf = O[y][x - 1]; dn = O[y + 1][x]; rt = O[y][x + 1]
            def diff(n): return n not in (c, ".", "k", "m", "a")
            def edge(n): return n in ".k"
            if diff(up) or diff(lf):
                g[y][x] = UPq[c]
            elif diff(dn) or diff(rt) or edge(rt) and x > 20:
                g[y][x] = DNq[c]
    return rows(g)

HANDS = {"tadzio": tadzio, "dad": dad, "curfew": curfew}

if __name__ == "__main__":
    write_game = "--write" in sys.argv
    Z = 12
    imgs = []
    for n, f in HANDS.items():
        o = orig(n)["down_0"]
        lines, fr, (fw, fh) = read(n)
        imgs.append((n, o, fr["down_0"], f(o), fw, fh))
        if write_game:
            ob = orig(n); pb = f(o)
            new = {k: (pb if k == "down_0" else carry(o, pb, rows_, paint)) for k, rows_ in ob.items()}
            write(n, new, "Painted: lit from the top left, rounded forms, a cool rim on the shadow side, cast shadows under heads and brims.")
    W = sum(fw * Z * 3 + 80 for *_, fw, fh in imgs)
    img = Image.new("RGBA", (W, 40 * Z + 70), (14, 14, 18, 255)); d = ImageDraw.Draw(img); x = 20
    for n, o, tool, hand, fw, fh in imgs:
        for j, (lab, r_) in enumerate((("now", o), ("tool", tool), ("hand-painted", hand))):
            xx = x + j * (fw * Z + 14)
            d.rounded_rectangle([xx - 4, 36, xx + fw * Z + 4, 44 + 40 * Z], 8, fill=P["n"])
            img.alpha_composite(draw(r_).resize((fw * Z, fh * Z), Image.NEAREST), (xx, 40 + 40 * Z - fh * Z))
            d.text((xx, 14), f"{n}: {lab}", fill=P["m"] if j == 2 else P["f"])
        x += fw * Z * 3 + 80
    img.save("hand3.png")
