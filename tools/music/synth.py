"""Turn a Song into stereo sound.

Chip voices are drawn band-limited (PolyBLEP), so high notes stay in tune and clean.
Notes that ring past the end of a loop wrap around to its start, and the room echo is
applied in a circle too, so the loop point has no click and no gap.
"""
import numpy as np
from scipy import signal

SR = 44100
RNG = np.random.default_rng(7)


def hz(m):
    return 440.0 * 2 ** ((m - 69) / 12)


def _blep(t, dt):
    y = np.zeros_like(t)
    a = t < dt
    x = t[a] / dt[a]
    y[a] = x + x - x * x - 1
    b = t > 1 - dt
    x = (t[b] - 1) / dt[b]
    y[b] = x * x + x + x + 1
    return y


def _phase(freq):
    return np.cumsum(freq / SR)


def pulse(freq, duty=0.5):
    ph = _phase(freq)
    dt = np.clip(freq / SR, 1e-6, 0.5)
    t = ph % 1.0
    d = duty if np.ndim(duty) else np.full_like(t, duty)
    y = np.where(t < d, 1.0, -1.0) + _blep(t, dt) - _blep((t - d) % 1.0, dt)
    return y - (2 * d - 1)


def saw(freq):
    ph = _phase(freq)
    dt = np.clip(freq / SR, 1e-6, 0.5)
    t = ph % 1.0
    return 2 * t - 1 - _blep(t, dt)


def tri(freq, steps=0):
    t = _phase(freq) % 1.0
    y = 4 * np.abs(t - 0.5) - 1
    if steps:
        y = np.round((y + 1) / 2 * (steps - 1)) / (steps - 1) * 2 - 1
    return y


def sine(freq):
    return np.sin(2 * np.pi * _phase(freq))


def env_adsr(n, gate_n, a=0.005, d=0.1, s=0.7, r=0.08):
    t = np.arange(n) / SR
    gt = gate_n / SR
    e = np.where(t < a, t / max(a, 1e-4), s + (1 - s) * np.exp(-(t - a) / max(d, 1e-4)))
    at_gate = np.interp(gt, t, e) if n else 0
    rel = at_gate * np.exp(-(t - gt) / max(r, 1e-4) * 3)
    return np.where(t < gt, e, rel)


def freq_path(n, f, prev_f=None, slide=0.05, vib_cents=0.0, vib_rate=5.5, vib_delay=0.25):
    t = np.arange(n) / SR
    fr = np.full(n, f)
    if prev_f:
        k = np.clip(t / slide, 0, 1)
        fr = prev_f * (f / prev_f) ** k
    if vib_cents:
        ramp = np.clip((t - vib_delay) / 0.3, 0, 1)
        fr = fr * 2 ** (vib_cents / 1200 * ramp * np.sin(2 * np.pi * vib_rate * t))
    return fr


def lowpass(x, cutoff, order=2):
    b, a = signal.butter(order, min(cutoff, SR * 0.45) / (SR / 2))
    return signal.lfilter(b, a, x)


def highpass(x, cutoff, order=2):
    b, a = signal.butter(order, cutoff / (SR / 2), "high")
    return signal.lfilter(b, a, x)


# ---------------------------------------------------------------- instruments
# Each takes (midi, seconds held, options, previous midi) and returns a mono array
# that includes its release tail.

def _len(held, rel):
    return int((held + rel + 0.02) * SR)


def i_pulse(m, held, o, prev):
    rel = float(o.get("rel", 0.08))
    n = _len(held, rel)
    fr = freq_path(n, hz(m), hz(prev) if prev else None, float(o.get("slide", 0.06)),
                   float(o.get("vib", 0)), float(o.get("vibrate", 5.5)), float(o.get("vibdelay", 0.22)))
    duty = float(o.get("duty", 0.5))
    if "duty2" in o:
        t = np.arange(n) / SR
        duty = duty + (float(o["duty2"]) - duty) * np.clip(t / float(o.get("sweep", 0.3)), 0, 1)
    y = pulse(fr, duty) * 0.5
    e = env_adsr(n, int(held * SR), float(o.get("att", 0.004)), float(o.get("dec", 0.15)),
                 float(o.get("sus", 0.75)), rel)
    y = y * e
    if "tone" in o:
        y = lowpass(y, float(o["tone"]))
    return y


