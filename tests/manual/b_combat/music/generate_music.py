"""Codex-authored procedural prototype interior exploration loop; no samples."""
import math, wave, struct
from pathlib import Path
RATE, SECONDS = 22050, 32
N = RATE*SECONDS
samples = [0.0]*N
# Periodic machine bed: integer-cycle tones and slow modulation close the seam.
for i in range(N):
 t=i/RATE
 samples[i]=.10*math.sin(2*math.pi*55*t)*(1+.14*math.cos(2*math.pi*t/8)) + .035*math.sin(2*math.pi*110*t)
# Soft open voicings, gradual crossfades; no percussive warning-like notes.
chords = [(146.83,220,261.63),(130.81,196,293.66),(174.61,220,261.63),(146.83,196,293.66)]
for bar, chord in enumerate(chords):
 for j in range(10*RATE):
  t=j/RATE
  env=math.sin(math.pi*t/10)**2
  value=sum(math.sin(2*math.pi*f*t)+.12*math.sin(2*math.pi*f*2*t) for f in chord)*.045*env
  samples[(bar*8*RATE+j)%N]+=value
# Sparse, gently decaying notes with rounded attacks.
for start, hz in [(2,440),(6,392),(11,329.63),(15,293.66),(19,349.23),(23,440),(27,392),(30,293.66)]:
 for j in range(4*RATE):
  t=j/RATE
  env=(1-math.exp(-t/ .16))*math.exp(-t/ .8)*min(1,(4-t)/.4)
  samples[(start*RATE+j)%N]+=.065*env*math.sin(2*math.pi*hz*t)
peak=max(map(abs,samples))
with wave.open(str(Path(__file__).with_name('interior_exploration.wav')),'wb') as w:
 w.setparams((1,2,RATE,0,'NONE','not compressed'))
 w.writeframes(b''.join(struct.pack('<h',round(x/peak*.4*32767)) for x in samples))
print('32-second loop; peak 0.4; seam delta', abs(samples[0]-samples[-1])/peak*.4)
