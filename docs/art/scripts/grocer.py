"""Draws the Grocer in the painted style: lit from the top left, three or four shades on every
round form, a cool rim on the shadow side. Also his projectiles.
Run from the repo root: python3 docs/art/scripts/grocer.py"""
from pathlib import Path

MAT = {
    "skin": ("m", "m", "A", "B", "B"),
    "hat": ("x", "x", "u", "f", "f"),
    "band": ("F", "h", "h", "D", "D"),
    "shirt": ("x", "u", "f", "s", "f"),
    "apron": ("i", "w", "v", "n", "v"),
    "hair": ("o", "j", "j", "D", "D"),
    "pants": ("f", "s", "d", "n", "d"),
    "shoe": ("o", "j", "j", "k", "j"),
    "gun": ("f", "s", "d", "n", "d"),
}


class Canvas:
    def __init__(self, w, h):
        self.w, self.h = w, h
        self.g = [["." for _ in range(w)] for _ in range(h)]

    def px(self, x, y, c):
        if 0 <= x < self.w and 0 <= y < self.h:
            self.g[y][x] = c

    def shade(self, mat, x, y, cx, cy, rx, ry):
        hi, base, sh, deep, rim = MAT[mat]
        nx, ny = (x + 0.5 - cx) / rx, (y + 0.5 - cy) / ry
        d = -0.62 * nx - 0.78 * ny
        if nx > 0.8 and ny > -0.6:
            return rim if d > -0.9 else deep
        if d > 0.55:
            return hi
        if d > -0.15:
            return base
        if d > -0.75:
            return sh
        return deep

    def oval(self, mat, cx, cy, rx, ry):
        for y in range(int(cy - ry - 1), int(cy + ry + 2)):
            for x in range(int(cx - rx - 1), int(cx + rx + 2)):
                if ((x + 0.5 - cx) / rx) ** 2 + ((y + 0.5 - cy) / ry) ** 2 <= 1.0:
                    self.px(x, y, self.shade(mat, x, y, cx, cy, rx, ry))

    def box(self, mat, x0, y0, x1, y1):
        cx, cy, rx, ry = (x0 + x1 + 1) / 2, (y0 + y1 + 1) / 2, (x1 - x0 + 1) / 2, (y1 - y0 + 1) / 2
        for y in range(y0, y1 + 1):
            for x in range(x0, x1 + 1):
                self.px(x, y, self.shade(mat, x, y, cx, cy, rx * 1.15, ry * 1.15))

    def outline(self):
        out = [r[:] for r in self.g]
        for y in range(self.h):
            for x in range(self.w):
                if self.g[y][x] == ".":
                    for dx, dy in ((1, 0), (-1, 0), (0, 1), (0, -1)):
                        nx, ny = x + dx, y + dy
                        if 0 <= nx < self.w and 0 <= ny < self.h and self.g[ny][nx] not in ".k":
                            out[y][x] = "k"
                            break
        self.g = out

    def text(self):
        return "\n".join("".join(r) for r in self.g)


