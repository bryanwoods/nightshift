#!/usr/bin/env python3
"""Generate the arcade machines' sound effects into assets/sfx, one set for each game.

Run from the repo root:  python3 tools/gen_arcade_sfx.py
"""
from gen_audio import ROOT, SR, bell, noise, note_hz, save_wav, tone


def make(name, dur, *parts):
    buf = [0.0] * int(dur * SR)
    for fn in parts:
        fn(buf)
    save_wav(ROOT / "assets/sfx" / f"a_{name}.wav", buf)


def arp(notes, step, kind="square", vol=0.25, length=None, duty=0.25):
    return lambda b: [tone(b, i * step, length or step, note_hz(n), kind, vol, duty=duty, release=0.02) for i, n in enumerate(notes)]


def main():
    make("coin", 0.25, arp(("B5", "E6"), 0.08, length=0.17))
    make("over", 1.0, arp(("G4", "E4", "C4"), 0.18, "tri", 0.35, length=0.3), lambda b: tone(b, 0.54, 0.45, note_hz("C3"), "tri", 0.3, release=0.3))

    make("maze_chomp_a", 0.07, lambda b: tone(b, 0, 0.07, 300, "square", 0.22, glide=520, duty=0.5, release=0.02))
    make("maze_chomp_b", 0.07, lambda b: tone(b, 0, 0.07, 520, "square", 0.22, glide=300, duty=0.5, release=0.02))
    make("maze_power", 0.5, lambda b: tone(b, 0, 0.5, 200, "square", 0.25, glide=900, vibrato=0.12, duty=0.3, release=0.1))
    make("maze_eat", 0.3, arp(("C5", "G5", "C6", "G6"), 0.05, length=0.08))
    make("maze_die", 0.9, lambda b: tone(b, 0, 0.9, 700, "square", 0.25, glide=90, vibrato=0.2, duty=0.4, release=0.2))

    make("hop_jump", 0.14, lambda b: tone(b, 0, 0.14, 330, "square", 0.22, glide=760, duty=0.125, release=0.03))
    make("hop_land", 0.08, lambda b: noise(b, 0, 0.08, 0.35, decay=60, seed=3), lambda b: tone(b, 0, 0.06, 140, "sine", 0.3, glide=80))
    make("hop_spark", 0.3, lambda b: bell(b, 0, note_hz("E6"), 0.35, 0.3), lambda b: bell(b, 0.06, note_hz("B6"), 0.25, 0.24))
    make("hop_splash", 0.4, lambda b: noise(b, 0, 0.4, 0.45, decay=9, seed=7), lambda b: tone(b, 0, 0.25, 900, "sine", 0.2, glide=300))
    make("hop_crash", 0.35, lambda b: noise(b, 0, 0.3, 0.4, decay=14, seed=9), lambda b: tone(b, 0, 0.3, 180, "square", 0.25, glide=60, duty=0.5))

    make("catch_star", 0.35, lambda b: bell(b, 0, note_hz("A5"), 0.4, 0.35), lambda b: tone(b, 0, 0.05, note_hz("A6"), "tri", 0.2))
    make("catch_moon", 0.8, lambda b: [bell(b, i * 0.07, note_hz(n), 0.3, 0.7) for i, n in enumerate(("C5", "E5", "G5", "C6"))])
    make("catch_wax", 0.3, lambda b: tone(b, 0, 0.3, 110, "saw", 0.3, glide=70, release=0.1), lambda b: noise(b, 0, 0.1, 0.2, decay=30, seed=4))
    make("catch_miss", 0.2, lambda b: tone(b, 0, 0.2, 420, "tri", 0.3, glide=200, release=0.08))

    make("cat_eat", 0.22, lambda b: tone(b, 0, 0.1, 500, "tri", 0.35, glide=900, release=0.02), lambda b: tone(b, 0.1, 0.12, 900, "tri", 0.3, glide=600, vibrato=0.06))
    make("cat_turn", 0.03, lambda b: tone(b, 0, 0.03, 1400, "square", 0.12, duty=0.125, release=0.01))
    make("cat_crash", 0.5, lambda b: noise(b, 0, 0.5, 0.35, decay=5, seed=11), lambda b: tone(b, 0, 0.4, 1200, "saw", 0.12, glide=500, vibrato=0.1))

    make("moon_boing", 0.25, lambda b: tone(b, 0, 0.25, 520, "sine", 0.45, glide=180, vibrato=0.08, release=0.1))
    make("moon_pop", 0.1, lambda b: noise(b, 0, 0.04, 0.35, decay=90, seed=2), lambda b: tone(b, 0, 0.08, 900, "sine", 0.35, glide=1500, release=0.03))
    make("moon_wall", 0.05, lambda b: tone(b, 0, 0.05, 1800, "sine", 0.3, release=0.04))
    make("moon_lose", 0.8, lambda b: tone(b, 0, 0.8, 1400, "sine", 0.35, glide=200, vibrato=0.04, release=0.2))
    make("moon_clear", 0.7, arp(("C6", "D6", "E6", "G6", "C7"), 0.08, "tri", 0.3, length=0.2))

    make("stack_drop", 0.14, lambda b: tone(b, 0, 0.14, 220, "sine", 0.45, glide=110, release=0.06), lambda b: noise(b, 0, 0.05, 0.2, decay=50, seed=6))
    make("stack_perfect", 0.6, lambda b: bell(b, 0, note_hz("C6"), 0.4, 0.6), lambda b: bell(b, 0.05, note_hz("G6"), 0.3, 0.55))
    make("stack_fail", 0.6, lambda b: tone(b, 0, 0.6, 300, "square", 0.22, glide=70, duty=0.5, release=0.2), lambda b: noise(b, 0.1, 0.4, 0.25, decay=8, seed=8))

    make("lamps_light", 0.4, lambda b: noise(b, 0, 0.12, 0.25, decay=25, seed=12), lambda b: bell(b, 0.05, note_hz("D6"), 0.35, 0.35))
    make("lamps_fizzle", 0.3, lambda b: [tone(b, s, 0.03, 90, "square", 0.2, duty=0.5) for s in (0, 0.07, 0.12, 0.2)])
    make("lamps_lost", 0.7, lambda b: tone(b, 0, 0.7, 260, "tri", 0.35, glide=110, vibrato=0.15, release=0.3))
    make("lamps_move", 0.03, lambda b: tone(b, 0, 0.03, 660, "tri", 0.2, release=0.01))

    make("flap_flap", 0.08, lambda b: noise(b, 0, 0.08, 0.3, decay=45, seed=13), lambda b: tone(b, 0, 0.06, 700, "sine", 0.15, glide=1100))
    make("flap_pass", 0.2, arp(("E6", "A6"), 0.07, "tri", 0.3, length=0.12))
    make("flap_crash", 0.4, lambda b: tone(b, 0, 0.4, 1600, "square", 0.2, glide=100, duty=0.125, release=0.1))
    print("arcade sounds written to assets/sfx/")


if __name__ == "__main__":
    main()
