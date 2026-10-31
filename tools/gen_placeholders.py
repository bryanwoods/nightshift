#!/usr/bin/env python3
"""Generate every placeholder sprite, tile, portrait, sfx and music loop.

Colors come from data/palette.json. Tile lists come from data/tilesets.json.
Run from the repo root:  uv run --with pillow python tools/gen_placeholders.py
Real art replaces these files one by one. Keep the sheet layouts the same.
"""
import array
import json
import math
import random
import shutil
import subprocess
import wave
from pathlib import Path

from PIL import Image, ImageDraw

ROOT = Path(__file__).resolve().parent.parent
PALETTE = json.loads((ROOT / "data/palette.json").read_text())
TILESETS = json.loads((ROOT / "data/tilesets.json").read_text())["tilesets"]


def rgb(h):
    h = h.lstrip("#")
    return (int(h[0:2], 16), int(h[2:4], 16), int(h[4:6], 16), 255)


N = {k: rgb(v) for k, v in PALETTE["night"].items()}
M = {k: rgb(v) for k, v in PALETTE["morning"].items()}
CLEAR = (0, 0, 0, 0)

ROLES = {
    "night": dict(outline=N["ink"], wall_top=N["ink"], wall=N["dusk"], wall_line=N["night"],
                  floor=N["night"], floor_line=N["ink"], wood=N["dusk"], wood_hi=N["slate"],
                  cloth=N["slate"], cloth_hi=N["fog"], glass=N["night"], glass_hi=N["fog"],
                  hi=N["fog"], text=N["moon"], warm=N["lamp"], hot=N["ember"], red=N["hush"],
                  green=N["slate"], metal=N["fog"], ground=N["night"], ground_hi=N["dusk"],
                  stone=N["slate"], stone_line=N["dusk"], clock_text="1:59"),
    "morning": dict(outline=M["bark"], wall_top=M["bark"], wall=M["butter"], wall_line=M["cream"],
                    floor=M["cream"], floor_line=M["butter"], wood=M["bark"], wood_hi=M["butter"],
                    cloth=M["sky"], cloth_hi=M["white"], glass=M["sky"], glass_hi=M["white"],
                    hi=M["white"], text=M["bark"], warm=M["butter"], hot=M["bark"], red=M["bark"],
                    green=M["leaf"], metal=M["white"], ground=M["leaf"], ground_hi=M["cream"],
                    stone=M["cream"], stone_line=M["butter"], clock_text="7:02"),
}

# 3x5 pixel glyphs for clock digits and chest letters.
GLYPHS = {
    "0": ["111", "101", "101", "101", "111"], "1": ["010", "110", "010", "010", "111"],
    "2": ["111", "001", "111", "100", "111"], "3": ["111", "001", "011", "001", "111"],
    "4": ["101", "101", "111", "001", "001"], "5": ["111", "100", "111", "001", "111"],
    "6": ["111", "100", "111", "101", "111"], "7": ["111", "001", "010", "010", "010"],
    "8": ["111", "101", "111", "101", "111"], "9": ["111", "101", "111", "001", "111"],
    ":": ["0", "1", "0", "1", "0"],
    "T": ["111", "010", "010", "010", "010"], "W": ["101", "101", "101", "111", "101"],
    "U": ["101", "101", "101", "101", "111"], "P": ["111", "101", "111", "100", "100"],
    "F": ["111", "100", "110", "100", "100"], "C": ["111", "100", "100", "100", "111"],
    "?": ["111", "001", "011", "000", "010"],
}


def glyph_text(d, x, y, text, color):
    for ch in text:
        g = GLYPHS[ch]
        for gy, row in enumerate(g):
            for gx, bit in enumerate(row):
                if bit == "1":
                    d.point((x + gx, y + gy), fill=color)
        x += len(g[0]) + 1


def R(d, x0, y0, x1, y1, c):
    d.rectangle([x0, y0, x1, y1], fill=c)


def outline(img, color=N["ink"]):
    """Add a one-pixel outline around every opaque pixel."""
    w, h = img.size
    src = img.load()
    out = img.copy()
    dst = out.load()
    for y in range(h):
        for x in range(w):
            if src[x, y][3] != 0:
                continue
            for dx, dy in ((1, 0), (-1, 0), (0, 1), (0, -1)):
                nx, ny = x + dx, y + dy
                if 0 <= nx < w and 0 <= ny < h and src[nx, ny][3] != 0 and src[nx, ny] != color:
                    dst[x, y] = color
                    break
    return out


# ---------------------------------------------------------------- tiles

def t_wall(d, r):
    R(d, 0, 0, 15, 15, r["wall_top"])
    for x in range(0, 16, 4):
        d.point((x + 1, 7), fill=r["wall_line"])


def t_wall_face(d, r):
    R(d, 0, 0, 15, 15, r["wall"])
    for x in range(1, 16, 4):
        d.line([(x, 1), (x, 12)], fill=r["wall_line"])
    R(d, 0, 0, 15, 0, r["outline"])
    R(d, 0, 13, 15, 15, r["wood"])
    R(d, 0, 13, 15, 13, r["wood_hi"])


def t_floor(d, r):
    R(d, 0, 0, 15, 15, r["floor"])
    for y in (3, 7, 11, 15):
        d.line([(0, y), (15, y)], fill=r["floor_line"])
    for x, y in ((5, 0), (12, 4), (2, 8), (9, 12)):
        d.line([(x, y), (x, y + 2)], fill=r["floor_line"])


def t_rug(d, r):
    R(d, 0, 0, 15, 15, r["cloth"])
    d.rectangle([1, 1, 14, 14], outline=r["cloth_hi"])
    d.polygon([(8, 4), (12, 8), (8, 12), (4, 8)], outline=r["cloth_hi"])


def t_bed_head(d, r):
    t_floor(d, r)
    R(d, 1, 0, 14, 15, r["wood"])
    R(d, 3, 2, 12, 6, r["hi"])
    R(d, 2, 8, 13, 15, r["cloth"])
    d.line([(2, 8), (13, 8)], fill=r["cloth_hi"])


def t_bed_foot(d, r):
    t_floor(d, r)
    R(d, 1, 0, 14, 15, r["wood"])
    R(d, 2, 0, 13, 12, r["cloth"])
    for x in (4, 8, 12):
        d.point((x, 5), fill=r["cloth_hi"])
    R(d, 1, 13, 14, 15, r["wood_hi"])


def t_desk(d, r):
    t_floor(d, r)
    R(d, 0, 2, 15, 9, r["wood_hi"])
    R(d, 0, 10, 15, 13, r["wood"])
    R(d, 1, 14, 2, 15, r["wood"])
    R(d, 13, 14, 14, 15, r["wood"])


def t_clock_radio(d, r):
    t_desk(d, r)
    R(d, 1, 1, 14, 8, r["outline"])
    glyph_text(d, 2, 2, r["clock_text"], r["hot"])