def battle(frame):
    c = Canvas(32, 64)
    lift = 3 if frame in (1, 3) else 0
    for x in range(8, 25):
        c.px(x, 63, "d")
    c.box("pants", 11, 53, 15, 59)
    c.box("pants", 17, 53, 21, 59)
    c.box("shoe", 10, 60, 15, 62)
    c.box("shoe", 17, 60, 22, 62)
    c.oval("shirt", 16, 43, 11, 11)
    c.box("shirt", 7, 31, 25, 40)
    c.box("shirt", 3, 33, 8, 44)
    c.box("shirt", 24, 30, 28, 36)
    c.box("shirt", 27, 23 - lift, 30, 31)
    c.oval("skin", 29, 20 - lift, 2.6, 2.8)
    c.box("skin", 3, 44, 7, 46)
    c.box("gun", 0, 45, 8, 48)
    c.box("gun", 4, 48, 6, 52)
    c.box("apron", 9, 35, 23, 55)
    c.box("apron", 10, 31, 11, 35)
    c.box("apron", 21, 31, 22, 35)
    c.box("skin", 13, 28, 19, 31)
    c.oval("skin", 4, 20, 2, 3)
    c.oval("skin", 28, 20, 2, 3)
    c.oval("skin", 16, 20, 11, 10.5)
    c.oval("hair", 6, 21, 2, 4)
    c.oval("hair", 26, 21, 2, 4)
    c.box("hat", 6, 8, 26, 13)
    c.box("hat", 9, 4, 23, 8)
    c.box("band", 6, 12, 26, 13)
    c.outline()
    for x in range(7, 26):
        c.px(x, 14, "A" if x < 20 else "B")
    for x in range(10, 23):
        c.px(x, 3, "k")
    for x, y in ((12, 17), (13, 17), (14, 18), (11, 16), (20, 17), (19, 17), (18, 18), (21, 16)):
        c.px(x, y, "j")
    for x, y in ((11, 17), (21, 17)):
        c.px(x, y, "o")
    for ex in (12, 19):
        c.px(ex, 19, "m"); c.px(ex + 1, 19, "k")
        c.px(ex, 20, "k"); c.px(ex + 1, 20, "k")
    c.px(12, 19, "x"); c.px(19, 19, "x")
    for x, y, col in ((15, 21, "A"), (16, 21, "A"), (17, 21, "B"), (15, 22, "m"), (16, 22, "A"), (17, 22, "B"), (15, 23, "A"), (16, 23, "B"), (17, 23, "B")):
        c.px(x, y, col)
    c.px(14, 22, "B")
    for x, y in ((9, 22), (10, 22), (22, 22), (23, 22)):
        c.px(x, y, "F")
    stache = ["....jjjjj.jjjjj....", "..ojjojjjjjjjojjo..", ".jjojjjjjjjjjjjojj.", "jjj.kjjj...jjjk.jjj", "j.....k.......k...j"]
    for r, row in enumerate(stache):
        for i, ch in enumerate(row):
            if ch != ".":
                c.px(7 + i, 23 + r, ch)
    for x in range(14, 19):
        c.px(x, 27, "k")
    c.px(13, 28, "k"); c.px(19, 28, "k")
    for x in range(13, 20):
        c.px(x, 30, "B")
    for x in range(9, 24):
        c.px(x, 35, "k")
    c.px(9, 35, "k")
    tags = [(12, 37, "y", "o"), (15, 36, "m", "h"), (18, 37, "y", "o")]
    for x, y, col, mark in tags:
        for dx in range(3):
            c.px(x + dx, y - 1, "k")
        for dy in range(4):
            c.px(x - 1, y + dy, "k"); c.px(x + 3, y + dy, "k")
            for dx in range(3):
                c.px(x + dx, y + dy, col)
        c.px(x + 1, y + 1, mark); c.px(x, y + 2, mark); c.px(x + 2, y + 2, mark)
    for x in range(11, 22):
        c.px(x, 41, "k"); c.px(x, 48, "w" if x % 2 else "v")
    for y in range(41, 49):
        c.px(11, y, "k"); c.px(21, y, "k")
    for y in range(42, 48):
        for x in range(12, 21):
            c.px(x, y, "w" if x < 15 and y < 45 else "v")
    for x in range(12, 21, 2):
        c.px(x, 42, "i")
    c.px(1, 46, "l"); c.px(0, 46, "l"); c.px(2, 45, "h"); c.px(3, 45, "h")
    for y in range(36, 55, 3):
        c.px(10, y, "i")
    if frame in (1, 3):
        for x, y in ((31, 15), (30, 13), (31, 11), (26, 14), (25, 13)):
            c.px(x, y, "l")
    if frame >= 2:
        for cx, cy in ((3, 6), (2, 3), (29, 6)):
            for x, y, col in ((cx, cy, "x"), (cx + 1, cy, "x"), (cx, cy - 1, "f"), (cx + 1, cy + 1, "f"), (cx - 1, cy, "f")):
                c.px(x, y, col)
    if frame == 3:
        for x in (7, 8, 23, 24, 25):
            c.px(x, 27, ".")
        for x, y in ((6, 25), (7, 24), (25, 24), (26, 25)):
            c.px(x, y, "j")
    return c.text()