def i_tri(m, held, o, prev):
    rel = float(o.get("rel", 0.04))
    n = _len(held, rel)
    fr = freq_path(n, hz(m), hz(prev) if prev else None, float(o.get("slide", 0.04)), float(o.get("vib", 0)))
    y = tri(fr, int(o.get("steps", 16))) * 0.8
    y = lowpass(y, float(o.get("tone", 5000)))
    return y * env_adsr(n, int(held * SR), 0.003, float(o.get("dec", 0.3)), float(o.get("sus", 0.85)), rel)


def i_bass(m, held, o, prev):
    """A round plucked bass: a soft body with a little string-like edge that fades fast."""
    rel = float(o.get("rel", 0.09))
    n = _len(held, rel)
    t = np.arange(n) / SR
    fr = freq_path(n, hz(m), hz(prev) if prev else None, 0.05, float(o.get("vib", 0)))
    fr = fr * 2 ** (-(float(o.get("scoop", 16)) / 1200) * np.exp(-t * 55))
    ph = _phase(fr)
    body = np.sin(2 * np.pi * ph) + 0.30 * np.sin(4 * np.pi * ph) + 0.09 * np.sin(6 * np.pi * ph)
    edge = lowpass(tri(fr), float(o.get("tone", 1500))) * np.exp(-t * float(o.get("pluck", 13)))
    e = env_adsr(n, int(held * SR), 0.007, float(o.get("dec", 0.38)), float(o.get("sus", 0.6)), rel)
    return (0.62 * body + 0.34 * edge) * e


def i_epiano(m, held, o, prev):
    """A warm FM electric piano: soft bell-like attack that mellows."""
    rel = float(o.get("rel", 0.25))
    n = _len(held, rel)
    t = np.arange(n) / SR
    f = hz(m)
    idx = 1.6 * np.exp(-t * 4.0) + 0.25
    tine = 0.5 * np.exp(-t * 30) * np.sin(2 * np.pi * f * 14 * t)
    y = np.sin(2 * np.pi * f * t + idx * np.sin(2 * np.pi * f * t) + tine)
    amp = np.exp(-t * float(o.get("decay", 1.1)))
    rel_e = np.where(t < held, 1.0, np.exp(-(t - held) / rel * 3))
    return 0.5 * y * amp * rel_e * np.clip(t / 0.003, 0, 1)


def i_bell(m, held, o, prev):
    """Celesta / music box: a pure tone with a glassy overtone."""
    n = int((held + float(o.get("ring", 1.6))) * SR)
    t = np.arange(n) / SR
    f = hz(m)
    y = (np.sin(2 * np.pi * f * t) + 0.35 * np.sin(2 * np.pi * f * 2 * t) * np.exp(-t * 3)
         + 0.18 * np.sin(2 * np.pi * f * 3.01 * t) * np.exp(-t * 6) + 0.08 * np.sin(2 * np.pi * f * 5.4 * t) * np.exp(-t * 12))
    return 0.45 * y * np.exp(-t * float(o.get("decay", 2.2))) * np.clip(t / 0.002, 0, 1)


def i_pad(m, held, o, prev):
    """Soft detuned strings / pad, filtered warm."""
    rel = float(o.get("rel", 0.6))
    n = _len(held, rel)
    f = hz(m)
    y = sum(saw(freq_path(n, f * 2 ** (c / 1200), vib_cents=float(o.get("vib", 6)), vib_rate=4.6 + c / 40, vib_delay=0.0))
            for c in (-7, 0, 6))
    y = lowpass(y / 3, float(o.get("tone", 1400)), 2)
    return 0.4 * y * env_adsr(n, int(held * SR), float(o.get("att", 0.35)), 0.5, 0.85, rel)