def t_window(d, r):
    t_wall_face(d, r)
    R(d, 3, 2, 12, 11, r["wood_hi"])
    R(d, 4, 3, 11, 10, r["glass"])
    d.line([(7, 3), (7, 10)], fill=r["wood_hi"])
    d.line([(4, 6), (11, 6)], fill=r["wood_hi"])
    d.point((10, 4), fill=r["glass_hi"])


def t_drawing(d, r):
    t_wall_face(d, r)
    R(d, 3, 2, 12, 10, r["text"])
    # TODO(Tadzio): the real drawing replaces this scribble.
    d.line([(4, 8), (6, 5), (8, 8), (10, 4)], fill=r["red"])
    d.point((5, 3), fill=r["warm"])
    d.point((11, 3), fill=r["warm"])


def t_closet(d, r):
    t_wall_face(d, r)
    R(d, 1, 1, 14, 15, r["wood"])
    d.line([(7, 1), (7, 15)], fill=r["outline"])
    d.point((6, 8), fill=r["hi"])
    d.point((9, 8), fill=r["hi"])


def t_door(d, r):
    R(d, 0, 0, 15, 15, r["floor"])
    R(d, 1, 0, 14, 15, r["wood_hi"])
    R(d, 3, 0, 12, 15, r["outline"])


def t_door_closed(d, r):
    t_wall_face(d, r)
    R(d, 3, 1, 12, 15, r["wood"])
    d.rectangle([4, 2, 11, 7], outline=r["wood_hi"])
    d.rectangle([4, 9, 11, 14], outline=r["wood_hi"])
    d.point((10, 8), fill=r["hi"])


def t_stairs(d, r):
    R(d, 0, 0, 15, 15, r["wood_hi"])
    for y in range(2, 16, 4):
        d.line([(0, y), (15, y)], fill=r["outline"])
        d.line([(0, y + 1), (15, y + 1)], fill=r["wood"])


def t_counter(d, r):
    R(d, 0, 0, 15, 15, r["wood"])
    R(d, 0, 0, 15, 4, r["hi"])
    d.line([(0, 5), (15, 5)], fill=r["outline"])
    d.line([(7, 6), (7, 15)], fill=r["outline"])
    d.point((5, 9), fill=r["hi"])
    d.point((10, 9), fill=r["hi"])


def t_stove(d, r):
    t_counter(d, r)
    d.ellipse([2, 0, 6, 4], outline=r["outline"])
    d.ellipse([9, 0, 13, 4], outline=r["outline"])


def t_fridge(d, r):
    R(d, 0, 0, 15, 15, r["wall"])
    R(d, 2, 0, 13, 15, r["hi"])
    d.rectangle([2, 0, 13, 15], outline=r["outline"])
    d.line([(2, 6), (13, 6)], fill=r["outline"])
    d.line([(11, 2), (11, 4)], fill=r["outline"])
    d.line([(11, 8), (11, 12)], fill=r["outline"])


def t_table(d, r):
    t_floor(d, r)
    d.ellipse([1, 2, 14, 13], fill=r["wood_hi"], outline=r["outline"])


def t_chair(d, r):
    t_floor(d, r)
    R(d, 4, 3, 11, 12, r["wood"])
    R(d, 4, 3, 11, 5, r["wood_hi"])


