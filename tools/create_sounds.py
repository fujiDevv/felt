"""Create Felt's original procedural material studies. No third-party audio.
These are designed textures, not field recordings. Deterministic for reproducible assets.
"""
import math, random, struct, wave
from pathlib import Path

ROOT = Path(__file__).resolve().parents[1] / 'Felt' / 'Sounds'
RATE = 44100
GESTURES = ['pinchIn', 'pinchOut', 'pinchEnd', 'rotate', 'swipe', 'forceClick', 'spaceSwitch']

def render(world, gesture, variation):
    rng = random.Random(f'felt/{world}/{gesture}/{variation}')
    duration = {'pinchEnd': .13, 'rotate': .14, 'forceClick': .19, 'spaceSwitch': .55, 'swipe': .30}.get(gesture, .26)
    n = int(duration * RATE)
    noise = [rng.uniform(-1, 1) for _ in range(n)]
    low, mid, slow = 0., 0., 0.
    samples = []
    offset = rng.uniform(.9, 1.1)
    for i in range(n):
        t = i / RATE
        u = i / n
        low += .035 * (noise[i] - low)
        mid += .28 * (noise[i] - mid)
        slow += .006 * (noise[i] - slow)
        env = (1 - math.exp(-t * 260)) * (1 - u) ** 2
        movement = gesture in ['pinchIn', 'pinchOut', 'swipe', 'spaceSwitch', 'pinchEnd']
        sweep = (1-u) if gesture == 'pinchIn' else u
        if world == 'paper':
            grain = (noise[i] - mid) * .26 + (mid - low) * .85
            fold = math.sin(t * 2 * math.pi * (95 * offset)) * math.exp(-t * 60) * .18
            crackle = noise[i] * (.8 if rng.random() < .003 else .03)
            s = (grain * (.5 + .5 * math.sin(t * 93)**2) + fold + crackle) * env
        elif world == 'cloth':
            grain = low * 2.6 + (mid - low) * .12
            brush = .35 + .65 * math.sin(math.pi * u) ** 2
            s = (grain * brush + math.sin(t * math.pi * 2 * 75 * offset) * math.exp(-t * 35) * .07) * env
        elif world == 'machine':
            click = (math.sin(t * 2 * math.pi * 780 * offset) * .30
                     + math.sin(t * 2 * math.pi * 1370 * offset) * .12) * math.exp(-t * 65)
            body = math.sin(t * 2 * math.pi * (145 if gesture == 'forceClick' else 240) * offset) * math.exp(-t * 30) * .45
            gear = (mid-low) * .18 * (math.sin(t * 2 * math.pi * 42) ** 8)
            s = (click + body + noise[i] * math.exp(-t * 130) * .35 + gear * int(movement)) * env
        else:
            # A rounded rubber pop with a small wooden resonator.
            f = (330 if gesture != 'forceClick' else 185) * offset
            phase = 2 * math.pi * (f * t + 95 * (1 - math.exp(-t * 24)) / 24)
            s = (math.sin(phase) * math.exp(-t * 22) * .45
                 + math.sin(t * 2 * math.pi * 970 * offset) * math.exp(-t * 55) * .08
                 + low * math.exp(-t * 28) * .7) * env
        if gesture == 'spaceSwitch':
            whoosh = (low * 2.3 + (mid-low) * (.3 + sweep)) * math.sin(math.pi * u) ** 2
            s = s * .3 + whoosh * .6
        elif gesture == 'swipe':
            s = s * .7 + (mid-low) * math.sin(math.pi * u) ** 2 * .25
        elif gesture == 'pinchOut':
            s *= .85
        samples.append(s)
    # Equal RMS target plus peak headroom; release remains deliberately quiet.
    rms = math.sqrt(sum(x*x for x in samples)/n)
    target = .065 if gesture == 'pinchEnd' else .105
    gain = min(target/max(rms, 1e-8), .65/max(max(abs(x) for x in samples), 1e-8))
    pcm = bytearray()
    for s in samples:
        # Dual mono allows the player node to position the sound consistently.
        v = int(max(-.95, min(.95, s*gain))*32767)
        pcm.extend(struct.pack('<hh', v, v))
    return pcm

ROOT.mkdir(parents=True, exist_ok=True)
for world in ['paper', 'cloth', 'machine', 'toy']:
    for gesture in GESTURES:
        for variation in range(1, 4):
            with wave.open(str(ROOT / f'{world}-{gesture}-{variation}.wav'), 'wb') as f:
                f.setnchannels(2); f.setsampwidth(2); f.setframerate(RATE)
                f.writeframes(render(world, gesture, variation))
print('Created 84 original WAV samples.')