def i_flute(m, held, o, prev):
    """A breathy ocarina for tender melodies."""
    rel = float(o.get("rel", 0.12))
    n = _len(held, rel)
    fr = freq_path(n, hz(m), hz(prev) if prev else None, 0.06, float(o.get("vib", 14)), 5.2, 0.2)
    ph = _phase(fr)
    y = np.sin(2 * np.pi * ph) + 0.12 * np.sin(4 * np.pi * ph) + 0.05 * np.sin(6 * np.pi * ph)
    breath = lowpass(RNG.standard_normal(n), 2500) * 0.04
    e = env_adsr(n, int(held * SR), float(o.get("att", 0.03)), 0.2, 0.9, rel)
    return 0.5 * (y + breath) * e


def i_drums(token, o):
    out = []
    for ch in token:
        if ch == "k":
            n = int(0.3 * SR); t = np.arange(n) / SR
            f = 45 + 110 * np.exp(-t * 28)
            y = np.sin(2 * np.pi * np.cumsum(f) / SR) * np.exp(-t * 11) + 0.4 * np.exp(-t * 300) * RNG.standard_normal(n) * 0.2
            out.append(y * 0.9)
        elif ch in "sc":
            n = int(0.22 * SR); t = np.arange(n) / SR
            hold = 3 if ch == "s" else 2
            nz = np.repeat(RNG.uniform(-1, 1, n // hold + 1), hold)[:n]
            nz = signal.lfilter(*signal.butter(2, [900 / (SR / 2), 7000 / (SR / 2)], "band"), nz)
            body = np.sin(2 * np.pi * 185 * t) * np.exp(-t * 30) * (0.5 if ch == "s" else 0)
            out.append((nz * np.exp(-t * (16 if ch == "s" else 22)) * 1.4 + body) * 0.6)
        elif ch in "ho":
            n = int((0.05 if ch == "h" else 0.25) * SR); t = np.arange(n) / SR
            nz = highpass(np.repeat(RNG.uniform(-1, 1, n // 2 + 1), 2)[:n], 6000)
            out.append(nz * np.exp(-t * (70 if ch == "h" else 12)) * 0.5)
        elif ch == "t":
            n = int(0.3 * SR); t = np.arange(n) / SR
            f = 90 + 60 * np.exp(-t * 15)
            out.append(tri(f, 16) * np.exp(-t * 9) * 0.6)
    if not out:
        return np.zeros(1)
    L = max(len(a) for a in out)
    return sum(np.pad(a, (0, L - len(a))) for a in out)


INSTRUMENTS = {"pulse": i_pulse, "tri": i_tri, "bass": i_bass, "epiano": i_epiano, "bell": i_bell, "pad": i_pad, "flute": i_flute}


# ---------------------------------------------------------------- mixing

def _add_wrap(buf, start, y, wrap):
    L = len(buf)
    if wrap:
        idx = (start + np.arange(len(y))) % L
        np.add.at(buf, idx, y)
    else:
        end = min(L, start + len(y))
        if end > start:
            buf[start:end] += y[: end - start]


def _shift(x, d, wrap):
    if wrap:
        return np.roll(x, d)
    y = np.zeros_like(x)
    y[d:] = x[:-d] if d else x
    return y


def reverb_ir(seconds=1.8, damp=4000):
    n = int(seconds * SR)
    t = np.arange(n) / SR
    ir = RNG.standard_normal((2, n)) * np.exp(-t * 6.9 / seconds)
    ir = np.stack([lowpass(ch, damp) for ch in ir])
    ir[:, : int(0.012 * SR)] = 0
    return ir / np.sqrt(np.sum(ir ** 2, axis=1, keepdims=True))


def _conv(x, ir, wrap):
    L = len(x)
    if wrap:
        folded = np.zeros(L)
        for i in range(0, len(ir), L):
            seg = ir[i:i + L]
            folded[:len(seg)] += seg
        return np.fft.irfft(np.fft.rfft(x) * np.fft.rfft(folded), L)
    N = 1 << int(np.ceil(np.log2(L + len(ir))))
    return np.fft.irfft(np.fft.rfft(x, N) * np.fft.rfft(ir, N), N)[:L]


def render(song, loops=1, solo=None, mute=()):
    """Render the song. loops=1 gives a seamless loop for the game."""
    wrap = song.loop and loops == 1
    grid_x = np.arange(len(song.times))
    at = lambda x: float(np.interp(x, grid_x, song.times))
    L1 = int(round(song.times[-1] * SR))
    L = L1 * loops + (0 if wrap else int(3 * SR))
    mix = np.zeros((2, L))
    send = np.zeros((2, L))
    for v in song.voices.values():
        if (solo and v.name not in solo) or v.name in mute:
            continue
        o = v.opts
        mono = np.zeros(L)
        inst = o.get("inst", "pulse")
        gate = float(o.get("gate", 0.92))
        prev = None
        notes = sorted(v.notes, key=lambda n: (n.step, n.off, n.midi))
        shape = float(o.get("shape", 0))
        center = np.mean([n.midi for n in notes]) if notes and shape else 0
        human = float(o.get("human", 0))
        jitter = np.random.default_rng(len(v.name) * 31)
        for rep in range(loops):
            for n in notes:
                t0 = at(n.step + n.off)
                if song.swing and n.step % 2 == 1:
                    t0 += song.swing * (at(n.step + 1) - at(n.step))
                if human:
                    t0 += float(jitter.normal(0, human))
                start = max(0, int(round(t0 * SR))) + rep * L1
                bar = song.bar_of(n.step)
                pos = n.step - bar.start
                weight = 1.06 if pos == 0 else 1.02 if pos % (bar.grid // bar.beats) == 0 else 0.95
                vel = weight * song.dyn[n.step]
                vel *= 1.25 if ">" in n.marks else 0.7 if "_" in n.marks else 1.0
                if shape:
                    vel *= 1 + shape * (n.midi - center) / 12
                if inst == "drums":
                    y = i_drums(n.drum, o)
                else:
                    held = (at(n.step + n.length - n.cut) - t0) * gate
                    y = INSTRUMENTS[inst](n.midi, held, o, prev if "^" in n.marks else None)
                    prev = n.midi
                _add_wrap(mono, start, y * vel, wrap)
        if float(o.get("echo", 0)):
            beats = float(o.get("echotime", 0.75))
            d = int(beats * 60 / song.tempo * SR)
            fb = float(o["echo"])
            left, right = mono.copy(), mono.copy()
            for k in range(1, 5):
                tap = _shift(mono, d * k, wrap) * fb ** k
                (left if k % 2 else right)[:] += tap
            stereo = np.stack([left, right])
        else:
            stereo = np.stack([mono, mono])
        pan = float(o.get("pan", 0))
        g = float(o.get("vol", 0.5))
        lr = np.array([[np.cos((pan + 1) * np.pi / 4)], [np.sin((pan + 1) * np.pi / 4)]]) * np.sqrt(2)
        stereo = stereo * lr * g
        mix += stereo
        send += stereo * float(o.get("rev", 0.18))
    ir = reverb_ir(float(song.master.get("room", 1.8)), float(song.master.get("damp", 4200)))
    wet = np.stack([_conv(send[c], ir[c], wrap) for c in range(2)])
    out = mix + wet * float(song.master.get("wet", 0.5))
    out = np.stack([highpass(c, 28) for c in out]) if not wrap else out - out.mean(axis=1, keepdims=True)
    return master(out, float(song.master.get("loud", -17)))


def master(x, target_db=-17.0):
    rms = np.sqrt(np.mean(x ** 2)) + 1e-9
    x = x * (10 ** (target_db / 20) / rms)
    return np.tanh(x * 1.1) / np.tanh(1.1) * 0.97 if np.max(np.abs(x)) > 0.8 else x


def fade_tail(x, seconds=4.0):
    n = int(seconds * SR)
    x = x.copy()
    x[:, -n:] *= np.linspace(1, 0, n) ** 2
    return x
