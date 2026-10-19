#!/usr/bin/env python3
"""
Tạo các bản nhạc nền gốc (tự tổng hợp bằng code, không dùng sample của ai)
cho Anniversary Memories. Vì do chính dự án tạo ra nên được dùng tự do.

    python3 script/synthesize_music.py              # tạo tất cả (cần numpy + ffmpeg)
    python3 script/synthesize_music.py lofi_chill   # chỉ tạo một vài bản theo key
Xuất ra public/music/*.m4a
"""
import os, subprocess, sys, tempfile, wave
import numpy as np

SR = 44100
OUT = os.path.join(os.path.dirname(__file__), "..", "public", "music")
NOTE = {n: i for i, n in enumerate("C C# D D# E F F# G G# A A# B".split())}
ECHO = "aecho=0.8:0.6:70|140|230:0.30|0.20|0.12"
LIGHT_ECHO = "aecho=0.8:0.5:90|180:0.15|0.08"

def freq(name):
    n, octave = name[:-1], int(name[-1])
    return 440.0 * 2 ** ((NOTE[n] + 12 * (octave + 1) - 69) / 12)

def times(dur):
    return np.arange(int(dur * SR)) / SR

# ---------- nhạc cụ ----------

def piano(f, dur, vel=0.5):
    t = times(dur)
    out = np.zeros_like(t)
    for k in range(1, 9):
        fk = f * k * (1 + 0.0004 * k * k)
        if fk > SR / 2: break
        out += (1 / k ** 1.6) * np.sin(2 * np.pi * fk * t) * np.exp(-t * (0.9 + 0.55 * k))
    att = np.minimum(1, t / 0.006)
    return vel * out * att

def pluck(f, dur, vel=0.4):
    t = times(dur)
    out = np.zeros_like(t)
    for k in range(1, 6):
        out += (1 / k ** 2) * np.sin(2 * np.pi * f * k * t) * np.exp(-t * (3.0 + 1.5 * k))
    return vel * out * np.minimum(1, t / 0.004)

def guitar(f, dur, vel=0.4):
    # dây nylon: nhiều họa âm, tắt chậm hơn pluck, hơi lệch dây cho ấm
    t = times(dur)
    out = np.zeros_like(t)
    for k in range(1, 9):
        fk = f * k * (1 + 0.0002 * k)
        out += (1 / k ** 1.4) * np.sin(2 * np.pi * fk * t) * np.exp(-t * (1.1 + 0.9 * k))
    return vel * out * np.minimum(1, t / 0.003)

def ukulele(f, dur, vel=0.4):
    t = times(dur)
    out = np.zeros_like(t)
    for k in range(1, 7):
        out += (1 / k ** 1.5) * np.sin(2 * np.pi * f * k * t) * np.exp(-t * (2.2 + 1.3 * k))
    return vel * out * np.minimum(1, t / 0.003)

def bell(f, dur, vel=0.35):
    # hộp nhạc: họa âm không nguyên (kim loại), tắt nhanh
    t = times(dur)
    out = (np.sin(2 * np.pi * f * t) * np.exp(-t * 2.0)
           + 0.35 * np.sin(2 * np.pi * f * 2.76 * t) * np.exp(-t * 5.0)
           + 0.15 * np.sin(2 * np.pi * f * 5.40 * t) * np.exp(-t * 9.0))
    return vel * out * np.minimum(1, t / 0.002)

def bass(f, dur, vel=0.5):
    t = times(dur)
    out = np.sin(2 * np.pi * f * t) + 0.3 * np.sin(2 * np.pi * 2 * f * t)
    env = np.minimum(1, t / 0.01) * np.clip((dur - t) / 0.05, 0, 1)
    return vel * out * env

def pad(freqs, dur, vel=0.12):
    t = times(dur)
    out = np.zeros_like(t)
    for f in freqs:
        for d in (-0.15, 0.0, 0.15):
            ff = f * 2 ** (d / 12)
            out += np.sin(2 * np.pi * ff * t) + 0.25 * np.sin(2 * np.pi * 2 * ff * t)
    env = np.minimum(1, t / 1.2) * np.minimum(1, (dur - t) / 1.2).clip(0, 1)
    return vel * out / (3 * len(freqs)) * env

# ---------- trống ----------

def kick(vel=0.9):
    t = times(0.35)
    f = 45 + 95 * np.exp(-t * 28)
    return vel * np.sin(2 * np.pi * np.cumsum(f) / SR) * np.exp(-t * 9)

def snare(rng, vel=0.5):
    t = times(0.22)
    noise = rng.uniform(-1, 1, len(t))
    return vel * (0.7 * noise * np.exp(-t * 20) + 0.4 * np.sin(2 * np.pi * 185 * t) * np.exp(-t * 28))

