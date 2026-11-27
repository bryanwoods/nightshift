"""Builds Wick's fire faces from his @fire portrait: one frame per feeling, each with a _b
twin whose flames lean the other way. The text box swaps the two so the fire flickers.
Run from the repo root: python3 docs/art/scripts/wick_fire_faces.py"""
import re
from pathlib import Path

PATH = Path("assets/px/portraits/wick.txt")
FEELINGS = ("shout", "sad", "hurt", "scared", "calm")


def frames(text):
    out, name = {}, None
    for line in text.splitlines():
        m = re.match(r"@(\w+)", line)
        if m:
            name = m.group(1)
            out[name] = []
        elif name and line.strip():
            out[name].append(list(line))
    return out


def put(g, cells, c):
    for (x, y) in cells:
        g[y][x] = c


def wipe_face(g):
    for y in range(11, 24):
        for x in range(7, 25):
            if g[y][x] not in "kd" and g[y][x] in "fkmelhq":
                g[y][x] = "f"
    for y in range(11, 24):
        row = "".join(g[y])
        first, last = row.find("k"), row.rfind("k")
        for x in range(first + 1, last):
            g[y][x] = "f"


def eyes(g, kind):
    for ex in (12, 19):
        if kind == "glow":
            put(g, [(ex, 14), (ex + 1, 14), (ex, 16), (ex + 1, 16)], "e")
            put(g, [(ex, 15), (ex + 1, 15)], "l")
            put(g, [(ex, 17), (ex + 1, 17)], "k")
        elif kind == "wide":
            put(g, [(ex, 13), (ex + 1, 13), (ex, 17), (ex + 1, 17)], "e")
            put(g, [(ex, 14), (ex + 1, 14), (ex, 16), (ex + 1, 16)], "l")
            put(g, [(ex, 15), (ex + 1, 15)], "m")
        elif kind == "droop":
            put(g, [(ex, 14), (ex + 1, 14)], "k")
            put(g, [(ex, 15), (ex + 1, 15)], "l")
            put(g, [(ex, 16), (ex + 1, 16)], "e")
        elif kind == "tiny":
            put(g, [(ex, 14), (ex + 1, 14), (ex, 16), (ex + 1, 16)], "m")
            put(g, [(ex, 15)], "m")
            put(g, [(ex + 1, 15)], "l")
        elif kind == "shut":
            put(g, [(ex - 1, 15), (ex, 16), (ex + 1, 16), (ex + 2, 15)], "k")


def brows(g, kind):
    if kind == "angry":
        put(g, [(10, 12), (11, 12), (12, 13), (13, 13), (14, 13)], "k")
        put(g, [(20, 12), (21, 12), (17, 13), (18, 13), (19, 13)], "k")
    elif kind == "sad":
        put(g, [(12, 12), (13, 12), (9, 13), (10, 13), (11, 13)], "k")
        put(g, [(18, 12), (19, 12), (20, 13), (21, 13), (22, 13)], "k")
    elif kind == "flat":
        put(g, [(x, 12) for x in range(10, 15)] + [(x, 12) for x in range(17, 22)], "k")
    elif kind == "high":
        put(g, [(10, 11), (11, 11), (12, 11), (13, 11), (18, 11), (19, 11), (20, 11), (21, 11)], "k")


def mouth(g, kind):
    if kind == "teeth":
        put(g, [(13, 20), (15, 20), (17, 20)], "k")
        put(g, [(14, 20), (16, 20), (18, 20)], "m")
        put(g, [(x, 21) for x in range(13, 19)], "k")
    elif kind == "open":
        put(g, [(x, 19) for x in range(13, 19)] + [(12, 20), (19, 20), (12, 21), (19, 21), (13, 22), (18, 22)], "k")
        put(g, [(x, 20) for x in range(13, 19)], "m")
        put(g, [(x, 21) for x in range(13, 19)] + [(x, 22) for x in range(14, 18)], "k")
        put(g, [(15, 22), (16, 22)], "h")
        put(g, [(x, 23) for x in range(14, 18)], "k")
    elif kind == "frown":
        put(g, [(x, 20) for x in range(14, 18)] + [(13, 21), (18, 21)], "k")
    elif kind == "flat":
        put(g, [(x, 20) for x in range(13, 19)], "k")
    elif kind == "o":
        put(g, [(15, 19), (16, 19), (14, 20), (17, 20), (14, 21), (17, 21), (15, 22), (16, 22)], "k")
    elif kind == "grit":
        put(g, [(13, 20), (14, 21), (15, 20), (16, 21), (17, 20), (18, 21)], "k")
        put(g, [(14, 20), (16, 20), (15, 21), (17, 21)], "m")


