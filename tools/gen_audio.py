#!/usr/bin/env python3
"""Generate every placeholder sound effect and music loop into assets/sfx and assets/music.

Run from the repo root:  python3 tools/gen_audio.py   (needs ffmpeg for the .ogg music)
Music is encoded fresh each run, so revert the .ogg files you did not mean to change.
"""
import array
import math
import random
import shutil
import subprocess
import wave
from pathlib import Path

ROOT = Path(__file__).resolve().parent.parent


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
    make("gone", 1.2, lambda b: tone(b, 0, 1.2, note_hz("C3"), "tri", 0.4, attack=0.02, release=0.8))
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
    # battle_loop: the worker fights. Quick, bouncy, a little cheeky.
    bbass = ([("A2", 0.5), ("A2", 0.5), ("A3", 0.5), ("A2", 0.5)] * 2 + [("F2", 0.5), ("F2", 0.5), ("F3", 0.5), ("F2", 0.5)] * 2
             + [("G2", 0.5), ("G2", 0.5), ("G3", 0.5), ("G2", 0.5)] * 2 + [("E2", 0.5), ("E2", 0.5), ("E3", 0.5), ("G#2", 0.5)] * 2)
    blead = [("E5", 0.5), ("A4", 0.5), ("C5", 0.5), ("E5", 0.5), ("D5", 1), ("C5", 0.5), ("B4", 0.5),
             ("A4", 1), (None, 0.5), ("E4", 0.5), ("A4", 1), ("C5", 1),
             ("D5", 0.5), ("G4", 0.5), ("B4", 0.5), ("D5", 0.5), ("C5", 1), ("B4", 0.5), ("G4", 0.5),
             ("G#4", 1.5), ("B4", 0.5), ("E5", 2)]
    battle = render_song(138, 64, [
        {"kind": "tri", "vol": 0.4, "notes": bbass * 4, "gate": 0.6},
        {"kind": "square", "vol": 0.13, "duty": 0.25, "notes": blead * 4, "release": 0.06},
    ], tick=False)
    spb = 60.0 / 138
    for beat in range(64):
        tone(battle, beat * spb, 0.12, 110, "sine", 0.5, glide=45, release=0.05)
        if beat % 2 == 1:
            noise(battle, beat * spb, 0.09, 0.25, decay=40, seed=beat)
    songs["battle_loop"] = battle
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
    for sub in ("sfx", "music"):
        (ROOT / "assets" / sub).mkdir(parents=True, exist_ok=True)
    sfx()
    music()
    print("sounds written to assets/")


if __name__ == "__main__":
    main()