def hat(rng, vel=0.18):
    t = times(0.06)
    noise = np.diff(rng.uniform(-1, 1, len(t) + 1))  # vi phân = lọc thông cao đơn giản
    return vel * noise * np.exp(-t * 70)

DRUMS = {"kick": lambda rng: kick(), "snare": snare, "hat": hat}

# ---------- dựng bản nhạc ----------

def place(buf, sig, start):
    i = int(start * SR)
    j = min(len(buf), i + len(sig))
    if i < len(buf): buf[i:j] += sig[: j - i]

def render(path, total, beat, chords, arp_pattern, voice, bass_vel, pad_vel, notes_per_beat,
           beats_per_bar=4, drums=None, bass_steps=None, swing=0.0, voice_dur=2.5, voice_vel=0.33,
           strum=0.0, echo=ECHO, pre_filter=None, crackle=0.0, seed=7):
    """arp_pattern: mỗi bước là chỉ số nốt trong hợp âm, None (nghỉ) hoặc "all" (cả hợp âm).
    drums: {"kick"|"snare"|"hat": [bước trong ô nhịp]}. bass_steps: các bước có tiếng bass ngắn
    (None = một nốt piano trầm dài mỗi ô nhịp như bản gốc)."""
    rng = np.random.default_rng(seed)
    buf = np.zeros(int(total * SR) + SR * 4)
    bar = beat * beats_per_bar
    steps = int(beats_per_bar * notes_per_beat)
    step = beat / notes_per_beat
    t, ci = 0.0, 0
    while t < total:
        chord = chords[ci % len(chords)]
        root, notes = chord[0], chord[1:]
        if bass_steps is None:
            place(buf, piano(freq(root), bar * 1.5, bass_vel), t)
        place(buf, pad([freq(n) for n in notes], bar, pad_vel), t)
        for s in range(steps):
            at = t + s * step + (swing * step if s % 2 else 0)
            if bass_steps is not None and s in bass_steps:
                place(buf, bass(freq(root), step * 0.9, bass_vel), at)
            for name, pattern in (drums or {}).items():
                if s in pattern:
                    place(buf, DRUMS[name](rng), at)
            idx = arp_pattern[s % len(arp_pattern)]
            if idx is None: continue
            if idx == "all":
                for k, n in enumerate(notes):
                    place(buf, voice(freq(n), voice_dur, voice_vel * 0.7), at + k * strum)
            else:
                place(buf, voice(freq(notes[idx % len(notes)]), voice_dur, voice_vel), at)
        t += bar; ci += 1
    buf = buf[: int(total * SR)]
    if crackle:
        # tiếng lách tách của đĩa than
        clicks = rng.random(len(buf)) < crackle / SR * 40
        buf += clicks * rng.uniform(-0.25, 0.25, len(buf))
    n = len(buf); tt = np.arange(n) / SR
    buf *= np.minimum(1, tt / 2.0) * np.minimum(1, (total - tt) / 4.0)
    buf /= np.max(np.abs(buf)) + 1e-9
    stereo = np.stack([buf, np.roll(buf, int(0.012 * SR))], axis=1)
    pcm = (stereo * 0.8 * 32767).astype(np.int16)
    af = ",".join(x for x in [pre_filter, echo, "loudnorm=I=-18:TP=-2:LRA=11"] if x)
    with tempfile.NamedTemporaryFile(suffix=".wav", delete=False) as tmp:
        with wave.open(tmp.name, "wb") as w:
            w.setnchannels(2); w.setsampwidth(2); w.setframerate(SR); w.writeframes(pcm.tobytes())
        subprocess.run(["ffmpeg", "-y", "-loglevel", "error", "-i", tmp.name,
                        "-af", af, "-ar", "44100", "-c:a", "aac", "-b:a", "128k", path], check=True)
        os.unlink(tmp.name)
    print("wrote", path)

