"""
Title-screen ambient BGM generator for 《借光 / Borrowed Light》.

Style reference: Hans Zimmer's  "Cornfield Chase"  atmospheric layer
-- low sustained drone, slow chord pad, sparse celesta-like stabs,
gradual swell from silence.  No samples,  no third-party audio.

Output:  title_bgm.wav     (mono 22.05 kHz 16-bit PCM, loopable)
Sibling file:  title_bgm.ogg  (converted if ffmpeg is available)

Run:  python3 assets/audio/generate_title_bgm.py
"""
import math, struct, wave, sys, subprocess, shutil
from pathlib import Path

RATE   = 22050
DUR    = 64.0           # seconds
N      = int(RATE * DUR)
OUT    = Path(__file__).with_name('title_bgm.wav')

samples = [0.0] * N

def env_tanh(t, attack=4.0, release=8.0, total=DUR):
    """gentle attack, slow decay; always 0 at both ends -> seamless loop."""
    x = (t - 0.0) / attack
    y = (DUR - t) / release
    return math.tanh(max(0, x)) * math.tanh(max(0, y))

def env_half(t, mid, width=2.5):
    """bell envelope centred at mid, width in seconds."""
    d = (t - mid) / width
    return math.exp(-d * d)

# --------- 1. Low drone (55 Hz + slow LFO on amplitude + slight detune) ---------
DRONE_BASE = 55.0
for i in range(N):
    t = i / RATE
    swell = env_tanh(t, attack=6.0, release=10.0)          # rises for 6 s
    # slow 8-second breath on volume
    breath = 0.55 + 0.45 * math.sin(2 * math.pi * t / 8.0)
    # detuned chorus to keep it from being perfectly flat
    detune_a = math.sin(2 * math.pi * (DRONE_BASE * 0.997) * t)
    detune_b = math.sin(2 * math.pi * (DRONE_BASE * 1.003) * t)
    samples[i] += 0.18 * swell * breath * (
        math.sin(2 * math.pi * DRONE_BASE * t) * 0.65
        + detune_a * 0.2
        + detune_b * 0.15
    )

# --------- 2. Slow-chord pad (synthesised, not sampled) ---------
# A minor -> F major -> C major -> G major cycle (all suspended / open voicings)
pads = [
    (220.00, 277.18, 329.63, 392.00),   # Am7 open
    (174.61, 220.00, 261.63, 329.63),   # Fmaj7 open
    (130.81, 164.81, 196.00, 246.94),   # C major spread
    (196.00, 246.94, 293.66, 392.00),   # G power-ish
]
pad_len = DUR / len(pads)
for idx, chord in enumerate(pads):
    for j in range(int(pad_len * RATE)):
        t = j / RATE
        i_global = int(idx * pad_len * RATE) + j
        # envelope fades smoothly between chords (no hard cut)
        env = math.sin(math.pi * t / pad_len) ** 2
        # reverb-ish smoothing via second harmonic + slight delay feedback (approx)
        tone = 0.0
        for k, f in enumerate(chord):
            tone += math.sin(2 * math.pi * f * t) * 0.25
            tone += math.sin(2 * math.pi * f * 2 * t) * 0.06   # soft octave up
        samples[i_global] += 0.075 * env * tone

# --------- 3. Sparse celesta / piano stabs (echoic, spaced) ---------
# pattern: midpoints across the piece, gets denser near the middle
stabs = [
    (8.0,  440.00, 0.045),   # A4
    (14.0, 392.00, 0.040),   # G4
    (20.0, 349.23, 0.050),   # F4
    (26.0, 440.00, 0.045),   # A4 (upbeat)
    (32.0, 293.66, 0.060),   # D4 (low stab for contrast)
    (38.0, 523.25, 0.045),   # C5
    (44.0, 392.00, 0.045),   # G4
    (50.0, 349.23, 0.045),   # F4
    (56.0, 440.00, 0.040),   # A4 (fading)
]
for start, hz, amp in stabs:
    for j in range(int(4.5 * RATE)):
        t = j / RATE
        # fast attack, long exponential decay, slight pitch bend at onset
        env = (1 - math.exp(-t / 0.08)) * math.exp(-t / 1.4) * \
              min(1.0, (4.5 - t) / 0.6)
        pitch_bend = 1.0 + 0.004 * math.exp(-t / 0.25)
        i = int((start + t) * RATE)
        if 0 <= i < N:
            samples[i] += amp * env * math.sin(2 * math.pi * hz * pitch_bend * t)
            # very slight second harmonic
            samples[i] += amp * 0.12 * env * math.sin(2 * math.pi * hz * pitch_bend * 2 * t)

# --------- 4. Final smooth tail: 4 s fade at very end + normalise ---------
tail_start = N - int(4 * RATE)
for i in range(tail_start, N):
    t = (i - tail_start) / RATE
    fade = 1.0 - t / 4.0
    samples[i] *= fade

peak = max(abs(x) for x in samples)
if peak < 1e-6:
    print("ERROR: zero volume?", file=sys.stderr); sys.exit(1)

with wave.open(str(OUT), 'wb') as w:
    w.setparams((1, 2, RATE, 0, 'NONE', 'not compressed'))
    w.writeframes(b''.join(struct.pack('<h', round(x / peak * 0.55 * 32767))
                           for x in samples))

print(f'WROTE  {OUT}  ({DUR:.0f} s, mono 22.05 kHz, peak 0.55)')

# Optional OGG conversion for Godot friendliness
if shutil.which('ffmpeg'):
    ogg = OUT.with_suffix('.ogg')
    subprocess.run([
        'ffmpeg', '-y', '-i', str(OUT), '-c:a', 'libvorbis',
        '-q:a', '3', str(ogg)
    ], capture_output=True, check=True)
    print(f'WROTE  {ogg}')
else:
    print('(ffmpeg not found -- skipping .ogg conversion)')

# Loop seam check
seam = abs(samples[0] - samples[-1]) / peak * 0.55 * 32767
print(f'seam delta: {seam:.1f}  (smaller = tighter loop)')