def t_tile_floor(d, r):
    for y in range(0, 16, 4):
        for x in range(0, 16, 4):
            R(d, x, y, x + 3, y + 3, r["floor"] if (x + y) // 4 % 2 == 0 else r["wall_line"] if r["wall_line"] != r["floor"] else r["floor_line"])


def t_nightstand(d, r):
    t_floor(d, r)
    R(d, 2, 3, 13, 15, r["wood"])
    R(d, 2, 3, 13, 5, r["wood_hi"])
    d.point((7, 10), fill=r["hi"])


def t_nightstand_card(d, r):
    t_nightstand(d, r)
    R(d, 4, 1, 11, 5, r["hi"])
    d.line([(5, 3), (10, 3)], fill=r["outline"])


def t_plant(d, r):
    t_floor(d, r)
    R(d, 5, 10, 10, 15, r["hot"])
    d.ellipse([3, 2, 12, 11], fill=r["green"], outline=r["outline"])


def t_shelf(d, r):
    t_wall_face(d, r)
    R(d, 1, 1, 14, 15, r["wood"])
    for y in (5, 10, 15):
        d.line([(1, y), (14, y)], fill=r["wood_hi"])
    for i, x in enumerate(range(2, 14, 2)):
        R(d, x, 2 + (i % 2), x, 4, [r["red"], r["cloth"], r["warm"], r["hi"]][i % 4])
        R(d, x, 7 + (i % 2), x, 9, [r["cloth"], r["hi"], r["red"], r["warm"]][i % 4])


def t_railing(d, r):
    t_floor(d, r)
    d.line([(0, 4), (15, 4)], fill=r["wood_hi"])
    for x in range(1, 16, 3):
        d.line([(x, 5), (x, 11)], fill=r["wood"])
    d.line([(0, 12), (15, 12)], fill=r["wood_hi"])


def t_sink(d, r):
    t_counter(d, r)
    R(d, 3, 0, 12, 3, r["metal"])
    R(d, 4, 1, 11, 3, r["outline"])


def t_roof(d, r):
    R(d, 0, 0, 15, 15, r["outline"])
    for y in range(1, 16, 4):
        off = 0 if (y // 4) % 2 == 0 else 4
        for x in range(off, 16, 8):
            d.line([(x, y), (x + 5, y)], fill=r["floor"])


def t_house_wall(d, r):
    R(d, 0, 0, 15, 15, r["wall"])
    for y in range(2, 16, 3):
        d.line([(0, y), (15, y)], fill=r["wall_line"])


def t_house_window(d, r):
    t_house_wall(d, r)
    R(d, 3, 3, 12, 12, r["wood_hi"])
    R(d, 4, 4, 11, 11, r["glass"])
    d.line([(7, 4), (7, 11)], fill=r["wood_hi"])


def t_house_door(d, r):
    t_house_wall(d, r)
    R(d, 4, 2, 11, 15, r["wood"])
    d.point((10, 9), fill=r["hi"])


def t_sidewalk(d, r):
    R(d, 0, 0, 15, 15, r["stone"])
    d.line([(0, 0), (15, 0)], fill=r["stone_line"])
    d.line([(0, 0), (0, 15)], fill=r["stone_line"])
    d.point((9, 6), fill=r["stone_line"])


def t_road(d, r):
    R(d, 0, 0, 15, 15, r["wall"])
    for x, y in ((3, 4), (11, 2), (7, 10), (13, 13), (1, 13)):
        d.point((x, y), fill=r["stone_line"] if r["stone_line"] != r["wall"] else r["floor"])


def t_road_line(d, r):
    t_road(d, r)
    R(d, 2, 7, 13, 8, r["text"])


def t_grass(d, r):
    R(d, 0, 0, 15, 15, r["ground"])
    for x, y in ((2, 3), (9, 1), (13, 7), (5, 10), (11, 13), (1, 14)):
        d.line([(x, y), (x, y + 1)], fill=r["ground_hi"])
        d.point((x + 1, y), fill=r["ground_hi"])


def t_hedge(d, r):
    R(d, 0, 0, 15, 15, r["outline"])
    for cx, cy in ((4, 5), (11, 4), (7, 11), (13, 12), (2, 12)):
        d.ellipse([cx - 4, cy - 4, cx + 3, cy + 3], fill=r["ground_hi"])


def t_tree(d, r):
    t_grass(d, r)
    R(d, 7, 10, 8, 15, r["wood"])
    d.ellipse([1, 0, 14, 12], fill=r["ground_hi"], outline=r["outline"])
    d.point((5, 4), fill=r["wood_hi"])


def t_fence(d, r):
    t_grass(d, r)
    for x in (1, 5, 9, 13):
        R(d, x, 2, x + 2, 14, r["hi"])
        d.point((x + 1, 1), fill=r["hi"])
    d.line([(0, 5), (15, 5)], fill=r["wood_hi"])
    d.line([(0, 11), (15, 11)], fill=r["wood_hi"])


def t_gate(d, r):
    t_grass(d, r)
    R(d, 4, 0, 11, 15, r["wood"])
    R(d, 0, 2, 2, 14, r["hi"])
    R(d, 13, 2, 15, 14, r["hi"])


def t_lamp_post(d, r):
    t_sidewalk(d, r)
    R(d, 7, 5, 8, 15, r["metal"])
    R(d, 5, 1, 10, 4, r["outline"])
    R(d, 6, 2, 9, 3, r["hi"])
    R(d, 5, 14, 10, 15, r["outline"])


def t_mailbox(d, r):
    t_sidewalk(d, r)
    R(d, 3, 2, 12, 14, r["wall"])
    R(d, 3, 2, 12, 4, r["red"])
    R(d, 5, 7, 10, 7, r["outline"])


def t_bench(d, r):
    t_sidewalk(d, r)
    for y in (5, 8, 11):
        R(d, 1, y, 14, y + 1, r["wood_hi"])
    R(d, 2, 13, 3, 15, r["wood"])
    R(d, 12, 13, 13, 15, r["wood"])


def t_shop_wall(d, r):
    R(d, 0, 0, 15, 15, r["wall"])
    for y in range(3, 16, 4):
        d.line([(0, y), (15, y)], fill=r["wall_line"])
        off = 0 if (y // 4) % 2 else 4
        for x in range(off, 16, 8):
            d.line([(x, y - 3), (x, y - 1)], fill=r["wall_line"])


def t_shop_window_lit(d, r):
    t_shop_wall(d, r)
    R(d, 1, 3, 14, 14, r["outline"])
    R(d, 2, 4, 13, 13, r["warm"])
    d.line([(2, 9), (13, 9)], fill=r["hot"])
    d.ellipse([4, 5, 8, 8], fill=r["hot"])


def t_shop_window(d, r):
    t_shop_wall(d, r)
    R(d, 1, 3, 14, 14, r["outline"])
    R(d, 2, 4, 13, 13, r["glass"])
    d.point((11, 5), fill=r["glass_hi"])


def t_bakery_door(d, r):
    t_shop_wall(d, r)
    R(d, 3, 2, 12, 15, r["wood"])
    R(d, 5, 4, 10, 8, r["warm"])
    d.point((10, 11), fill=r["hi"])


def t_bakery_sign(d, r):
    t_shop_wall(d, r)
    R(d, 1, 4, 14, 11, r["text"])
    d.ellipse([4, 5, 11, 10], fill=r["warm"], outline=r["hot"])


def t_cobble(d, r):
    R(d, 0, 0, 15, 15, r["stone_line"])
    for cx, cy in ((3, 3), (11, 3), (7, 8), (3, 13), (12, 12)):
        d.ellipse([cx - 3, cy - 2, cx + 3, cy + 2], fill=r["stone"])


def t_tower(d, r):
    R(d, 0, 0, 15, 15, r["wall"])
    for y in range(3, 16, 4):
        d.line([(0, y), (15, y)], fill=r["outline"])
    R(d, 0, 0, 0, 15, r["outline"])
    R(d, 15, 0, 15, 15, r["outline"])


def t_tower_face(d, r):
    t_tower(d, r)
    d.ellipse([1, 1, 14, 14], fill=r["text"], outline=r["outline"])
    d.line([(7, 7), (7, 2)], fill=r["outline"])
    d.line([(7, 7), (10, 5)], fill=r["outline"])


def t_fountain(d, r):
    t_cobble(d, r)
    d.ellipse([1, 2, 14, 14], fill=r["hi"], outline=r["outline"])
    d.ellipse([3, 4, 12, 12], fill=r["glass"])
    d.point((7, 7), fill=r["glass_hi"])


def t_depot_wall(d, r):
    R(d, 0, 0, 15, 15, r["wall"])
    for x in range(0, 16, 2):
        d.line([(x, 0), (x, 15)], fill=r["wall_line"])


def t_rolling_door(d, r):
    R(d, 0, 0, 15, 15, r["stone"])
    for y in range(0, 16, 3):
        d.line([(0, y), (15, y)], fill=r["stone_line"])
    R(d, 0, 15, 15, 15, r["outline"])


def t_side_door(d, r):
    t_depot_wall(d, r)
    R(d, 3, 1, 12, 15, r["wood_hi"])
    R(d, 4, 2, 11, 15, r["outline"])


def t_side_door_closed(d, r):
    t_depot_wall(d, r)
    R(d, 3, 1, 12, 15, r["wood"])
    R(d, 5, 3, 10, 6, r["glass"])
    d.point((10, 9), fill=r["hi"])


def t_punch_clock(d, r):
    t_depot_wall(d, r)
    R(d, 3, 2, 12, 13, r["metal"])
    d.ellipse([5, 3, 10, 8], fill=r["text"], outline=r["outline"])
    R(d, 5, 10, 10, 11, r["outline"])


def t_crate(d, r):
    R(d, 0, 0, 15, 15, r["wood"])
    d.rectangle([0, 0, 15, 15], outline=r["outline"])
    d.line([(1, 1), (14, 14)], fill=r["wood_hi"])
    d.line([(14, 1), (1, 14)], fill=r["wood_hi"])


def t_flowerbed(d, r):
    R(d, 0, 0, 15, 15, r["outline"])
    R(d, 1, 1, 14, 14, r["ground"])
    for i, (x, y) in enumerate(((3, 4), (8, 3), (12, 6), (5, 10), (10, 11))):
        d.point((x, y), fill=[r["red"], r["warm"], r["text"]][i % 3])


def t_ladder_broken(d, r):
    t_sidewalk(d, r)
    d.line([(2, 12), (9, 5)], fill=r["wood_hi"])
    d.line([(4, 14), (11, 7)], fill=r["wood_hi"])
    for i in range(3):
        d.line([(3 + 2 * i, 11 - 2 * i), (5 + 2 * i, 13 - 2 * i)], fill=r["wood"])
    d.line([(12, 12), (14, 10)], fill=r["wood_hi"])


def t_path(d, r):
    R(d, 0, 0, 15, 15, r["ground_hi"])
    for x, y in ((3, 2), (10, 5), (6, 11), (13, 13)):
        d.point((x, y), fill=r["stone"])


def t_back_door(d, r):
    t_house_wall(d, r)
    R(d, 3, 1, 12, 15, r["wood_hi"])
    R(d, 4, 2, 11, 15, r["outline"])


def t_porch(d, r):
    R(d, 0, 0, 15, 15, r["wood"])
    for y in range(0, 16, 4):
        d.line([(0, y), (15, y)], fill=r["outline"])


def t_concrete(d, r):
    R(d, 0, 0, 15, 15, r["wall"])
    for x, y in ((2, 3), (12, 2), (7, 9), (13, 13), (3, 12)):
        d.point((x, y), fill=r["wall_line"])


def t_floor_line(d, r):
    t_concrete(d, r)
    R(d, 0, 7, 15, 8, r["warm"])


def t_board(d, r):
    t_depot_face(d, r)
    R(d, 0, 1, 15, 12, r["wood_hi"])
    for x, y in ((1, 2), (6, 3), (11, 2), (3, 7), (9, 7)):
        R(d, x, y, x + 3, y + 3, r["text"])
        d.point((x + 1, y), fill=r["red"])


def t_depot_face(d, r):
    R(d, 0, 0, 15, 15, r["wall"])
    for x in range(0, 16, 2):
        d.line([(x, 0), (x, 12)], fill=r["wall_line"])
    R(d, 0, 13, 15, 15, r["outline"])


def t_bin(d, r):
    t_concrete(d, r)
    R(d, 1, 3, 14, 15, r["metal"])
    R(d, 1, 3, 14, 5, r["text"])
    R(d, 3, 6, 12, 14, r["outline"])
    d.point((8, 7), fill=N["wake"])


def t_timecards(d, r):
    t_depot_face(d, r)
    R(d, 1, 1, 14, 12, r["outline"])
    for x in range(2, 14, 3):
        R(d, x, 2, x + 1, 5, r["text"])
        R(d, x, 7, x + 1, 10, r["text"])


def t_desk_big(d, r):
    t_concrete(d, r)
    R(d, 0, 2, 15, 13, r["wood_hi"])
    R(d, 0, 10, 15, 13, r["wood"])


def t_locker(d, r):
    R(d, 0, 0, 15, 15, r["metal"])
    d.rectangle([0, 0, 15, 15], outline=r["outline"])
    d.line([(7, 0), (7, 15)], fill=r["outline"])
    for y in (3, 5):
        d.line([(2, y), (5, y)], fill=r["outline"])
        d.line([(10, y), (13, y)], fill=r["outline"])


def t_depot_window(d, r):
    t_depot_face(d, r)
    R(d, 2, 2, 13, 10, r["outline"])
    R(d, 3, 3, 12, 9, r["glass"])
    d.point((11, 4), fill=r["glass_hi"])


TILES = {
    "wall": t_wall, "wall_face": t_wall_face, "floor": t_floor, "rug": t_rug, "bed_head": t_bed_head,
    "bed_foot": t_bed_foot, "desk": t_desk, "clock_radio": t_clock_radio, "window": t_window,
    "drawing": t_drawing, "closet": t_closet, "door": t_door, "door_closed": t_door_closed,
    "stairs": t_stairs, "counter": t_counter, "stove": t_stove, "fridge": t_fridge, "table": t_table,
    "chair": t_chair, "tile_floor": t_tile_floor, "nightstand": t_nightstand,
    "nightstand_card": t_nightstand_card, "plant": t_plant, "shelf": t_shelf, "railing": t_railing,
    "sink": t_sink, "roof": t_roof, "house_wall": t_house_wall, "house_window": t_house_window,
    "house_door": t_house_door, "sidewalk": t_sidewalk, "road": t_road, "road_line": t_road_line,
    "grass": t_grass, "hedge": t_hedge, "tree": t_tree, "fence": t_fence, "gate": t_gate,
    "lamp_post": t_lamp_post, "mailbox": t_mailbox, "bench": t_bench, "shop_wall": t_shop_wall,
    "shop_window_lit": t_shop_window_lit, "shop_window": t_shop_window, "bakery_door": t_bakery_door,
    "bakery_sign": t_bakery_sign, "cobble": t_cobble, "tower": t_tower, "tower_face": t_tower_face,
    "fountain": t_fountain, "depot_wall": t_depot_wall, "rolling_door": t_rolling_door,
    "side_door": t_side_door, "side_door_closed": t_side_door_closed, "punch_clock": t_punch_clock,
    "crate": t_crate, "flowerbed": t_flowerbed, "ladder_broken": t_ladder_broken, "path": t_path,
    "back_door": t_back_door, "porch": t_porch, "concrete": t_concrete, "floor_line": t_floor_line,
    "board": t_board, "bin": t_bin, "timecards": t_timecards, "desk_big": t_desk_big, "locker": t_locker,
}
DEPOT_OVERRIDES = {"wall_face": t_depot_face, "window": t_depot_window, "door": t_door}


def gen_tiles():
    for name, ts in TILESETS.items():
        roles = ROLES["morning" if "morning" in name else "night"]
        tiles = ts["tiles"]
        cols = 8
        rows = (len(tiles) + cols - 1) // cols
        img = Image.new("RGBA", (cols * 16, rows * 16), CLEAR)
        for i, tile in enumerate(tiles):
            t = Image.new("RGBA", (16, 16), roles["floor"])
            d = ImageDraw.Draw(t)
            fn = (DEPOT_OVERRIDES.get(tile) if name.startswith("depot") else None) or TILES.get(tile)
            if fn:
                fn(d, roles)
            else:
                R(d, 0, 0, 15, 15, roles["red"])
            img.paste(t, ((i % cols) * 16, (i // cols) * 16))
        out = ROOT / ts["png"].replace("res://", "")
        out.parent.mkdir(parents=True, exist_ok=True)
        img.save(out)


# ---------------------------------------------------------------- characters

def humanoid(d, facing, f, c, w=16):
    """Draw a 16x32 person. c holds colors and feature switches."""
    bob = 1 if f in (1, 3) else 0
    top = c.get("top", 5)
    # legs
    if facing in ("down", "up"):
        ll = 29 if f == 1 else 30
        rl = 29 if f == 3 else 30
        R(dr := d, 5, 25, 7, ll, c["legs"])
        R(dr, 8, 25, 10, rl, c["legs"])
        R(dr, 5, ll, 7, ll, c.get("feet", c["legs"]))
        R(dr, 8, rl, 10, rl, c.get("feet", c["legs"]))
    else:
        if f in (1, 3):
            R(d, 4, 25, 6, 30, c["legs"])
            R(d, 8, 25, 10, 30, c["legs"])
        else:
            R(d, 6, 25, 8, 30, c["legs"])
    # body
    body_bottom = c.get("body_bottom", 25)
    R(d, 4, 14 + bob, 11, body_bottom, c["body"])
    if c.get("stripes"):
        for y in range(16 + bob, body_bottom, 3):
            d.line([(4, y), (11, y)], fill=c["stripes"])
    if c.get("apron") and facing != "up":
        R(d, 5, 16 + bob, 10, body_bottom, c["apron"])
    # arms
    if facing in ("down", "up"):
        R(d, 3, 15 + bob, 3, 21 + bob, c.get("arms", c["body"]))
        R(d, 12, 15 + bob, 12, 21 + bob, c.get("arms", c["body"]))
    else:
        swing = {1: -1, 3: 1}.get(f, 0)
        R(d, 7 + swing, 16 + bob, 8 + swing, 21 + bob, c.get("arms", c["body"]))
    # head
    hw = c.get("head_w", 8)
    hx0 = 8 - hw // 2
    d.ellipse([hx0, top + bob, hx0 + hw - 1, top + 9 + bob], fill=c["head"])
    if c.get("hair"):
        if facing == "up":
            d.ellipse([hx0, top + bob, hx0 + hw - 1, top + 9 + bob], fill=c["hair"])
        else:
            R(d, hx0 + 1, top + bob, hx0 + hw - 2, top + 2 + bob, c["hair"])
    if c.get("hat"):
        R(d, hx0, top - 4 + bob, hx0 + hw - 1, top + 1 + bob, c["hat"])
    if c.get("cap"):
        R(d, hx0, top + bob, hx0 + hw - 1, top + 2 + bob, c["cap"])
        if facing != "up":
            bx = {"left": hx0 - 2, "right": hx0 + hw - 2}.get(facing, hx0)
            R(d, bx, top + 3 + bob, bx + (hw if facing == "down" else 3), top + 3 + bob, c.get("brim", c["cap"]))
    if c.get("antennae"):
        d.line([(6, top + bob), (4, top - 4 + bob)], fill=c["antennae"])
        d.line([(9, top + bob), (11, top - 4 + bob)], fill=c["antennae"])
        d.point((4, top - 5 + bob), fill=N["lamp"])
        d.point((11, top - 5 + bob), fill=N["lamp"])
    # eyes
    ey = top + 5 + bob
    eye = c.get("eye", N["ink"])
    big = c.get("big_eyes")
    if facing == "down":
        for ex in (6, 9):
            R(d, ex - (1 if big and ex == 6 else 0), ey, ex + (1 if big and ex == 9 else 0), ey + (1 if big else 0), eye)
    elif facing == "left":
        R(d, 5, ey, 5 + (1 if big else 0), ey + (1 if big else 0), eye)
    elif facing == "right":
        R(d, 9, ey, 10 if big else 9, ey + (1 if big else 0), eye)
    # extras
    if c.get("bag") and facing != "right":
        R(d, 11, 18 + bob, 14, 23 + bob, c["bag"])
    if c.get("pole") and facing in ("down", "left"):
        d.line([(13, 6 + bob), (13, 30)], fill=N["dusk"])
        R(d, 12, 3 + bob, 14, 5 + bob, N["lamp"])
        d.point((13, 2 + bob), fill=N["ember"])
    if facing == "down" and c.get("letter"):
        glyph_text(d, 6, 17 + bob, c["letter"], c.get("letter_color", N["ink"]))


def big_person(d, facing, f, c, s):
    """Foreman: a wide 32x32 figure."""
    bob = 1 if f in (1, 3) else 0
    if facing in ("down", "up"):
        R(d, 10, 26, 13, 31 - (1 if f == 1 else 0), c["legs"])
        R(d, 18, 26, 21, 31 - (1 if f == 3 else 0), c["legs"])
    else:
        R(d, 13, 26, 18, 31, c["legs"])
    R(d, 6, 13 + bob, 25, 27, c["body"])
    R(d, 4, 15 + bob, 5, 23 + bob, c["body"])
    R(d, 26, 15 + bob, 27, 23 + bob, c["body"])
    d.ellipse([10, 2 + bob, 21, 13 + bob], fill=c["head"])
    R(d, 9, 3 + bob, 22, 5 + bob, c["visor"])
    if facing != "up":
        R(d, 9, 6 + bob, 22, 6 + bob, c["visor"])
        d.line([(9, 7 + bob), (9, 10 + bob)], fill=N["lamp"])
        d.line([(22, 7 + bob), (22, 10 + bob)], fill=N["lamp"])
    if facing == "down":
        R(d, 13, 8 + bob, 13, 9 + bob, N["ink"])
        R(d, 18, 8 + bob, 18, 9 + bob, N["ink"])
        R(d, 18, 16 + bob, 24, 24 + bob, N["moon"])
        for y in (18, 20, 22):
            d.line([(19, y + bob), (23, y + bob)], fill=N["slate"])
        glyph_text(d, 9, 17 + bob, "F", N["moon"])
    elif facing == "left":
        R(d, 11, 8 + bob, 11, 9 + bob, N["ink"])
        R(d, 4, 16 + bob, 9, 23 + bob, N["moon"])


def blob(d, facing, f, c, s):
    """Curfew: a 48x48 heap of quilt and pillows that breathes."""
    breathe = 1 if f in (1, 3) else 0
    d.ellipse([2 - breathe, 16 - breathe * 2, 45 + breathe, 47], fill=c["body"])
    for i, (x, y) in enumerate(((8, 26), (20, 22), (32, 27), (14, 36), (27, 37), (37, 34))):
        R(d, x, y, x + 6, y + 5, [N["slate"], N["dusk"], N["fog"]][i % 3])
    d.ellipse([7, 9 - breathe, 22, 21 - breathe], fill=c["pillow"])
    d.ellipse([25, 11 - breathe, 41, 23 - breathe], fill=c["pillow"])
    if facing != "up":
        ox = {"left": -6, "right": 6}.get(facing, 0)
        for ex in (17 + ox, 29 + ox):
            R(d, ex, 27 - breathe, ex + 4, 28 - breathe, N["hush"])
            R(d, ex, 26 - breathe, ex + 4, 26 - breathe, c["body"])
    if facing == "down":
        glyph_text(d, 22, 38, "C", N["moon"])


CHARACTERS = {
    "tadzio": (16, 32, humanoid, dict(head=N["moon"], hair=N["ink"], body=N["slate"], stripes=N["fog"],
                                       legs=N["slate"], feet=N["fog"], arms=N["slate"], letter="T")),
    "wick": (16, 32, humanoid, dict(head=N["fog"], head_w=10, top=6, body=N["dusk"], body_bottom=29,
                                     legs=N["ink"], arms=N["dusk"], antennae=N["fog"], big_eyes=True,
                                     pole=True, letter="W", letter_color=N["lamp"])),
    "unbaker": (16, 32, humanoid, dict(head=N["moon"], top=5, hat=N["moon"], body=N["dusk"],
                                        apron=N["moon"], legs=N["night"], arms=N["dusk"], letter="U")),
    "postman": (16, 32, humanoid, dict(head=N["moon"], cap=N["night"], brim=N["fog"], body=N["night"],
                                        body_bottom=28, legs=N["ink"], arms=N["night"], bag=N["lamp"],
                                        letter="P", letter_color=N["moon"])),
    "foreman": (32, 32, big_person, dict(head=N["moon"], visor=N["ember"], body=N["dusk"], legs=N["night"])),
    "curfew": (48, 48, blob, dict(body=N["slate"], pillow=N["moon"])),
}


def gen_characters():
    for name, (fw, fh, fn, c) in CHARACTERS.items():
        sheet = Image.new("RGBA", (fw * 4, fh * 4), CLEAR)
        for row, facing in enumerate(("down", "up", "left", "right")):
            for f in range(4):
                fr = Image.new("RGBA", (fw, fh), CLEAR)
                d = ImageDraw.Draw(fr)
                if fn is humanoid:
                    fn(d, "left" if facing == "right" else facing, f, c)
                else:
                    fn(d, "left" if facing == "right" else facing, f, c, (fw, fh))
                fr = outline(fr)
                if facing == "right":
                    fr = fr.transpose(Image.FLIP_LEFT_RIGHT)
                sheet.paste(fr, (f * fw, row * fh))
        sheet.save(ROOT / f"assets/sprites/{name}.png")


# ---------------------------------------------------------------- portraits

def face(d, mood, c):
    d.rectangle([0, 0, 31, 31], fill=N["night"], outline=N["dusk"])
    R(d, 6, 24, 25, 31, c["body"])
    hx0, hx1 = c.get("head_x", (7, 24))
    d.ellipse([hx0, 5, hx1, 26], fill=c["head"], outline=N["ink"])
    if c.get("hair"):
        d.chord([hx0, 5, hx1, 26], 180, 360, fill=c["hair"])
        R(d, hx0 + 2, 11, hx1 - 2, 15, c["head"])
    if c.get("hat"):
        R(d, hx0 - 1, 1, hx1 + 1, 9, c["hat"])
        d.rectangle([hx0 - 1, 1, hx1 + 1, 9], outline=N["ink"])
    if c.get("visor"):
        R(d, hx0 - 2, 7, hx1 + 2, 10, c["visor"])
        d.line([(hx0 - 1, 11), (hx0 - 1, 16)], fill=N["lamp"])
        d.line([(hx1 + 1, 11), (hx1 + 1, 16)], fill=N["lamp"])
    if c.get("cap"):
        R(d, hx0, 4, hx1, 9, c["cap"])
        R(d, hx0 - 2, 9, hx1 - 3, 10, N["fog"])
    if c.get("antennae"):
        d.line([(12, 6), (8, 0)], fill=N["fog"])
        d.line([(19, 6), (23, 0)], fill=N["fog"])
        d.point((8, 0), fill=N["lamp"])
        d.point((23, 0), fill=N["lamp"])
    if c.get("pillows"):
        d.ellipse([1, 0, 15, 10], fill=N["moon"], outline=N["ink"])
        d.ellipse([16, 1, 30, 11], fill=N["moon"], outline=N["ink"])
    ey = c.get("eye_y", 15)
    eye = c.get("eye", N["ink"])
    lx, rx = 12, 19
    if mood == "panic":
        for x in (lx, rx):
            d.rectangle([x - 1, ey - 2, x + 1, ey + 1], fill=N["moon"], outline=eye)
        d.ellipse([14, 20, 17, 23], fill=N["ink"])
        d.line([(25, 9), (25, 12)], fill=N["fog"])
    elif mood == "sad":
        for x, s in ((lx, -1), (rx, 1)):
            R(d, x, ey, x, ey + 1, eye)
            d.line([(x - 2, ey - 2 + (1 if s < 0 else 0)), (x + 2, ey - 2 + (0 if s < 0 else 1))], fill=N["ink"])
        d.arc([13, 21, 18, 25], 200, 340, fill=N["ink"])
    elif mood == "happy":
        for x in (lx, rx):
            d.arc([x - 2, ey - 1, x + 2, ey + 3], 200, 340, fill=eye)
        d.arc([12, 17, 19, 23], 20, 160, fill=N["ink"])
    elif mood == "grump":
        for x, s in ((lx, 1), (rx, -1)):
            R(d, x, ey, x, ey + 1, eye)
            d.line([(x - 2, ey - 3 + (0 if s > 0 else 1)), (x + 2, ey - 3 + (1 if s > 0 else 0))], fill=N["ink"])
        d.line([(13, 22), (18, 22)], fill=N["ink"])
    elif mood == "sleepy":
        for x in (lx, rx):
            d.line([(x - 2, ey), (x + 2, ey)], fill=eye)
            d.line([(x - 2, ey + 1), (x + 2, ey + 1)], fill=eye)
        d.ellipse([14, 20, 17, 24], fill=N["ink"])
    else:
        for x in (lx, rx):
            R(d, x, ey, x + (1 if c.get("big_eyes") else 0), ey + (2 if c.get("big_eyes") else 1), eye)
        d.line([(14, 21), (17, 21)], fill=N["ink"])


PORTRAITS = {
    "tadzio": (["neutral", "happy", "sad"], dict(head=N["moon"], hair=N["ink"], body=N["slate"])),
    "wick": (["neutral", "panic", "sad", "happy"], dict(head=N["fog"], body=N["dusk"], antennae=True,
                                                         big_eyes=True, head_x=(5, 26))),
    "unbaker": (["neutral", "grump", "happy"], dict(head=N["moon"], body=N["moon"], hat=N["moon"])),
    "postman": (["neutral"], dict(head=N["moon"], body=N["night"], cap=N["night"])),
    "foreman": (["neutral", "grump"], dict(head=N["moon"], body=N["dusk"], visor=N["ember"], head_x=(5, 26))),
    "curfew": (["neutral", "sleepy", "happy"], dict(head=N["slate"], body=N["slate"], pillows=True,
                                                     eye=N["hush"], head_x=(2, 29), eye_y=17)),
}


def gen_portraits():
    for name, (moods, c) in PORTRAITS.items():
        for mood in moods:
            img = Image.new("RGBA", (32, 32), CLEAR)
            face(ImageDraw.Draw(img), mood, c)
            img.save(ROOT / f"assets/portraits/{name}_{mood}.png")


# ---------------------------------------------------------------- small sprites

def radial(size, color, bands=0, power=1.0):
    img = Image.new("RGBA", (size, size), CLEAR)
    px = img.load()
    c = (size - 1) / 2
    for y in range(size):
        for x in range(size):
            dist = math.hypot(x - c, y - c) / (size / 2)
            a = max(0.0, 1.0 - dist) ** power
            if bands:
                a = math.ceil(a * bands) / bands
            px[x, y] = (color[0], color[1], color[2], int(255 * a))
    return img


def cone(size, length, spread_deg, bands):
    img = Image.new("RGBA", (size, size), CLEAR)
    px = img.load()
    cy = size / 2
    half = math.radians(spread_deg / 2)
    for y in range(size):
        for x in range(size):
            dx, dy = x + 0.5, y + 0.5 - cy
            dist = math.hypot(dx, dy)
            if dist == 0 or dist > length:
                continue
            ang = abs(math.atan2(dy, dx))
            if ang > half:
                continue
            a = (1 - dist / length) * (1 - (ang / half) ** 2)
            a = math.ceil(a * bands) / bands
            px[x, y] = (255, 255, 255, int(255 * a))
    return img


def gen_small():
    s = ROOT / "assets/sprites"
    img = Image.new("RGBA", (8, 8), CLEAR)
    d = ImageDraw.Draw(img)
    d.ellipse([1, 2, 6, 6], fill=N["lamp"])
    d.point((2, 3), fill=N["moon"])
    d.point((5, 5), fill=N["ember"])
    outline(img).save(s / "crumb.png")

    img = Image.new("RGBA", (8, 8), CLEAR)
    d = ImageDraw.Draw(img)
    d.ellipse([1, 4, 4, 7], fill=N["moon"])
    d.line([(4, 0), (4, 5)], fill=N["moon"])
    d.line([(5, 0), (6, 1)], fill=N["moon"])
    img.save(s / "note.png")

    img = Image.new("RGBA", (8, 8), CLEAR)
    d = ImageDraw.Draw(img)
    d.ellipse([1, 1, 6, 6], fill=N["hush"])
    d.ellipse([3, 3, 4, 4], fill=N["moon"])
    img.save(s / "drifter.png")

    Image.new("RGBA", (1, 8), N["moon"]).save(s / "bar.png")

    img = Image.new("RGBA", (6, 6), CLEAR)
    d = ImageDraw.Draw(img)
    d.ellipse([0, 0, 5, 5], fill=N["moon"])
    d.point((2, 2), fill=(255, 255, 255, 255))
    img.save(s / "token.png")

    radial(24, N["moon"], bands=4, power=1.5).save(s / "glow.png")
    radial(64, (255, 255, 255), bands=4, power=0.8).save(s / "light_radial.png")
    cone(64, 56, 60, bands=4).save(s / "light_cone.png")

    img = Image.new("RGBA", (8, 8), CLEAR)
    d = ImageDraw.Draw(img)
    d.ellipse([0, 1, 7, 7], fill=N["wake"], outline=N["ink"])
    d.line([(4, 4), (4, 2)], fill=N["ink"])
    d.line([(4, 4), (5, 4)], fill=N["ink"])
    R(d, 3, 0, 4, 0, N["wake"])
    img.save(s / "watch_icon.png")

    img = Image.new("RGBA", (5, 4), CLEAR)
    d = ImageDraw.Draw(img)
    d.polygon([(0, 0), (4, 0), (2, 3)], fill=N["lamp"])
    img.save(s / "marker.png")


# ---------------------------------------------------------------- audio

SR = 22050


def note_hz(name):
    names = {"C": 0, "C#": 1, "Db": 1, "D": 2, "D#": 3, "Eb": 3, "E": 4, "F": 5, "F#": 6, "Gb": 6,
             "G": 7, "G#": 8, "Ab": 8, "A": 9, "A#": 10, "Bb": 10, "B": 11}
    pitch, octave = name[:-1], int(name[-1])
    midi = 12 * (octave + 1) + names[pitch]
    return 440.0 * 2 ** ((midi - 69) / 12)


def osc(kind, phase, duty=0.5):
    p = phase % 1.0
    if kind == "square":
        return 1.0 if p < duty else -1.0
    if kind == "tri":
        return 4 * abs(p - 0.5) - 1
    if kind == "saw":
        return 2 * p - 1
    return math.sin(2 * math.pi * p)


def tone(buf, start, dur, hz, kind="square", vol=0.3, attack=0.005, release=0.05, duty=0.5, glide=None, vibrato=0.0):
    n0 = int(start * SR)
    n = int(dur * SR)
    phase = 0.0
    for i in range(n):
        t = i / SR
        f = hz if glide is None else hz + (glide - hz) * (i / n)
        if vibrato:
            f *= 1 + vibrato * math.sin(2 * math.pi * 5 * t)
        phase += f / SR
        env = min(1.0, t / attack) if attack else 1.0
        env *= min(1.0, (dur - t) / release) if release else 1.0
        j = n0 + i
        if j < len(buf):
            buf[j] += vol * env * osc(kind, phase, duty)


def noise(buf, start, dur, vol, decay=10.0, seed=1):
    rnd = random.Random(seed)
    n0 = int(start * SR)
    for i in range(int(dur * SR)):
        j = n0 + i
        if j < len(buf):
            buf[j] += vol * math.exp(-decay * i / SR) * (rnd.random() * 2 - 1)


def bell(buf, start, hz, vol, dur):
    n0 = int(start * SR)
    for i in range(int(dur * SR)):
        t = i / SR
        s = sum(a * math.sin(2 * math.pi * hz * m * t) for m, a in ((1, 1.0), (2.76, 0.4), (5.4, 0.2)))
        j = n0 + i
        if j < len(buf):
            buf[j] += vol * math.exp(-2.2 * t) * s


def save_wav(path, buf):
    peak = max(1.0, max(abs(x) for x in buf))
    data = array.array("h", (int(x / peak * 30000) for x in buf))
    with wave.open(str(path), "wb") as w:
        w.setnchannels(1)
        w.setsampwidth(2)
        w.setframerate(SR)
        w.writeframes(data.tobytes())


def sfx():
    out = ROOT / "assets/sfx"

    def make(name, dur, fn):
        buf = [0.0] * int(dur * SR)
        fn(buf)
        save_wav(out / f"{name}.wav", buf)

    make("blip", 0.05, lambda b: tone(b, 0, 0.05, 520, "square", 0.25, release=0.03, duty=0.25))
    make("cursor", 0.04, lambda b: tone(b, 0, 0.04, 880, "square", 0.2, release=0.02, duty=0.25))
    make("confirm", 0.12, lambda b: (tone(b, 0, 0.05, 660, "square", 0.25, duty=0.25),
                                    tone(b, 0.05, 0.07, 990, "square", 0.25, duty=0.25)))
    make("cancel", 0.12, lambda b: (tone(b, 0, 0.05, 520, "square", 0.25, duty=0.25),
                                   tone(b, 0.05, 0.07, 350, "square", 0.25, duty=0.25)))
    make("buzz", 0.6, lambda b: (tone(b, 0, 0.6, 92, "square", 0.3), tone(b, 0, 0.6, 97, "square", 0.3)))
    make("whoosh", 0.7, lambda b: (noise(b, 0, 0.7, 0.4, decay=4),
                                  tone(b, 0.05, 0.6, 180, "sine", 0.4, glide=420, release=0.3)))
    make("chime", 2.5, lambda b: (bell(b, 0, note_hz("G5"), 0.5, 2.5), bell(b, 0.6, note_hz("D5"), 0.4, 1.9)))
    make("hit", 0.18, lambda b: (tone(b, 0, 0.18, 240, "sine", 0.6, glide=90, release=0.08),
                                noise(b, 0, 0.06, 0.15, decay=40)))
    make("hustle", 0.14, lambda b: (tone(b, 0, 0.06, 1200, "square", 0.25, duty=0.25),
                                   tone(b, 0.06, 0.08, 1600, "square", 0.25, duty=0.25)))
    make("rewind", 0.6, lambda b: tone(b, 0, 0.6, 1400, "saw", 0.25, glide=180, vibrato=0.08, attack=0.3, release=0.05))
    make("tick", 0.06, lambda b: (noise(b, 0, 0.02, 0.5, decay=200), tone(b, 0, 0.04, 2200, "sine", 0.3, release=0.03)))
    make("note", 0.4, lambda b: tone(b, 0, 0.4, note_hz("C5"), "tri", 0.4, release=0.25))
    make("flicker", 0.35, lambda b: [tone(b, s, 0.04, 120, "square", 0.3) for s in (0, 0.08, 0.2, 0.27)])
    make("asleep", 0.9, lambda b: tone(b, 0, 0.9, 660, "sine", 0.4, glide=220, release=0.4))
    make("satisfied", 0.6, lambda b: [tone(b, i * 0.1, 0.18, note_hz(n), "tri", 0.35)
                                     for i, n in enumerate(("C5", "E5", "G5", "C6"))])
    make("door", 0.15, lambda b: (noise(b, 0, 0.05, 0.3, decay=60), tone(b, 0, 0.12, 160, "sine", 0.3, glide=120)))
    make("block", 0.2, lambda b: tone(b, 0, 0.2, note_hz("E5"), "tri", 0.4, release=0.15))
    make("step_ok", 0.25, lambda b: (tone(b, 0, 0.1, note_hz("E5"), "tri", 0.3), tone(b, 0.1, 0.15, note_hz("A5"), "tri", 0.3)))


def render_song(bpm, beats, voices, tick=True, tick_vol=0.12):
    spb = 60.0 / bpm
    total = beats * spb
    buf = [0.0] * int(total * SR)
    for v in voices:
        t = 0.0
        for item in v["notes"]:
            name, length = item
            dur = length * spb
            if name:
                for nm in name.split("+"):
                    tone(buf, t, dur * v.get("gate", 0.9), note_hz(nm), v["kind"], v["vol"],
                         attack=v.get("attack", 0.01), release=v.get("release", 0.08),
                         duty=v.get("duty", 0.5), vibrato=v.get("vibrato", 0.0))
            t += dur
    if tick:
        for b in range(beats):
            noise(buf, b * spb, 0.015, tick_vol, decay=300, seed=b)
    return buf


def music():
    out = ROOT / "assets/music"
    songs = {}
    # house_hum: a low hum and the fridge's four-note motif, very sparse.
    motif = [("A4", 1), ("C5", 1), ("B4", 1), ("E4", 2), (None, 3)]
    motif2 = [("A4", 1), ("C5", 1), ("B4", 1), ("G4", 2), (None, 3)]
    songs["house_hum"] = render_song(66, 48, [
        {"kind": "sine", "vol": 0.18, "notes": [("A1+A2", 8)] * 6, "gate": 1.0, "attack": 0.5, "release": 0.5},
        {"kind": "tri", "vol": 0.22, "notes": motif + [(None, 8)] + motif2 + [(None, 8)] + [(None, 16)], "release": 0.3},
    ], tick_vol=0.05)
    # street_loop: a slow walk under the lamps.
    bass = [("D2", 1), ("A2", 1), ("F2", 1), ("A2", 1), ("C2", 1), ("G2", 1), ("E2", 1), ("G2", 1),
            ("Bb1", 1), ("F2", 1), ("D2", 1), ("F2", 1), ("A1", 1), ("E2", 1), ("C#2", 1), ("E2", 1)]
    lead = [("F4", 2), ("E4", 1), ("D4", 1), ("A4", 3), (None, 1), ("G4", 1), ("F4", 1), ("E4", 1), ("C4", 1),
            ("D4", 3), (None, 1), ("F4", 1), ("A4", 1), ("C5", 2), ("Bb4", 1), ("A4", 1), ("G4", 2),
            ("E4", 2), ("C#4", 2), ("A3", 2), (None, 2)]
    songs["street_loop"] = render_song(84, 64, [
        {"kind": "tri", "vol": 0.35, "notes": bass * 4, "gate": 0.8},
        {"kind": "square", "vol": 0.12, "duty": 0.25, "notes": lead * 2, "release": 0.15},
    ])
    # depot_loop: everything on the schedule.
    dbass = [("E2", 0.5), ("E2", 0.5), ("B2", 0.5), ("E2", 0.5)] * 4 + [("C2", 0.5), ("C2", 0.5), ("G2", 0.5), ("C2", 0.5)] * 2 + [("D2", 0.5), ("D2", 0.5), ("A2", 0.5), ("D2", 0.5)] * 2
    dlead = [("B4", 1), ("E5", 1), ("D5", 0.5), ("B4", 0.5), ("A4", 1), (None, 4), ("G4", 1), ("A4", 1), ("B4", 1), ("D5", 1),
             ("E5", 2), (None, 2), ("C5", 1), ("B4", 1), ("A4", 1), ("G4", 1), ("F#4", 2), (None, 2)]
    songs["depot_loop"] = render_song(96, 64, [
        {"kind": "square", "vol": 0.22, "duty": 0.5, "notes": dbass * 4, "gate": 0.5},
        {"kind": "square", "vol": 0.1, "duty": 0.125, "notes": dlead * 2, "release": 0.1},
    ], tick_vol=0.16)
    # curfew_theme: a lullaby in 3/4.
    wbass = [("F2", 1), ("A3+C4", 1), ("A3+C4", 1), ("C2", 1), ("G3+Bb3", 1), ("G3+Bb3", 1),
             ("D2", 1), ("F3+A3", 1), ("F3+A3", 1), ("C2", 1), ("E3+G3", 1), ("E3+G3", 1)]
    melody = [("C5", 2), ("A4", 1), ("Bb4", 2), ("G4", 1), ("A4", 2), ("F4", 1), ("G4", 3),
              ("C5", 2), ("D5", 1), ("C5", 2), ("Bb4", 1), ("A4", 1), ("G4", 1), ("A4", 1), ("F4", 3)]
    songs["curfew_theme"] = render_song(72, 48, [
        {"kind": "tri", "vol": 0.25, "notes": wbass * 4, "gate": 0.85, "release": 0.2},
        {"kind": "sine", "vol": 0.3, "notes": melody * 2, "vibrato": 0.006, "release": 0.3, "attack": 0.03},
    ])
    ffmpeg = shutil.which("ffmpeg")
    for name, buf in songs.items():
        wav = out / f"{name}.wav"
        save_wav(wav, buf)
        if ffmpeg:
            ogg = out / f"{name}.ogg"
            subprocess.run([ffmpeg, "-y", "-loglevel", "error", "-i", str(wav), "-c:a", "vorbis",
                            "-strict", "-2", "-ac", "2", str(ogg)], check=True)
            wav.unlink()


def main():
    for sub in ("sprites", "tiles", "portraits", "sfx", "music"):
        (ROOT / "assets" / sub).mkdir(parents=True, exist_ok=True)
    gen_tiles()
    gen_characters()
    gen_portraits()
    gen_small()
    sfx()
    music()
    print("placeholders written to assets/")


if __name__ == "__main__":
    main()
