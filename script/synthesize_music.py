#!/usr/bin/env python3
"""
Tạo 3 bản nhạc nền gốc (tự tổng hợp bằng code, không dùng sample của ai)
cho Anniversary Memories. Vì do chính dự án tạo ra nên được dùng tự do.

    python3 script/synthesize_music.py   # cần numpy + ffmpeg
Xuất ra public/music/*.m4a
"""
import os, subprocess, tempfile, wave
import numpy as np

SR = 44100
OUT = os.path.join(os.path.dirname(__file__), "..", "public", "music")
NOTE = {n: i for i, n in enumerate("C C# D D# E F F# G G# A A# B".split())}

def freq(name):
    n, octave = name[:-1], int(name[-1])
    return 440.0 * 2 ** ((NOTE[n] + 12 * (octave + 1) - 69) / 12)

def piano(f, dur, vel=0.5):
    t = np.arange(int(dur * SR)) / SR
    out = np.zeros_like(t)
    for k in range(1, 9):
        fk = f * k * (1 + 0.0004 * k * k)
        if fk > SR / 2: break
        out += (1 / k ** 1.6) * np.sin(2 * np.pi * fk * t) * np.exp(-t * (0.9 + 0.55 * k))
    att = np.minimum(1, t / 0.006)
    return vel * out * att

def pluck(f, dur, vel=0.4):
    t = np.arange(int(dur * SR)) / SR
    out = np.zeros_like(t)
    for k in range(1, 6):
        out += (1 / k ** 2) * np.sin(2 * np.pi * f * k * t) * np.exp(-t * (3.0 + 1.5 * k))
    return vel * out * np.minimum(1, t / 0.004)

def pad(freqs, dur, vel=0.12):
    t = np.arange(int(dur * SR)) / SR
    out = np.zeros_like(t)
    for f in freqs:
        for d in (-0.15, 0.0, 0.15):
            ff = f * 2 ** (d / 12)
            out += np.sin(2 * np.pi * ff * t) + 0.25 * np.sin(2 * np.pi * 2 * ff * t)
    env = np.minimum(1, t / 1.2) * np.minimum(1, (dur - t) / 1.2).clip(0, 1)
    return vel * out / (3 * len(freqs)) * env

def place(buf, sig, start):
    i = int(start * SR)
    j = min(len(buf), i + len(sig))
    if i < len(buf): buf[i:j] += sig[: j - i]

def render(path, total, beat, chords, arp_pattern, voice, bass_vel, pad_vel, notes_per_beat):
    buf = np.zeros(int(total * SR) + SR * 4)
    bar = beat * 4
    t, ci = 0.0, 0
    while t < total:
        chord = chords[ci % len(chords)]
        root = chord[0]
        place(buf, piano(freq(root), bar * 1.5, bass_vel), t)
        place(buf, pad([freq(n) for n in chord[1:]], bar, pad_vel), t)
        step = beat / notes_per_beat
        for s in range(int(4 * notes_per_beat)):
            idx = arp_pattern[s % len(arp_pattern)]
            if idx is None: continue
            place(buf, voice(freq(chord[1:][idx % (len(chord) - 1)]), 2.5, 0.33), t + s * step)
        t += bar; ci += 1
    buf = buf[: int(total * SR)]
    n = len(buf); tt = np.arange(n) / SR
    buf *= np.minimum(1, tt / 2.0) * np.minimum(1, (total - tt) / 4.0)
    buf /= np.max(np.abs(buf)) + 1e-9
    stereo = np.stack([buf, np.roll(buf, int(0.012 * SR))], axis=1)
    pcm = (stereo * 0.8 * 32767).astype(np.int16)
    with tempfile.NamedTemporaryFile(suffix=".wav", delete=False) as tmp:
        with wave.open(tmp.name, "wb") as w:
            w.setnchannels(2); w.setsampwidth(2); w.setframerate(SR); w.writeframes(pcm.tobytes())
        subprocess.run(["ffmpeg", "-y", "-loglevel", "error", "-i", tmp.name,
                        "-af", "aecho=0.8:0.6:70|140|230:0.30|0.20|0.12,loudnorm=I=-18:TP=-2:LRA=11",
                        "-ar", "44100", "-c:a", "aac", "-b:a", "128k", path], check=True)
        os.unlink(tmp.name)
    print("wrote", path)

if __name__ == "__main__":
    os.makedirs(OUT, exist_ok=True)
    # 1. Piano nhẹ nhàng — F: I V vi IV, 70 bpm
    render(os.path.join(OUT, "piano_nhe_nhang.m4a"), 96, 60 / 70,
           [["F2", "F4", "A4", "C5"], ["C2", "E4", "G4", "C5"], ["D2", "D4", "F4", "A4"], ["A#1", "D4", "F4", "A#4"]],
           [0, 1, 2, 1, 0, 1, 2, 1], piano, 0.55, 0.10, 2)
    # 2. Ấm áp — C: I vi IV V, chậm, nhiều pad
    render(os.path.join(OUT, "am_ap.m4a"), 96, 60 / 60,
           [["C2", "E4", "G4", "C5"], ["A1", "C4", "E4", "A4"], ["F1", "C4", "F4", "A4"], ["G1", "D4", "G4", "B4"]],
           [0, None, 2, None, 1, None, 2, None], piano, 0.45, 0.22, 2)
    # 3. Vui tươi — G: I IV V I, 100 bpm, pluck
    render(os.path.join(OUT, "vui_tuoi.m4a"), 96, 60 / 100,
           [["G2", "G4", "B4", "D5"], ["C3", "G4", "C5", "E5"], ["D3", "F#4", "A4", "D5"], ["G2", "G4", "B4", "D5"]],
           [0, 2, 1, 2, 0, 2, 1, 2, 0, 1, 2, 1, 0, 2, 1, 2], pluck, 0.45, 0.06, 4)
