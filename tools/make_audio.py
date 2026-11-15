"""Synthesises the game's sound effects and ambient loop (mono 22 kHz WAV)."""
import wave
from pathlib import Path
import numpy as np

SR = 22050
OUT = Path("assets/audio")
rng = np.random.default_rng(3)


def t(d):
    return np.arange(int(SR * d)) / SR


def env(n, a=0.005, r=0.2):
    e = np.ones(n)
    na, nr = int(SR * a), int(SR * r)
    if na:
        e[:na] = np.linspace(0, 1, na)
    if nr:
        e[-nr:] *= np.linspace(1, 0, nr) ** 2
    return e


def noise(d):
    return rng.uniform(-1, 1, int(SR * d))


def lowpass(x, k):
    y = np.zeros_like(x)
    acc = 0.0
    for i, v in enumerate(x):
        acc += k * (v - acc)
        y[i] = acc
    return y


def write(name, x, gain=0.8):
    x = np.asarray(x, np.float64)
    peak = np.max(np.abs(x)) or 1
    x = x / peak * gain
    data = (np.clip(x, -1, 1) * 32767).astype(np.int16)
    with wave.open(str(OUT / f"{name}.wav"), "wb") as w:
        w.setnchannels(1)
        w.setsampwidth(2)
        w.setframerate(SR)
        w.writeframes(data.tobytes())


# UI select: soft glassy blip
tt = t(0.12)
write("select", (np.sin(2 * np.pi * 880 * tt) + 0.5 * np.sin(2 * np.pi * 1320 * tt)) * np.exp(-tt * 30), 0.45)
# rotate tick
tt = t(0.04)
write("rotate", np.sin(2 * np.pi * 1900 * tt) * np.exp(-tt * 120) + 0.3 * noise(0.04) * np.exp(-tt * 200), 0.3)
# pickaxe swing whoosh
d = 0.28
tt = t(d)
x = lowpass(noise(d), 0.08) * np.sin(np.pi * tt / d) ** 2
write("swing", x, 0.5)
# pickaxe strike: metallic clang + energy
d = 0.6
tt = t(d)
clang = sum(np.sin(2 * np.pi * f * tt) * np.exp(-tt * k) for f, k in ((620, 7), (1490, 10), (2730, 14), (3910, 18)))
zap = np.sin(2 * np.pi * (300 + 900 * tt) * tt) * np.exp(-tt * 6) * 0.6
write("strike", clang + zap + 0.4 * noise(d) * np.exp(-tt * 60), 0.7)
# ricochet ping
d = 0.35
tt = t(d)
write("ricochet", (np.sin(2 * np.pi * (2400 - 1500 * tt) * tt) + 0.4 * np.sin(2 * np.pi * 3600 * tt)) * np.exp(-tt * 14), 0.5)
# miss fizzle (quiet)
d = 0.3
tt = t(d)
write("miss", lowpass(noise(d), 0.3) * np.exp(-tt * 12) + 0.3 * np.sin(2 * np.pi * 180 * tt) * np.exp(-tt * 10), 0.3)
# target hit / success chime
d = 0.9
tt = t(d)
chime = sum(np.sin(2 * np.pi * f * tt) * np.exp(-tt * 4) * (tt >= o) for f, o in ((660, 0), (880, 0.08), (1320, 0.16)))
write("hit", chime + 0.3 * noise(d) * np.exp(-tt * 40), 0.6)
# rocks crumble
d = 1.4
tt = t(d)
x = np.zeros(int(SR * d))
for _ in range(40):
    s = int(rng.uniform(0, d * 0.8) * SR)
    n = int(SR * rng.uniform(0.04, 0.15))
    seg = lowpass(rng.uniform(-1, 1, n), rng.uniform(0.05, 0.25)) * np.exp(-np.arange(n) / SR * 30)
    x[s:s + n] += seg[: len(x[s:s + n])] * rng.uniform(0.3, 1)
x += lowpass(noise(d), 0.02) * np.exp(-tt * 2) * 3
write("crumble", x, 0.75)
# elevator / machinery motor
d = 2.2
tt = t(d)
motor = np.sign(np.sin(2 * np.pi * 55 * tt)) * 0.3 + np.sin(2 * np.pi * 110 * tt) * 0.4
clank = np.zeros_like(tt)
for k in np.arange(0, d, 0.18):
    i = int(k * SR)
    n = int(0.05 * SR)
    clank[i:i + n] += np.sin(2 * np.pi * 900 * np.arange(len(clank[i:i + n])) / SR) * np.exp(-np.arange(len(clank[i:i + n])) / SR * 70)
