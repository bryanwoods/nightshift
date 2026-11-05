#!/usr/bin/env python3
"""Build every sprite, tile and portrait PNG from the text files in assets/px/.

One letter is one pixel. The letters come from data/palette.json, and "." is clear.
Run from the repo root:  uv run --with pillow python tools/compile_px.py

A file:
    # wick 16x32                 the first line: the name, then the frame size
    # anything                   a comment
    @down_0                      a frame; the next rows are its pixels, one row per line
    ....kkkk........
    @right_0 = flip left_0       the same pixels as another frame, mirrored left to right
    @down_2 = down_0             the same pixels as another frame

Blank lines between frames are fine. Where each file goes:
    assets/px/sprites/<name>.txt     -> assets/sprites/<name>.png (frames 4 across, in file order)
    assets/px/portraits/<name>.txt   -> assets/portraits/<name>_<frame>.png (one file a frame)
    assets/px/tiles/<tileset>/<tile>.txt, else assets/px/tiles/<tile>.txt
                                     -> assets/tiles/<tileset>.png (8 across, data/tilesets.json order)
Light gradients cannot be drawn with letters, so light_radial, light_cone and glow are made in code.
"""
import json
import math
import re
import sys
from pathlib import Path

from PIL import Image

ROOT = Path(__file__).resolve().parent.parent
PX = ROOT / "assets/px"
CLEAR = (0, 0, 0, 0)
HEADER = re.compile(r"^#\s*(\S+)\s+(\d+)x(\d+)\s*$")
FRAME = re.compile(r"^@(\S+)\s*(?:=\s*(flip\s+)?(\S+))?\s*$")


def palette():
    data = json.loads((ROOT / "data/palette.json").read_text())
    colors = {data.get("transparent", "."): CLEAR}
    for group in ("night", "morning"):
        for c in data[group].values():
            h = c["hex"].lstrip("#")
            colors[c["letter"]] = (int(h[0:2], 16), int(h[2:4], 16), int(h[4:6], 16), 255)
    return colors


def read(path, colors, errors):
    """Return (name, size, [(frame name, Image)]) or None. Every problem goes to errors as file:line."""
    rel = path.relative_to(ROOT)
    lines = path.read_text().splitlines()
    m = HEADER.match(lines[0]) if lines else None
    if not m:
        errors.append(f"{rel}:1: the first line must be like \"# door_closed 16x32\"")
        return None
    name, w, h = m.group(1), int(m.group(2)), int(m.group(3))
    frames, order = {}, []
    current, start = None, 0

    def close():
        if current is None or current in frames:
            return
        rows = current_rows
        if len(rows) != h:
            errors.append(f"{rel}:{start}: frame @{current} has {len(rows)} rows, it needs {h}")
            return
        img = Image.new("RGBA", (w, h), CLEAR)
        for y, (ln, row) in enumerate(rows):
            for x, ch in enumerate(row):
                img.putpixel((x, y), colors[ch])
        frames[current] = img

    current_rows = []
    for n, line in enumerate(lines[1:], start=2):
        text = line.rstrip()
        if text == "" or text.startswith("#"):
            continue
        fm = FRAME.match(text)
        if fm:
            close()
            current, start, current_rows = fm.group(1), n, []
            if current in order:
                errors.append(f"{rel}:{n}: frame @{current} is named twice")
            order.append(current)
            if fm.group(3):
                src = fm.group(3)
                if src not in frames:
                    errors.append(f"{rel}:{n}: @{current} copies @{src}, which is not above it")
                else:
                    img = frames[src]
                    frames[current] = img.transpose(Image.FLIP_LEFT_RIGHT) if fm.group(2) else img
            continue
        if current is None:
            errors.append(f"{rel}:{n}: pixels before the first @frame line")
            continue
        if current in frames:
            errors.append(f"{rel}:{n}: @{current} copies another frame, so it cannot have its own rows")
            continue
        bad = sorted({ch for ch in text if ch not in colors})
        if bad:
            errors.append(f"{rel}:{n}: letter {' '.join(repr(c) for c in bad)} is not in data/palette.json")
            continue
        if len(text) != w:
            errors.append(f"{rel}:{n}: row is {len(text)} wide, it needs {w}")
            continue
        current_rows.append((n, text))
    close()
    if not order:
        errors.append(f"{rel}:1: no @frame in this file")
    return name, (w, h), [(f, frames[f]) for f in order if f in frames]


