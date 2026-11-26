"""Draw Tadzio in each pair of pajamas by recoloring the shirt and pants of tadzio.txt.

Run from the repo root:  python3 docs/art/scripts/pajamas.py
"""
from pathlib import Path

SRC = Path("assets/px/sprites/tadzio.txt")
# shirt: x light, u middle, f shadow. pants: s light, d middle, n dark, i shine.
PAJAMAS = {
    "star": ({"x": "m", "u": "l", "f": "y"}, {"s": "l", "d": "y", "n": "o", "i": "m"}, "gold with white stars"),
    "frog": ({"x": "i", "u": "w", "f": "v"}, {"s": "w", "d": "v", "n": "k", "i": "i"}, "frog green"),
    "moon": ({"x": "E", "u": "p", "f": "d"}, {"s": "p", "d": "d", "n": "n", "i": "E"}, "moon purple"),
    "cloud": ({"x": "t", "u": "m", "f": "f"}, {"s": "m", "d": "f", "n": "s", "i": "t"}, "fluffy cloud white"),
}


def dress(lines, shirt, pants, stars):
    out, frame_row = [], 0
    for line in lines:
        if line.startswith("@") or line.startswith("#") or not line.strip():
            out.append(line)
            frame_row = 0
            continue
        if frame_row >= 12:
            pal = {**shirt, **pants} if frame_row >= 24 else shirt
            line = "".join(pal.get(c, c) for c in line)
            if stars and frame_row in (15, 19, 23):
                i = (frame_row * 3) % 5 + 5
                if line[i] in "ly":
                    line = line[:i] + "m" + line[i + 1:]
        out.append(line)
        frame_row += 1
    return out


def main():
    lines = SRC.read_text().split("\n")
    for name, (shirt, pants, about) in PAJAMAS.items():
        body = dress(lines[1:], shirt, pants, name == "star")
        head = [f"# tadzio_{name} 16x32", f"# Tadzio in {about} pajamas. Drawn by docs/art/scripts/pajamas.py from tadzio.txt."]
        Path(f"assets/px/sprites/tadzio_{name}.txt").write_text("\n".join(head + [l for l in body if not l.startswith("# tadzio ")]))
    print(f"wrote {len(PAJAMAS)} pajamas")


if __name__ == "__main__":
    main()