def flames(g, lean, small=False):
    for y in range(1, 6):
        for x in range(9, 23):
            if g[y][x] in "elm":
                g[y][x] = "D"
    shape = {
        0: [(15, 1, "e"), (16, 1, "e"), (14, 2, "e"), (15, 2, "e"), (16, 2, "l"), (17, 2, "e"),
            (13, 3, "e"), (14, 3, "l"), (15, 3, "l"), (16, 3, "l"), (17, 3, "l"), (18, 3, "e"),
            (13, 4, "e"), (14, 4, "l"), (15, 4, "m"), (16, 4, "m"), (17, 4, "l"), (18, 4, "e")],
        1: [(16, 1, "e"), (17, 1, "e"), (15, 2, "e"), (16, 2, "l"), (17, 2, "e"), (18, 2, "e"),
            (13, 3, "e"), (14, 3, "e"), (15, 3, "l"), (16, 3, "l"), (17, 3, "l"), (18, 3, "e"),
            (13, 4, "e"), (14, 4, "l"), (15, 4, "l"), (16, 4, "m"), (17, 4, "m"), (18, 4, "e")],
        -1: [(14, 1, "e"), (15, 1, "e"), (13, 2, "e"), (14, 2, "e"), (15, 2, "l"), (16, 2, "e"),
             (13, 3, "e"), (14, 3, "l"), (15, 3, "l"), (16, 3, "l"), (17, 3, "e"), (18, 3, "e"),
             (13, 4, "e"), (14, 4, "m"), (15, 4, "m"), (16, 4, "l"), (17, 4, "l"), (18, 4, "e")],
    }[lean]
    shape = shape + {0: [], 1: [(20, 2, "l"), (19, 1, "e")], -1: [(11, 2, "l"), (12, 1, "e")]}[lean]
    for x, y, c in shape:
        if small and y < 3:
            continue
        g[y][x] = {"m": "l", "l": "e", "e": "C"}[c] if small else c


LOOKS = {
    "fire": ("glow", "angry", "teeth"),
    "shout": ("wide", "angry", "open"),
    "sad": ("droop", "sad", "frown"),
    "hurt": ("shut", "angry", "grit"),
    "scared": ("tiny", "high", "o"),
    "calm": ("glow", "flat", "flat"),
}


def face(base, feeling, lean):
    g = [row[:] for row in base]
    e, b, m = LOOKS[feeling]
    if feeling != "fire":
        wipe_face(g)
        eyes(g, e)
        brows(g, b)
        mouth(g, m)
        if feeling == "sad":
            put(g, [(12, 17), (12, 18)], "q")
    flames(g, lean, small=feeling in ("sad", "scared"))
    return g


def main():
    text = PATH.read_text()
    fr = frames(text)
    base = fr["fire"]
    keep = re.split(r"\n(?=@fire\b)", text)[0].rstrip("\n")
    out = [keep]
    for feeling in ("fire",) + FEELINGS:
        name = "fire" if feeling == "fire" else f"fire_{feeling}"
        a = base if feeling == "fire" else face(base, feeling, 0)
        out.append(f"@{name}\n" + "\n".join("".join(r) for r in a))
        out.append(f"@{name}_b\n" + "\n".join("".join(r) for r in face(base, feeling, 1 if feeling != "scared" else -1)))
    PATH.write_text("\n".join(out) + "\n")


if __name__ == "__main__":
    main()
