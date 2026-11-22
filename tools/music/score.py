"""Read a .song text file into notes, chords and voice settings.

A song file looks like this:

    tempo 88
    meter 4/4
    grid 8
    form A A2

    voice lead inst=pulse duty=0.25 vol=0.5 role=melody
    voice pad  inst=pad auto=chords

    section A
    chords | Dmaj7 | F#m7 | Gmaj7 | Gm6 |
    lead   | F#4 . A4 . D5 . . C#5 | . . . . E5 . D5 C#5 | ...

Each bar holds exactly `grid` steps. A note name starts a note, "." holds the
sound before it, "-" is silence, "%" repeats the bar before. A line with one bar
repeats that bar for the whole section. Note marks: ">" accent, "_" soft, "^" slide
in from the note before, "!" an intended clash the theory check lets through.
A comma splits one step evenly, for quick runs and drum fills: "E5,F#5" or "s,s".

A section can change the feel:  section B meter=3/4 grid=6 tempo=78 rit=1:0.85
(rit slows the last 1 bar to 0.85 of the tempo). Every section keeps the same number
of steps per beat. A "dyn" line sets loudness per bar and glides between bars.
Drum letters: k kick, s snare, h hat, o open hat, c clap, t tom.

Two whole-line shortcuts:
    bell | @lead+12 |   copies the lead's notes in this section, an octave up
    pad  | auto |       plays the voice's auto part (auto=chords, arp:up, arp:broken,
                        comp with pattern=--x.x. (g = two quick hits), roots=1 for root notes only, root) over this section's chords
"""
import bisect
import re
from dataclasses import dataclass, field
from pathlib import Path

NAMES = {"C": 0, "D": 2, "E": 4, "F": 5, "G": 7, "A": 9, "B": 11}
QUAL = {
    "": (0, 4, 7), "m": (0, 3, 7), "5": (0, 7), "7": (0, 4, 7, 10), "maj7": (0, 4, 7, 11),
    "m7": (0, 3, 7, 10), "mmaj7": (0, 3, 7, 11), "6": (0, 4, 7, 9), "m6": (0, 3, 7, 9),
    "9": (0, 4, 7, 10, 14), "maj9": (0, 4, 7, 11, 14), "m9": (0, 3, 7, 10, 14),
    "add9": (0, 4, 7, 14), "madd9": (0, 3, 7, 14), "6/9": (0, 4, 7, 9, 14),
    "sus2": (0, 2, 7), "sus4": (0, 5, 7), "7sus4": (0, 5, 7, 10), "9sus4": (0, 5, 7, 10, 14),
    "dim": (0, 3, 6), "dim7": (0, 3, 6, 9), "m7b5": (0, 3, 6, 10), "aug": (0, 4, 8),
    "maj7#11": (0, 4, 7, 11, 18), "m11": (0, 3, 7, 10, 14, 17), "13": (0, 4, 7, 10, 14, 21),
    "7b9": (0, 4, 7, 10, 13), "7#9": (0, 4, 7, 10, 15), "maj13": (0, 4, 7, 11, 14, 21),
}
DRUMS = set("kshoct")
NOTE_RE = re.compile(r"^([A-G])([#b]?)(-?\d)([>^!_]*)$")
CHORD_RE = re.compile(r"^([A-G])([#b]?)([^/]*)(?:/([A-G][#b]?))?$")


class SongError(Exception):
    pass


def pc(name):
    p = NAMES[name[0]]
    for ch in name[1:]:
        p += 1 if ch == "#" else -1 if ch == "b" else 0
    return p % 12


def midi_of(token):
    m = NOTE_RE.match(token)
    if not m:
        return None, ""
    letter, acc, octave, marks = m.groups()
    return 12 * (int(octave) + 1) + pc(letter + acc), marks


@dataclass
class Chord:
    name: str
    root: int
    pcs: frozenset
    bass: int
    tones: tuple

    @staticmethod
    def parse(name):
        if name in ("N.C.", "NC", "-"):
            return Chord(name, -1, frozenset(), -1, ())
        m = CHORD_RE.match(name)
        if not m or m.group(3) not in QUAL:
            raise SongError(f"I don't know the chord '{name}'")
        root = pc(m.group(1) + m.group(2))
        tones = QUAL[m.group(3)]
        bass = pc(m.group(4)) if m.group(4) else root
        return Chord(name, root, frozenset((root + t) % 12 for t in tones) | {bass}, bass, tones)