TRACKS = {
    # 1. Piano nhẹ nhàng — F: I V vi IV, 70 bpm
    "piano_nhe_nhang": lambda p: render(p, 96, 60 / 70,
        [["F2", "F4", "A4", "C5"], ["C2", "E4", "G4", "C5"], ["D2", "D4", "F4", "A4"], ["A#1", "D4", "F4", "A#4"]],
        [0, 1, 2, 1, 0, 1, 2, 1], piano, 0.55, 0.10, 2),
    # 2. Ấm áp — C: I vi IV V, chậm, nhiều pad
    "am_ap": lambda p: render(p, 96, 60 / 60,
        [["C2", "E4", "G4", "C5"], ["A1", "C4", "E4", "A4"], ["F1", "C4", "F4", "A4"], ["G1", "D4", "G4", "B4"]],
        [0, None, 2, None, 1, None, 2, None], piano, 0.45, 0.22, 2),
    # 3. Vui tươi — G: I IV V I, 100 bpm, pluck
    "vui_tuoi": lambda p: render(p, 96, 60 / 100,
        [["G2", "G4", "B4", "D5"], ["C3", "G4", "C5", "E5"], ["D3", "F#4", "A4", "D5"], ["G2", "G4", "B4", "D5"]],
        [0, 2, 1, 2, 0, 2, 1, 2, 0, 1, 2, 1, 0, 2, 1, 2], pluck, 0.45, 0.06, 4),
    # 4. Ballad guitar — Am F C G, 76 bpm, rải dây nylon
    "guitar_ballad": lambda p: render(p, 100, 60 / 76,
        [["A1", "A3", "C4", "E4", "A4"], ["F1", "F3", "A3", "C4", "F4"],
         ["C2", "G3", "C4", "E4", "G4"], ["G1", "G3", "B3", "D4", "G4"]],
        [0, 2, 1, 3, 2, 1, 3, 2], guitar, 0.40, 0.05, 2, voice_dur=3.0, voice_vel=0.30),
    # 5. Waltz ngày cưới — 3/4, C Am F G7, kiểu "bùm-chát-chát"
    "waltz_ngay_cuoi": lambda p: render(p, 96, 60 / 138,
        [["C2", "E4", "G4", "C5"], ["A1", "E4", "A4", "C5"], ["F1", "F4", "A4", "C5"], ["G1", "F4", "G4", "B4"]],
        [None, "all", "all"], piano, 0.55, 0.08, 1, beats_per_bar=3, voice_dur=1.2, voice_vel=0.40),
    # 6. Hộp nhạc — F, 84 bpm, chuông cao trong trẻo
    "hop_nhac": lambda p: render(p, 96, 60 / 84,
        [["F2", "A5", "C6", "F6"], ["D2", "A5", "D6", "F6"], ["A#1", "A#5", "D6", "F6"], ["C2", "G5", "C6", "E6"]],
        [0, 2, 1, 2, 0, 2, 1, 3], bell, 0.30, 0.04, 2, voice_dur=2.0, voice_vel=0.30, echo=LIGHT_ECHO),
    # 7. Lofi chill — Dm7 G7 Cmaj7 Am7, 80 bpm, swing, trống nhẹ, lách tách đĩa than
    "lofi_chill": lambda p: render(p, 96, 60 / 80,
        [["D2", "F3", "A3", "C4", "E4"], ["G1", "F3", "B3", "D4", "G4"],
         ["C2", "E3", "G3", "B3", "D4"], ["A1", "G3", "C4", "E4", "A4"]],
        ["all", None, None, 2, None, "all", None, None], piano, 0.45, 0.06, 2,
        drums={"kick": [0, 5], "snare": [2, 6], "hat": [0, 1, 2, 3, 4, 5, 6, 7]}, bass_steps=[0, 3, 5],
        swing=0.18, voice_dur=1.8, voice_vel=0.32, strum=0.02, echo=LIGHT_ECHO,
        pre_filter="lowpass=f=3600", crackle=1.0),
    # 8. Pop sôi động — D A Bm G, 118 bpm, trống four-on-the-floor
    "pop_soi_dong": lambda p: render(p, 96, 60 / 118,
        [["D2", "D4", "F#4", "A4"], ["A1", "C#4", "E4", "A4"], ["B1", "D4", "F#4", "B4"], ["G1", "D4", "G4", "B4"]],
        [0, 1, 2, 1, 0, 2, 1, 2], pluck, 0.50, 0.07, 2,
        drums={"kick": [0, 2, 4, 6], "snare": [2, 6], "hat": [1, 3, 5, 7]}, bass_steps=[0, 1, 2, 3, 4, 5, 6, 7],
        voice_vel=0.30, echo=LIGHT_ECHO),
    # 9. Ukulele — C G Am F, 108 bpm, quạt chả "xuống - xuống lên - lên xuống"
    "ukulele_vui": lambda p: render(p, 96, 60 / 108,
        [["C2", "G4", "C4", "E4", "A4"], ["G1", "G4", "B3", "D4", "G4"],
         ["A1", "A4", "C4", "E4", "A4"], ["F1", "A4", "C4", "F4", "A4"]],
        ["all", None, "all", "all", None, "all", "all", None], ukulele, 0.35, 0.03, 2,
        drums={"hat": [1, 3, 5, 7]}, voice_dur=1.0, voice_vel=0.36, strum=0.014, echo=LIGHT_ECHO),
}

if __name__ == "__main__":
    os.makedirs(OUT, exist_ok=True)
    names = sys.argv[1:] or list(TRACKS)
    for name in names:
        TRACKS[name](os.path.join(OUT, f"{name}.m4a"))