write("machine", (lowpass(motor, 0.15) + 0.5 * clank) * env(len(tt), 0.2, 0.5), 0.6)
# worm roar
d = 1.8
tt = t(d)
f = 70 + 30 * np.sin(2 * np.pi * 3 * tt)
roar = np.sin(2 * np.pi * np.cumsum(f) / SR) + 0.6 * np.sin(2 * np.pi * np.cumsum(f * 2.02) / SR)
roar = roar * (1 + 0.5 * lowpass(noise(d), 0.05)) + 0.8 * lowpass(noise(d), 0.12)
write("roar", roar * env(len(tt), 0.15, 0.6), 0.8)
# worm hurt
d = 0.9
tt = t(d)
hurt = np.sin(2 * np.pi * np.cumsum(220 - 120 * tt) / SR) * (1 + lowpass(noise(d), 0.2)) + 0.6 * lowpass(noise(d), 0.25)
write("worm_hurt", hurt * env(len(tt), 0.01, 0.5), 0.75)
# attack charge
d = 1.2
tt = t(d)
write("charge", np.sin(2 * np.pi * np.cumsum(200 + 500 * tt) / SR) * tt / d * (1 + 0.3 * np.sin(2 * np.pi * 18 * tt)), 0.4)
# attack shot
d = 0.5
tt = t(d)
write("blast", np.sin(2 * np.pi * np.cumsum(500 - 400 * tt) / SR) * np.exp(-tt * 6) + 0.4 * lowpass(noise(d), 0.3) * np.exp(-tt * 10), 0.6)
# shield damage
d = 0.7
tt = t(d)
write("damage", (np.sin(2 * np.pi * 150 * tt) + lowpass(noise(d), 0.4)) * np.exp(-tt * 6), 0.7)
# three knocks
d = 1.6
x = np.zeros(int(SR * d))
for k in (0.0, 0.45, 0.9):
    i = int(k * SR)
    n = int(0.25 * SR)
    tk = np.arange(n) / SR
    x[i:i + n] += (np.sin(2 * np.pi * 95 * tk) + 0.5 * lowpass(rng.uniform(-1, 1, n), 0.1)) * np.exp(-tk * 22)
write("knocks", x, 0.8)
# victory jingle
d = 2.0
tt = t(d)
notes = [(523, 0.0), (659, 0.18), (784, 0.36), (1046, 0.6)]
x = np.zeros_like(tt)
for f, o in notes:
    m = tt >= o
    x += np.sin(2 * np.pi * f * (tt - o)) * np.exp(-(tt - o) * 2.5) * m
write("victory", x, 0.55)
# ambient mine loop: low drone, wind, sparse drips. Seamless 12 s loop.
d = 12.0
tt = t(d)
drone = 0.5 * np.sin(2 * np.pi * 55 * tt) + 0.3 * np.sin(2 * np.pi * 82.5 * tt + 0.5 * np.sin(2 * np.pi * 0.25 * tt))
wind = lowpass(noise(d), 0.01) * (0.6 + 0.4 * np.sin(2 * np.pi * tt / d * 2))
x = drone * 0.35 + wind * 2.0
for k in (1.3, 4.1, 6.7, 9.2, 10.8):
    i = int(k * SR)
    n = int(0.3 * SR)
    tk = np.arange(n) / SR
    x[i:i + n] += 0.25 * np.sin(2 * np.pi * (1800 - 900 * tk) * tk) * np.exp(-tk * 18)
fade = int(0.5 * SR)
x[:fade] = x[:fade] * np.linspace(0, 1, fade) + x[-fade:] * np.linspace(1, 0, fade)
x = x[:-fade]
write("ambient", x, 0.35)
print("ok")

# boss fight loop: 120 bpm, D minor ostinato, kick/snare, low drone. 16 s.
bpm = 120
beat = 60 / bpm
d = beat * 32
tt = t(d)
x = np.zeros_like(tt)
notes = [73.4, 73.4, 87.3, 73.4, 98.0, 87.3, 69.3, 65.4]   # D2 D2 F2 D2 G2 F2 C#2 C2
for i in range(64):
    f = notes[i % 8] * (2 if (i // 16) % 2 else 1)
    s0 = int(i * beat / 2 * SR)
    n = int(beat / 2 * SR * 0.9)
    tk = np.arange(n) / SR
    saw = 2 * (tk * f % 1) - 1
    seg = lowpass(saw, 0.08) * np.exp(-tk * 5)
    x[s0:s0 + n] += seg[: len(x[s0:s0 + n])] * 0.5
for i in range(32):
    s0 = int(i * beat * SR)
    n = int(0.25 * SR)
    tk = np.arange(n) / SR
    if i % 2 == 0:
        kick = np.sin(2 * np.pi * (110 * np.exp(-tk * 20) + 40) * tk) * np.exp(-tk * 9)
        x[s0:s0 + n] += kick[: len(x[s0:s0 + n])] * 1.1
    else:
        sn = lowpass(rng.uniform(-1, 1, n), 0.5) * np.exp(-tk * 18)
        x[s0:s0 + n] += sn[: len(x[s0:s0 + n])] * 0.55
drone = 0.18 * np.sin(2 * np.pi * 36.7 * tt) + 0.1 * np.sin(2 * np.pi * 55 * tt + np.sin(2 * np.pi * 0.25 * tt))
x += drone
write("boss_music", x, 0.6)
print("music ok")