@dataclass
class Note:
    step: int
    length: int
    midi: int
    marks: str = ""
    drum: str = ""
    off: float = 0.0
    cut: float = 0.0


@dataclass
class Voice:
    name: str
    opts: dict
    notes: list = field(default_factory=list)
    active: list = field(default_factory=list)


@dataclass
class Bar:
    start: int
    grid: int
    beats: int
    unit: int
    section: str
    index: int


@dataclass
class Song:
    name: str
    tempo: float
    beats: int
    unit: int
    grid: int
    swing: float
    key: str
    form: list
    voices: dict
    chords: list          # (step, length, Chord)
    bars: int
    loop: bool = True
    master: dict = field(default_factory=dict)
    barmap: list = field(default_factory=list)
    times: list = field(default_factory=list)
    dyn: list = field(default_factory=list)
    tempos: list = field(default_factory=list)

    @property
    def steps(self):
        return len(self.times) - 1

    def bar_of(self, step):
        return self.barmap[bisect.bisect_right(self._starts(), step) - 1]

    def _starts(self):
        return [b.start for b in self.barmap]

    @property
    def step_sec(self):
        return 60.0 / self.tempo * self.beats / self.grid

    def chord_at(self, step):
        for s, n, c in self.chords:
            if s <= step < s + n:
                return c
        return None


def _num(v):
    try:
        return float(v)
    except ValueError:
        return v