def sheet(frames, w, h, across):
    cols = min(across, len(frames))
    rows = (len(frames) + across - 1) // across
    out = Image.new("RGBA", (cols * w, rows * h), CLEAR)
    for i, (_, img) in enumerate(frames):
        out.paste(img, ((i % across) * w, (i // across) * h))
    return out


def radial(size, color, bands, power):
    img = Image.new("RGBA", (size, size), CLEAR)
    c = (size - 1) / 2
    for y in range(size):
        for x in range(size):
            a = max(0.0, 1.0 - math.hypot(x - c, y - c) / (size / 2)) ** power
            img.putpixel((x, y), color[:3] + (int(255 * math.ceil(a * bands) / bands),))
    return img


def cone(size, length, spread_deg, bands):
    img = Image.new("RGBA", (size, size), CLEAR)
    half = math.radians(spread_deg / 2)
    for y in range(size):
        for x in range(size):
            dx, dy = x + 0.5, y + 0.5 - size / 2
            dist, ang = math.hypot(dx, dy), abs(math.atan2(dy, dx))
            if 0 < dist <= length and ang <= half:
                a = (1 - dist / length) * (1 - (ang / half) ** 2)
                img.putpixel((x, y), (255, 255, 255, int(255 * math.ceil(a * bands) / bands)))
    return img


def warm(img, hot):
    """True if two touching pixels are lamp or moon: the "warm" art rule."""
    w, h = img.size
    px = img.load()
    return any(px[x, y] in hot and ((x + 1 < w and px[x + 1, y] in hot) or (y + 1 < h and px[x, y + 1] in hot))
               for y in range(h) for x in range(w))


def touchable(tiles, sprites, hot, errors):
    """Every interactable shows a lamp or moon cluster. A multi-tile door is an edge exit, and a false wall is a secret."""
    for path in sorted((ROOT / "data/rooms").glob("*.json")):
        room = json.loads(path.read_text())
        layout, legend = room["layout"], room["legend"]
        swaps = {(o["x"], o["y"]): o["tile"] for o in room.get("overrides", [])}
        for e in room.get("entities", []):
            kind, w, h = e.get("type"), e.get("w", 1), e.get("h", 1)
            if kind in ("npc", "encounter"):
                name = e.get("sprite", e.get("id", e.get("worker")))
                shown = [f"sprite {name}"]
                ok = name in sprites and warm(sprites[name], hot)
            elif kind in ("inspect", "lamp", "hold") or (kind == "door" and w * h == 1):
                cells = [(e["x"] + i, e["y"] + j) for i in range(w) for j in range(h)]
                names = {legend.get(layout[y][x]) for x, y in cells if y < len(layout) and x < len(layout[y])}
                names |= {swaps[c] for c in cells if c in swaps}
                shown = sorted(f"tile {n}" for n in names if n)
                ok = any(warm(tiles.get(room["tileset"], {})[n], hot) for n in names if n in tiles.get(room["tileset"], {}))
            else:
                continue
            if not ok:
                errors.append(f"{path.relative_to(ROOT)}: {kind} at {e['x']},{e['y']} ({', '.join(shown)}) has no lamp or moon cluster (SPEC.md Art, warm)")


def main():
    colors = palette()
    errors, out = [], {}
    tiles, sprites = {}, {}
    for path in sorted((PX / "sprites").glob("*.txt")):
        r = read(path, colors, errors)
        if r and r[2]:
            out[ROOT / f"assets/sprites/{r[0]}.png"] = sheet(r[2], *r[1], across=4)
            sprites[r[0]] = r[2][0][1]
    for path in sorted((PX / "portraits").glob("*.txt")):
        r = read(path, colors, errors)
        for frame, img in (r[2] if r else []):
            out[ROOT / f"assets/portraits/{r[0]}_{frame}.png"] = img
    tilesets = json.loads((ROOT / "data/tilesets.json").read_text())["tilesets"]
    for ts, info in tilesets.items():
        for tile in info["tiles"]:
            path = next((p for p in (PX / "tiles" / ts / f"{tile}.txt", PX / "tiles" / f"{tile}.txt") if p.exists()), None)
            if path is None:
                errors.append(f"data/tilesets.json: tileset {ts} needs assets/px/tiles/{ts}/{tile}.txt or assets/px/tiles/{tile}.txt")
                continue
            r = read(path, colors, errors)
            if r and r[1] != (16, 16):
                errors.append(f"{path.relative_to(ROOT)}:1: a tile is 16x16, this one is {r[1][0]}x{r[1][1]}")
            elif r and r[2]:
                tiles.setdefault(ts, {})[tile] = r[2][0][1]
        if len(tiles.get(ts, {})) == len(info["tiles"]):
            out[ROOT / info["png"].replace("res://", "")] = sheet(list(tiles[ts].items()), 16, 16, across=8)
    touchable(tiles, sprites, {colors["l"], colors["m"]}, errors)
    if errors:
        print("\n".join(errors), file=sys.stderr)
        print(f"{len(errors)} problem(s). Nothing was written.", file=sys.stderr)
        sys.exit(1)
    moon = colors["m"]
    out[ROOT / "assets/sprites/glow.png"] = radial(24, moon, bands=4, power=1.5)
    out[ROOT / "assets/sprites/light_radial.png"] = radial(64, (255, 255, 255), bands=4, power=0.8)
    out[ROOT / "assets/sprites/light_cone.png"] = cone(64, 56, 60, bands=4)
    for path, img in out.items():
        path.parent.mkdir(parents=True, exist_ok=True)
        img.save(path)
    print(f"wrote {len(out)} PNGs")


if __name__ == "__main__":
    main()
