"""Codex-authored procedural placeholder SFX; stdlib only, no sampled assets."""
import math, random, wave, struct, sys
from pathlib import Path
ROOT = Path(__file__).parent
# id: seconds, start Hz, end Hz, noise mix, pulse count
SOUNDS = {
 'player_step': (.14, 180, 145, 0.0, 1),
 'player_hurt': (.24, 480, 180, .2, 2),
 'player_shutdown': (.7, 420, 45, .12, 1),
 'enemy_hit': (.12, 1300, 320, .55, 1),
 'enemy_shutdown': (.55, 190, 35, .55, 3),
 'cleaner_warning': (.6, 620, 1050, .02, 3),
 'cleaner_attack': (.18, 240, 70, .7, 1),
 'sentry_warning': (.7, 900, 900, .01, 4),
 'sentry_fire': (.12, 680, 160, .35, 1),
 'protocol_enter': (.32, 330, 660, .01, 2),
 'protocol_exit': (.32, 660, 330, .01, 2),
 'repair': (.35, 400, 800, .01, 3),
 'weapon_pickup': (.4, 520, 1040, .01, 3),
 'scatter_fire': (.22, 180, 50, .85, 1),
 'boss_pulse_warning': (.8, 450, 1200, .03, 1),
 'boss_floor_warning': (.8, 140, 140, .12, 4),
 'hazard_warning': (.6, 720, 720, .04, 2),
}
def write_grating_step(variant):
 # Filtered, aperiodic contact layers; no pitched oscillator in the footstep.
 rng = random.Random(5100 + variant)
 duration = .155
 low = mid = fine = 0.0
 samples = []
 contacts = [(0.0, 1.0, .014), (.019 + rng.random()*.008, .36, .009),
             (.057 + rng.random()*.012, .16, .006),
             (.095 + rng.random()*.012, .08, .005)]
 for i in range(int(44100*duration)):
  t = i/44100
  noise = rng.uniform(-1, 1)
  low += .035*(noise-low)
  mid += .24*(noise-mid)
  fine += .52*(noise-fine)
  impact = sum(gain*min(max(t-onset,0)/.001,1)*math.exp(-max(t-onset,0)/decay)
               for onset, gain, decay in contacts if t >= onset)
  # Weighty sole contact, dry grille clack, then short irregular friction.
  body = low * 3.2 * math.exp(-t/.022)
  clack = (mid-low)*impact*1.7
  friction = (fine-mid)*.30*math.sin(math.pi*t/duration)**2*math.exp(-t/.055)
  value = (body+clack+friction)*min(t/.0015,1)*min((duration-t)/.018,1)
  samples.append(value)
 peak = max(abs(v) for v in samples)
 name = 'player_step' if variant == 0 else f'player_step_{variant+1}'
 with wave.open(str(ROOT/(name+'.wav')), 'wb') as output:
  output.setparams((1,2,44100,0,'NONE','not compressed'))
  output.writeframes(b''.join(struct.pack('<h',round(v/peak*.3*32767)) for v in samples))

if len(sys.argv) == 1 or 'player_step' in sys.argv[1:]:
 for variant in range(4):
  write_grating_step(variant)

for name, (duration, start, end, noise, pulses) in SOUNDS.items():
 if name == "player_step":
  continue
 if len(sys.argv) > 1 and name not in sys.argv[1:]:
  continue
 rng = random.Random(name)
 samples = []
 phase = 0.0
 for i in range(int(44100 * duration)):
  t = i / 44100
  u = t / duration
  phase += 2 * math.pi * (start + (end-start)*u) / 44100
  envelope = min(t/.008, 1) * min((duration-t)/.035, 1)
  pulse = (0.5 - 0.5*math.cos(2*math.pi*((u*pulses)%1))) if pulses > 1 else (1-u)**.6
  value = ((1-noise)*(math.sin(phase)+.2*math.sin(phase*2)) + noise*rng.uniform(-1,1))
  samples.append(value * envelope * pulse)
 peak = max(abs(v) for v in samples)
 with wave.open(str(ROOT / (name+'.wav')), 'wb') as output:
  output.setparams((1,2,44100,0,'NONE','not compressed'))
  output.writeframes(b''.join(struct.pack('<h',round(v/peak*.3*32767)) for v in samples))
