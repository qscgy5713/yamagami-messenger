#!/usr/bin/env python3
"""合成日式配樂(都節音階):箏撥弦、尺八風長音、低音持續音、風鈴/鐘、和太鼓。
用法:python3 tools/make_music.py  → 在 assets/audio/ 產生 *.ogg(需要 ffmpeg)。原創合成,無授權問題。"""
import math, random, struct, subprocess, os, wave

SR = 22050
OUT = os.path.join(os.path.dirname(__file__), "..", "assets", "audio")

def hz(midi): return 440.0 * 2 ** ((midi - 69) / 12.0)

# 都節音階相對根音的半音:0 1 5 7 8(D E♭ G A B♭ …)
SCALE = [0, 1, 5, 7, 8]
def note(root, idx):
    octv, d = divmod(idx, 5)
    return root + SCALE[d] + 12 * octv

def pluck(freq, dur, vol, bright=0.5):
    n = int(SR * dur)
    p = max(2, int(SR / freq))
    buf = [random.uniform(-1, 1) * bright + random.uniform(-1, 1) * (1 - bright) * 0.3 for _ in range(p)]
    out = []
    decay = 0.996 if freq > 300 else 0.998
    for i in range(n):
        j = i % p
        nxt = buf[(j + 1) % p]
        v = (buf[j] + nxt) * 0.5 * decay
        buf[j] = v
        env = 1.0 if i < n * 0.7 else (n - i) / (n * 0.3)
        out.append(v * vol * env)
    return out

def flute(freq, dur, vol):
    n = int(SR * dur)
    out = []
    ph = 0.0
    for i in range(n):
        t = i / SR
        vib = 1 + 0.012 * math.sin(2 * math.pi * 5.2 * t) * min(1.0, t / 0.5)
        ph += 2 * math.pi * freq * vib / SR
        a = min(1.0, t / 0.18) * min(1.0, (dur - t) / 0.5)
        tone = math.sin(ph) + 0.25 * math.sin(2 * ph) + 0.08 * math.sin(3 * ph)
        breath = random.uniform(-1, 1) * 0.07
        out.append((tone * 0.5 + breath) * vol * a)
    return out

def drone(freq, dur, vol):
    """低音持續音。頻率與顫音都量化成「整段剛好整數個週期」,首尾相接時沒有斷點,讓循環無縫。"""
    n = int(SR * dur)
    def q(f): return max(1, round(f * dur)) / dur
    f1, f2, f3, lfo = q(freq), q(freq * 1.5), q(freq * 2), 5.0 / dur
    out = []
    for i in range(n):
        t = i / SR
        s = math.sin(2 * math.pi * f1 * t) + 0.6 * math.sin(2 * math.pi * f2 * t) + 0.3 * math.sin(2 * math.pi * f3 * t)
        out.append(s * vol * (0.85 + 0.15 * math.sin(2 * math.pi * lfo * t)))
    return out

def bell(freq, dur, vol):
    n = int(SR * dur)
    out = []
    for i in range(n):
        t = i / SR
        e = math.exp(-t * 2.2)
        s = math.sin(2 * math.pi * freq * t) + 0.5 * math.sin(2 * math.pi * freq * 2.76 * t) + 0.25 * math.sin(2 * math.pi * freq * 5.4 * t)
        out.append(s * vol * e)
    return out

def taiko(vol):
    n = int(SR * 0.5)
    out = []
    for i in range(n):
        t = i / SR
        f = 70 + 60 * math.exp(-t * 18)
        out.append((math.sin(2 * math.pi * f * t) * math.exp(-t * 7) + random.uniform(-1, 1) * 0.25 * math.exp(-t * 40)) * vol)
    return out

def mix(buf, start_s, samples):
    s = int(start_s * SR)
    for i, v in enumerate(samples):
        k = s + i
        if k >= len(buf):
            k -= len(buf)  # 超出尾端的部分繞回開頭,讓循環無縫
        buf[k] += v

def render(name, root, bpm, seconds, density, flute_amt, bell_amt, drum, seed, mood_rise=True):
    random.seed(seed)
    buf = [0.0] * (SR * seconds)
    beat = 60.0 / bpm
    mix(buf, 0, drone(hz(root - 12), seconds, 0.07))
    mix(buf, 0, drone(hz(root - 5), seconds, 0.035))
    # 箏:琶音與短句
    idx = 5
    t = 0.0
    while t < seconds - 2:
        if random.random() < density:
            step = random.choice([-2, -1, -1, 1, 1, 2, 3, -3])
            idx = max(0, min(14, idx + step))
            midi = note(root, idx)
            mix(buf, t, pluck(hz(midi), 2.2, 0.22, 0.6))
            if random.random() < 0.25:
                mix(buf, t + beat * 0.5, pluck(hz(note(root, idx + 2)), 1.6, 0.14, 0.5))
        t += beat * random.choice([1, 1, 2, 0.5, 1])
    # 尺八風長音
    t = 4.0
    while t < seconds - 6 and flute_amt > 0:
        phrase = [random.choice([5, 7, 8, 10, 6]) for _ in range(random.choice([2, 3]))]
        for p_ in phrase:
            d = beat * random.choice([2.5, 3.5, 4])
            mix(buf, t, flute(hz(note(root + 12, p_ - 5)), d, 0.10 * flute_amt))
            t += d + beat * random.choice([0.5, 1])
        t += beat * random.choice([6, 8, 10])
    # 鐘 / 風鈴
    t = random.uniform(3, 7)
    while t < seconds - 4 and bell_amt > 0:
        mix(buf, t, bell(hz(note(root + 24, random.randint(0, 4))), 4.0, 0.05 * bell_amt))
        t += random.uniform(5, 11) / bell_amt
    # 太鼓
    if drum:
        t = 0.0
        while t < seconds - 1:
            mix(buf, t, taiko(0.45 if int(t / beat) % 4 == 0 else 0.22))
            t += beat
    peak = max(abs(v) for v in buf) or 1.0
    gain = 0.8 / peak
    wav = os.path.join(OUT, name + ".wav")
    with wave.open(wav, "wb") as w:
        w.setnchannels(1); w.setsampwidth(2); w.setframerate(SR)
        w.writeframes(b"".join(struct.pack("<h", int(max(-1, min(1, v * gain)) * 32767)) for v in buf))
    subprocess.run(["ffmpeg", "-y", "-loglevel", "error", "-i", wav, "-ac", "2", "-c:a", "vorbis", "-strict", "-2", "-q:a", "4", os.path.join(OUT, name + ".ogg")], check=True)
    os.remove(wav)
    print("ok", name)

if __name__ == "__main__":
    os.makedirs(OUT, exist_ok=True)
    #      name       root bpm  sec dens fl  bell drum seed
    render("title",    62, 58, 48, 0.55, 1.0, 1.0, False, 1)
    render("spring",   62, 66, 48, 0.65, 0.8, 1.0, False, 2)
    render("summer",   69, 76, 48, 0.8, 0.5, 2.0, False, 3)   # 風鈴多、節奏稍快
    render("autumn",   64, 54, 48, 0.5, 1.4, 0.8, False, 4)   # 尺八為主,較蕭瑟
    render("winter",   71, 50, 48, 0.35, 0.8, 1.6, False, 5)  # 稀疏、鐘聲
    render("boss",     62, 96, 36, 0.9, 0.4, 0.3, True, 6)
    render("finale",   62, 60, 56, 0.7, 1.2, 1.4, False, 7)
