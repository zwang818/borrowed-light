"""Codex procedural prototype laser 'biu'; no external samples."""
import math, struct, wave
from pathlib import Path
rate, duration = 44100, .18
phase = 0.0
samples = []
for i in range(round(rate*duration)):
 t = i/rate
 u = t/duration
 # Rapid descending pitch gives the rounded 'b-iu' articulation.
 hz = 260 + 2200*math.exp(-t/.035)
 phase += 2*math.pi*hz/rate
 envelope = min(t/.003,1)*min((duration-t)/.03,1)*math.exp(-t/.08)
 samples.append((math.sin(phase)+.22*math.sin(phase*2)+.08*math.sin(phase*3))*envelope)
peak = max(map(abs,samples))
with wave.open(str(Path(__file__).with_name('pulse_biu.wav')),'wb') as output:
 output.setparams((1,2,rate,0,'NONE','not compressed'))
 output.writeframes(b''.join(struct.pack('<h',round(v/peak*.3*32767)) for v in samples))
