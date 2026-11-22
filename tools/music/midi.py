"""Write a Song as a standard MIDI file, so it opens in GarageBand, and read one back."""
import struct

PROGRAM = {"pulse": 80, "tri": 38, "bass": 33, "hum": 52, "guitar": 29, "epiano": 4, "bell": 8, "pad": 89, "flute": 79}
DRUM_KEY = {"k": 36, "s": 38, "h": 42, "o": 46, "c": 39, "t": 45, "m": 56, "p": 75}
TPQ = 480


def _vlq(n):
    out = [n & 0x7F]
    n >>= 7
    while n:
        out.append(0x80 | (n & 0x7F))
        n >>= 7
    return bytes(reversed(out))


def _track(events):
    events.sort(key=lambda e: (e[0], e[1]))
    data, last = b"", 0
    for tick, _order, msg in events:
        data += _vlq(tick - last) + msg
        last = tick
    data += b"\x00\xff\x2f\x00"
    return b"MTrk" + struct.pack(">I", len(data)) + data


def write(song, path):
    tps = TPQ * song.beats / song.grid * 4 / song.unit
    meta, last_tempo, last_meter = [], None, None
    for st, bpm in enumerate(song.tempos):
        us = int(60_000_000 / bpm)
        if us != last_tempo:
            meta.append((int(st * tps), 0, b"\xff\x51\x03" + us.to_bytes(3, "big")))
            last_tempo = us
    for b in song.barmap:
        if (b.beats, b.unit) != last_meter:
            meta.append((int(b.start * tps), 0, bytes([0xFF, 0x58, 0x04, b.beats, {2: 1, 4: 2, 8: 3}[b.unit], 24, 8])))
            last_meter = (b.beats, b.unit)
    tracks = [_track(meta)]
    ch = 0
    for v in song.voices.values():
        inst = v.opts.get("inst", "pulse")
        drum = inst == "drums"
        c = 9 if drum else ch
        name = v.name.encode()
        ev = [(0, 0, b"\xff\x03" + _vlq(len(name)) + name)]
        if not drum:
            ev.append((0, 1, bytes([0xC0 | c, PROGRAM.get(inst, 80)])))
            ch = ch + 1 if ch + 1 != 9 else 10
        vol = max(1, min(127, int(float(v.opts.get("vol", 0.5)) * 160)))
        for n in v.notes:
            vel = min(127, int(vol * (1.25 if ">" in n.marks else 1)))
            keys = [DRUM_KEY[d] for d in n.drum if d in DRUM_KEY] if drum else [n.midi]
            on = int((n.step + n.off) * tps)
            off = int((n.step + (1 if drum else n.length) - n.cut) * tps) - 1
            for k in keys:
                ev.append((on, 3, bytes([0x90 | c, k, vel])))
                ev.append((off, 2, bytes([0x80 | c, k, 0])))
        tracks.append(_track(ev))
    head = b"MThd" + struct.pack(">IHHH", 6, 1, len(tracks), TPQ)
    with open(path, "wb") as f:
        f.write(head + b"".join(tracks))


def read_notes(path):
    """Return {track name: [(start beat, length in beats, midi)]} from a MIDI file."""
    data = open(path, "rb").read()
    tpq = struct.unpack(">H", data[12:14])[0]
    pos, out, t_no = 14, {}, 0
    while pos < len(data):
        size = struct.unpack(">I", data[pos + 4:pos + 8])[0]
        chunk, pos = data[pos + 8:pos + 8 + size], pos + 8 + size
        i, tick, status, name, on, notes = 0, 0, 0, f"track{t_no}", {}, []
        t_no += 1
        while i < len(chunk):
            d = 0
            while True:
                b = chunk[i]; i += 1
                d = (d << 7) | (b & 0x7F)
                if b < 0x80:
                    break
            tick += d
            if chunk[i] >= 0x80:
                status = chunk[i]; i += 1
            if status == 0xFF:
                kind = chunk[i]; i += 1
                ln = 0
                while True:
                    b = chunk[i]; i += 1
                    ln = (ln << 7) | (b & 0x7F)
                    if b < 0x80:
                        break
                if kind == 0x03:
                    name = chunk[i:i + ln].decode(errors="replace")
                i += ln
            elif status in (0xF0, 0xF7):
                ln = chunk[i]; i += 1 + ln
            else:
                hi = status & 0xF0
                a = chunk[i]; i += 1
                b = 0
                if hi not in (0xC0, 0xD0):
                    b = chunk[i]; i += 1
                if hi == 0x90 and b > 0:
                    on[a] = tick
                elif hi in (0x80, 0x90) and a in on:
                    s = on.pop(a)
                    notes.append((s / tpq, (tick - s) / tpq, a))
        if notes:
            out[name] = sorted(notes)
    return out