def parse(path):
    path = Path(path)
    head = {"tempo": 100, "meter": "4/4", "grid": 8, "swing": 0, "key": "C major", "form": None, "loop": "yes"}
    voices, sections, order, master, section_opts = {}, {}, [], {}, {}
    cur = None
    for raw_no, raw in enumerate(path.read_text().splitlines(), 1):
        line = raw.split(" #", 1)[0].rstrip() if not raw.lstrip().startswith("#") else ""
        if not line.strip():
            continue
        word, _, rest = line.strip().partition(" ")
        rest = rest.strip()
        if word in head and cur is None:
            head[word] = rest
        elif word == "master":
            master = {k: _num(v) for k, v in (kv.split("=", 1) for kv in rest.split())}
        elif word == "voice":
            name, *kvs = rest.split()
            voices[name] = Voice(name, {k: _num(v) for k, v in (kv.split("=", 1) for kv in kvs)})
        elif word == "section":
            cur, *kvs = rest.split()
            sections[cur] = {}
            section_opts[cur] = dict(kv.split("=", 1) for kv in kvs)
            order.append(cur)
        elif cur is not None and "|" in line:
            sections[cur][word] = (raw_no, [b.split() for b in rest.split("|")[1:-1]])
        else:
            raise SongError(f"{path.name} line {raw_no}: I don't understand '{line.strip()}'")
    beats, unit = map(int, head["meter"].split("/"))
    grid = int(head["grid"])
    if grid % beats:
        raise SongError(f"{path.name}: grid {grid} does not split into {beats} beats")
    per_beat = grid / beats * unit
    form = head["form"].split() if head["form"] else order
    song = Song(path.stem, float(head["tempo"]), beats, unit, grid, float(head["swing"]), head["key"],
                form, voices, [], 0, head["loop"] == "yes", master)

    step0 = 0
    clock = 0.0
    levels = []
    held = {v: None for v in voices}

    def place(voice, vname, tok, step, where):
        subs = tok.split(",")
        for i, sub in enumerate(subs):
            if sub == "-":
                held[vname] = None
                continue
            off, cut = i / len(subs), (len(subs) - i - 1) / len(subs)
            if voice.opts.get("inst") == "drums":
                bad = [ch for ch in sub if ch not in DRUMS and ch not in ">_"]
                if bad:
                    raise SongError(f"{where}: unknown drum '{bad[0]}'")
                marks = "".join(ch for ch in sub if ch in ">_")
                n = Note(step, 1, 0, marks, "".join(ch for ch in sub if ch in DRUMS), off, cut)
            else:
                m, marks = midi_of(sub)
                if m is None:
                    raise SongError(f"{where}: '{sub}' is not a note")
                n = Note(step, 1, m, marks, "", off, cut)
            voice.notes.append(n)
            held[vname] = n

    for sec in form:
        if sec not in sections:
            raise SongError(f"{path.name}: the form names section '{sec}' but there is none")
        lines = sections[sec]
        opts = section_opts[sec]
        sbeats, sunit = map(int, opts.get("meter", head["meter"]).split("/"))
        sgrid = int(opts.get("grid", grid))
        if sgrid % sbeats or sgrid / sbeats * sunit != per_beat:
            raise SongError(f"{path.name}: section {sec} needs the same steps per beat as the song")
        if "chords" not in lines:
            raise SongError(f"{path.name}: section {sec} has no chords line")
        ln, cbars = lines["chords"]
        cbars = [list(b) for b in cbars]
        nbars = len(cbars)
        sec_tempo = float(opts.get("tempo", song.tempo))
        rit_bars, rit_to = 0, 1.0
        if "rit" in opts:
            rb, rt = opts["rit"].split(":")
            rit_bars, rit_to = int(rb), float(rt)
        for b in range(nbars):
            song.barmap.append(Bar(step0 + b * sgrid, sgrid, sbeats, sunit, sec, b))
            for i in range(sgrid):
                done = (b + i / sgrid - (nbars - rit_bars)) / rit_bars if rit_bars else -1
                bpm = sec_tempo * (1 + (rit_to - 1) * max(0.0, done))
                song.times.append(clock)
                song.tempos.append(bpm)
                clock += 60.0 / bpm * sbeats / sgrid
        if "dyn" in lines:
            dln, dbars = lines["dyn"]
            vals = [float(x[0]) for x in dbars]
            if len(vals) == 1:
                vals = vals * nbars
            if len(vals) != nbars:
                raise SongError(f"{path.name} line {dln}: dyn has {len(vals)} bars, chords have {nbars}")
        else:
            vals = [1.0] * nbars
        levels += [(step0 + b * sgrid, v) for b, v in enumerate(vals)]
        for b, bar in enumerate(cbars):
            if bar == ["%"]:
                bar = cbars[b - 1]
                cbars[b] = bar
            if not bar or sgrid % len(bar):
                raise SongError(f"{path.name} line {ln}: bar {b + 1} splits {sgrid} steps into {len(bar)} chords unevenly")
            each = sgrid // len(bar)
            for i, cname in enumerate(bar):
                song.chords.append((step0 + b * sgrid + i * each, each, Chord.parse(cname)))
        for vname, voice in voices.items():
            if vname not in lines:
                held[vname] = None
                continue
            ln, bars = lines[vname]
            bars = [list(b) for b in bars]
            if bars == [["auto"]]:
                voice.active.append((step0, step0 + nbars * sgrid))
                held[vname] = None
                continue
            if len(bars) == 1 and len(bars[0]) == 1 and bars[0][0].startswith("@"):
                m = re.match(r"^@(\w+)([+-]\d+)?$", bars[0][0])
                if not m or m.group(1) not in voices:
                    raise SongError(f"{path.name} line {ln}: {vname} copies '{bars[0][0]}', which is not a voice above it")
                shift = int(m.group(2) or 0)
                for n in voices[m.group(1)].notes:
                    if step0 <= n.step < step0 + nbars * sgrid:
                        voice.notes.append(Note(n.step, n.length, n.midi + shift, n.marks, n.drum, n.off, n.cut))
                held[vname] = None
                continue
            if len(bars) == 1:
                bars = bars * nbars
            if len(bars) != nbars:
                raise SongError(f"{path.name} line {ln}: {vname} has {len(bars)} bars, chords have {nbars}")
            for b, bar in enumerate(bars):
                if bar == ["%"]:
                    bar = bars[b - 1]
                    bars[b] = bar
                if len(bar) != sgrid:
                    raise SongError(f"{path.name} line {ln}: {vname} bar {b + 1} has {len(bar)} steps, needs {sgrid}")
                for i, tok in enumerate(bar):
                    step = step0 + b * sgrid + i
                    if tok == ".":
                        if held[vname] is not None:
                            held[vname].length = step + 1 - held[vname].step
                    elif tok == "-":
                        held[vname] = None
                    else:
                        place(voice, vname, tok, step, f"{path.name} line {ln}: {vname} bar {b + 1}")
        for extra in lines:
            if extra not in ("chords", "dyn") and extra not in voices:
                raise SongError(f"{path.name} line {lines[extra][0]}: no voice named '{extra}'")
        step0 += nbars * sgrid
    song.times.append(clock)
    xs = [x for x, _ in levels] + [step0]
    ys = [y for _, y in levels] + [levels[0][1] if song.loop else levels[-1][1]]
    song.dyn = [_glide(xs, ys, st) for st in range(step0)]
    song.bars = len(song.barmap)
    _auto_parts(song)
    return song


