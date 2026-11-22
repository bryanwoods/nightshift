"""Music rules, checked like the art rules. Errors stop a build. Hints are printed.

The melody is the voice marked role=melody. The bass is role=bass.
"""
from score import Chord

NAMES = ["C", "C#", "D", "Eb", "E", "F", "F#", "G", "Ab", "A", "Bb", "B"]


def name(m):
    return f"{NAMES[m % 12]}{m // 12 - 1}"


def where(song, step):
    b = song.bar_of(step)
    beat, sub = divmod(step - b.start, b.grid // b.beats)
    return f"bar {song.barmap.index(b) + 1} beat {beat + 1}" + (f"+{sub}" if sub else "")


def _fits(note_midi, chord):
    return chord is None or chord.root < 0 or note_midi % 12 in chord.pcs


LAMPLIGHT = [66, 69, 74, 73, 76, 74, 73, 71, 69, 71, 74, 74, 70, 69, 71, 74, 78, 79, 78, 76, 74, 71, 73, 74, 73]
COPY_RUN = 6


def _steps(pitches):
    return [b - a for a, b in zip(pitches, pitches[1:])]


def copied_run(pitches):
    """The longest stretch of melody moves shared with Lamplight, in any key."""
    x, y = _steps(pitches), _steps(LAMPLIGHT)
    best, prev = 0, [0] * (len(y) + 1)
    for a in x:
        cur = [0] * (len(y) + 1)
        for j, b in enumerate(y, 1):
            if a == b:
                cur[j] = prev[j - 1] + 1
                best = max(best, cur[j])
        prev = cur
    return best


def dna_count(pitches):
    """How often the theme's shape appears: two moves one way, then a small step back."""
    n = 0
    for a, b, c, d in zip(pitches, pitches[1:], pitches[2:], pitches[3:]):
        if (a < b < c and 1 <= c - d <= 2) or (a > b > c and 1 <= d - c <= 2):
            n += 1
    return n


def kinship(song):
    """Each (voice, longest copied run, shape count) among the melody voices."""
    out = []
    for v in song.voices.values():
        if v.opts.get("role") == "melody" and v.notes:
            p = [n.midi for n in sorted(v.notes, key=lambda n: (n.step, n.off))]
            out.append((v.name, copied_run(p), dna_count(p)))
    return out


def check(song):
    errors, hints = [], []
    mel = [v for v in song.voices.values() if v.opts.get("role") == "melody"]
    bas = [v for v in song.voices.values() if v.opts.get("role") == "bass"]
    for v in mel:
        _melody(song, v, errors, hints)
        for b in bas:
            _outer_voices(song, v, b, hints)
    for b in bas:
        _bass(song, b, errors)
    if song.name != "main_theme":
        kin = kinship(song)
        for name_, run, _dna in kin:
            if run >= COPY_RUN:
                hints.append(f"{song.name} {name_}: copies {run + 1} notes of Lamplight in a row")
        if kin and not any(d for *_, d in kin):
            hints.append(f"{song.name}: no melody uses the theme's shape")
    return errors, hints


def _sounding(notes, step):
    for n in notes:
        if n.step <= step < n.step + n.length:
            return n
    return None


def _resolves(notes, i, song):
    """A clashing note is fine when the next note steps to a note that fits."""
    if i + 1 >= len(notes):
        nxt = notes[0] if song.loop and notes else None
        nxt_step = song.steps if nxt else None
    else:
        nxt = notes[i + 1]
        nxt_step = nxt.step
    if nxt is None:
        return False
    gap = nxt_step - (notes[i].step + notes[i].length)
    c = song.chord_at(nxt.step)
    return gap <= 1 and abs(nxt.midi - notes[i].midi) <= 2 and _fits(nxt.midi, c)


def _melody(song, v, errors, hints):
    notes = sorted(v.notes, key=lambda n: n.step)
    if not notes:
        return
    beat = song.barmap[0].grid // song.barmap[0].beats
    index = {id(n): i for i, n in enumerate(notes)}

    # 1. strong beats land on notes that fit the chord, or lean into one by a step
    for bar in song.barmap:
        for s in ((0, bar.grid // 2) if bar.beats % 2 == 0 else (0,)):
            step = bar.start + s
            n = _sounding(notes, step)
            c = song.chord_at(step)
            if n is None or "!" in n.marks or _fits(n.midi, c):
                continue
            if _resolves(notes, index[id(n)], song):
                continue
            errors.append(f"{song.name} {v.name}: {name(n.midi)} clashes with {c.name} at {where(song, step)} "
                          f"and doesn't step to a note that fits")

    # 2. long notes don't sit on a clash
    for i, n in enumerate(notes):
        if n.length >= beat * 2 and "!" not in n.marks:
            for st in range(n.step, n.step + n.length):
                c = song.chord_at(st)
                if not _fits(n.midi, c) and not (st == n.step and _resolves(notes, i, song)):
                    late = st + 1 >= n.step + n.length - beat // 2
                    if not (late and _resolves(notes, i, song)):
                        errors.append(f"{song.name} {v.name}: long {name(n.midi)} sits on {c.name} at {where(song, st)}")
                        break

    # 3. big jumps are answered by a step back the other way
    for a, b, c in zip(notes, notes[1:], notes[2:]):
        jump = b.midi - a.midi
        if b.step - (a.step + a.length) > 2:
            continue
        if abs(jump) > 7:
            back = c.midi - b.midi
            if not (back * jump < 0 and abs(back) <= 4):
                hints.append(f"{song.name} {v.name}: the jump {name(a.midi)} to {name(b.midi)} at "
                             f"{where(song, b.step)} isn't answered by a step back")
        if abs(jump) in (6, 10, 11) and "!" not in b.marks:
            hints.append(f"{song.name} {v.name}: awkward jump {name(a.midi)} to {name(b.midi)} at {where(song, b.step)}")

    # 4. every four-bar phrase ends on a note that fits
    for bar in song.barmap:
        if bar.index % 4 != 3:
            continue
        end_bar = song.barmap.index(bar)
        lo, hi = bar.start, bar.start + bar.grid
        last = [n for n in notes if n.step < hi and n.step + n.length > lo]
        if last:
            n = last[-1]
            c = song.chord_at(max(n.step, lo))
            if not _fits(n.midi, c) and "!" not in n.marks and not _resolves(notes, index[id(n)], song):
                errors.append(f"{song.name} {v.name}: the phrase ending in bar {end_bar + 1} rests on "
                              f"{name(n.midi)}, which doesn't fit {c.name}")

    # 5. range and the high point
    lo, hi = min(n.midi for n in notes), max(n.midi for n in notes)
    if hi - lo > 19:
        hints.append(f"{song.name} {v.name}: range {name(lo)}-{name(hi)} is wider than an octave and a fifth")
    tops = [n for n in notes if n.midi == hi]
    if len(tops) > 3:
        hints.append(f"{song.name} {v.name}: the highest note {name(hi)} comes {len(tops)} times; one peak hits harder")

    # 6. the loop seam
    if song.loop and len(notes) > 1:
        jump = notes[0].midi - notes[-1].midi
        if abs(jump) > 9:
            hints.append(f"{song.name} {v.name}: the loop jumps {name(notes[-1].midi)} to {name(notes[0].midi)}")


def _outer_voices(song, mel, bass, hints):
    on = {}
    for n in bass.notes:
        on[n.step] = n.midi
    pairs = [(n.step, n.midi, on[n.step]) for n in sorted(mel.notes, key=lambda n: n.step) if n.step in on]
    for (s1, m1, b1), (s2, m2, b2) in zip(pairs, pairs[1:]):
        i1, i2 = (m1 - b1) % 12, (m2 - b2) % 12
        if i1 == i2 and i1 in (0, 7) and m1 != m2 and b1 != b2 and (m2 - m1) * (b2 - b1) > 0:
            kind = "octaves" if i1 == 0 else "fifths"
            hints.append(f"{song.name}: melody and bass move in parallel {kind} at {where(song, s2)}")


def _bass(song, v, errors):
    for n in v.notes:
        if song.bar_of(n.step).start == n.step:
            c = song.chord_at(n.step)
            if c and c.root >= 0 and n.midi % 12 not in c.pcs and "!" not in n.marks:
                errors.append(f"{song.name} {v.name}: {name(n.midi)} on the downbeat of {where(song, n.step)} "
                              f"isn't in {c.name}")