def town(frame):
    big = [list(r) for r in battle(frame).split("\n")]
    c = Canvas(16, 32)
    for y in range(32):
        for x in range(16):
            block = [big[y * 2 + dy][x * 2 + dx] for dy in (0, 1) for dx in (0, 1)]
            filled = [b for b in block if b not in ".k"]
            if len(filled) >= 2:
                c.px(x, y, max(set(filled), key=filled.count))
            elif any(b == "k" for b in block) and filled:
                c.px(x, y, filled[0])
    c.outline()
    for x, y, col in ((5, 9, "j"), (6, 9, "j"), (10, 9, "j"), (9, 9, "j"), (6, 10, "k"), (10, 10, "k"), (8, 11, "A"),
                      (4, 12, "j"), (5, 12, "j"), (6, 12, "j"), (7, 12, "j"), (9, 12, "j"), (10, 12, "j"), (11, 12, "j"), (12, 12, "j"),
                      (7, 13, "k"), (8, 13, "k"), (9, 13, "k"), (5, 11, "F"), (11, 11, "F")):
        c.px(x, y, col)
    for x, y, col in ((7, 19, "y"), (8, 18, "m"), (9, 19, "y")):
        c.px(x, y, col)
    return c.text()


SP = Path("assets/px/sprites")
alias = "@down_2 = down_0\n@down_3 = down_1\n" + "".join(f"@{d}_{k} = down_{k % 2}\n" for d in ("up", "left", "right") for k in range(4))
paint = "# Painted: lit from the top left, rounded forms, a cool rim on the shadow side, cast shadows under heads and brims.\n"
(SP / "grocer_battle.txt").write_text("# grocer_battle 32x64\n# The Grocer: paper hat, bushy mustache, round belly, green apron with a pocket stuffed with stolen price tags, price gun and a shaking fist.\n"
    + paint + "# rules: viewpoint, outline, characters\n\n" + "".join(f"@idle_{i}\n{battle(i)}\n\n" for i in range(4)))
(SP / "grocer.txt").write_text("# grocer 16x32\n# The town sheet: grocer_battle at half size, with the face drawn again by hand.\n"
    + paint + "# rules: viewpoint, outline, characters\n\n" + f"@down_0\n{town(0)}\n\n@down_1\n{town(1)}\n\n" + alias)

for name, size, desc, rows in (
    ("price_tag", "10x13", "A stolen price tag on its string, painted cream with a red dollar mark.", [
        "....kk....", "...k..k...", "....kk....", "...kmmk...", "..kmxxmk..", ".kmxmkmmk.", "kmmmmmmmyk", "kmmhhhmmyk",
        "kmhmmmmmyk", "kmmhhhmmyk", "kmmmmhmmyk", "kmhhhmmyok", ".kkkkkkkk."]),
    ("cart", "14x12", "A runaway shopping cart full of groceries: bread, apples and lettuce.", [
        "hh............", ".hk.yy.hh.ww..", "..kkyykhhkwwkk", "..kxmxmxmxmxmk", "..kmfmfmfmfmfk", "...kxmxmxmxmk.",
        "...kmfmfmfmfk.", "....kkkkkkkk..", "....k......k..", "...kfk....kfk.", "...kkk....kkk.", ".............."]),
    ("can", "8x10", "A can of beans, rolling. A red label with a yellow bean on it.", [
        ".kkkkkk.", "kfxxxxfk", "kffffffk", "khmhhhhk", "kmmlmmhk", "kmlllmhk", "kmmlmmhk", "khhhhhDk", "kffffsdk", ".kkkkkk."]),
    ("sticker", "8x8", "A bright price sticker from the Grocer's price gun.", [
        "..kkkk..", ".kxlllk.", "kxlhhlyk", "klhlllyk", "kllhhlyk", "kllllhyk", ".kyhhyk.", "..kkkk.."]),
):
    (SP / f"{name}.txt").write_text(f"# {name} {size}\n# {desc}\n\n@sprite\n" + "\n".join(rows) + "\n")