def _glide(xs, ys, x):
    i = bisect.bisect_right(xs, x) - 1
    if i >= len(xs) - 1:
        return ys[-1]
    return ys[i] + (ys[i + 1] - ys[i]) * (x - xs[i]) / (xs[i + 1] - xs[i])


def _voice_chord(chord, prev, lo, hi, size):
    """Pick chord notes between lo and hi that move as little as possible from the last voicing."""
    if chord.root < 0:
        return []
    pcs = [(chord.root + t) % 12 for t in chord.tones]
    if len(pcs) > size:
        drop = [p for p in pcs if (p - chord.root) % 12 == 7]
        pcs = [p for p in pcs if p not in drop][:size] if drop else pcs[:size]
    cands = [m for m in range(lo, hi + 1) if m % 12 in pcs]
    best = None
    import itertools
    for combo in itertools.combinations(cands, len(pcs)):
        if {m % 12 for m in combo} != set(pcs) or combo[-1] - combo[0] > 16:
            continue
        cost = sum(min(abs(m - p) for p in prev) for m in combo) if prev else abs(sum(combo) / len(combo) - (lo + hi) / 2)
        cost += sum(6 if b - a == 1 else 3 if b - a == 2 and a < 60 else 0 for a, b in zip(combo, combo[1:]))
        if best is None or cost < best[0]:
            best = (cost, combo)
    return list(best[1]) if best else sorted(cands[: len(pcs)])


def _auto_parts(song):
    for v in song.voices.values():
        auto = str(v.opts.get("auto", ""))
        if not auto:
            continue
        lo, hi = int(v.opts.get("lo", 50)), int(v.opts.get("hi", 74))
        size = int(v.opts.get("size", 4))
        prev = []
        kind, _, style = auto.partition(":")
        rate = int(v.opts.get("rate", 1))
        for s, n, c in song.chords:
            if not any(a <= s < b for a, b in v.active):
                continue
            notes = _voice_chord(c, prev, lo, hi, size)
            if not notes:
                continue
            prev = notes
            if kind == "chords":
                for m in notes:
                    v.notes.append(Note(s, n, m))
            elif kind == "arp":
                seq = notes if style in ("", "up") else notes[::-1] if style == "down" else notes + notes[-2:0:-1]
                if style == "broken":
                    seq = [notes[0], notes[2 % len(notes)], notes[1], notes[-1]]
                for i, st in enumerate(range(s, s + n, rate)):
                    v.notes.append(Note(st, rate, seq[i % len(seq)]))
            elif kind == "comp":
                pat = str(v.opts.get("pattern", "x" * song.bar_of(s).grid))
                if v.opts.get("roots"):
                    notes = [lo + (c.root - lo) % 12]
                hit = None
                for i in range(n):
                    ch = pat[(s + i - song.bar_of(s).start) % len(pat)]
                    if ch == "x":
                        hit = [Note(s + i, 1, m) for m in notes]
                        v.notes.extend(hit)
                    elif ch == "g":
                        v.notes.extend(Note(s + i, 1, m, cut=0.5) for m in notes)
                        hit = [Note(s + i, 1, m, off=0.5) for m in notes]
                        v.notes.extend(hit)
                    elif ch == "." and hit:
                        for h in hit:
                            h.length += 1
                    else:
                        hit = None
            elif kind == "root":
                v.notes.append(Note(s, n, lo + (c.bass - lo) % 12))
