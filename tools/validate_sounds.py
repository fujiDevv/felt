"""Check short cue durations, stereo PCM format, peak headroom and faded boundaries."""
import array, json, math, wave
from pathlib import Path

root = Path(__file__).resolve().parents[1]
metrics = {}
for path in sorted((root / 'Felt' / 'Sounds').glob('*.wav')):
    with wave.open(str(path), 'rb') as file:
        assert (file.getnchannels(), file.getsampwidth(), file.getframerate()) == (2, 2, 44100), path.name
        count = file.getnframes()
        pcm = array.array('h', file.readframes(count))
    peak = max(abs(sample) for sample in pcm) / 32768
    rms = math.sqrt(sum(sample * sample for sample in pcm) / len(pcm)) / 32768
    duration = count / 44100
    assert 0.059 <= duration <= 0.221, (path.name, duration)
    assert 0.005 < peak <= 0.401 and rms > 0.001, (path.name, peak, rms)
    assert pcm[0] == pcm[1] == pcm[-1] == pcm[-2] == 0, path.name
    metrics[path.name] = {'duration_seconds': round(duration, 4), 'peak': round(peak, 4), 'rms': round(rms, 4)}
assert len(metrics) == 84
(root / 'sound-design' / 'audio-validation.json').write_text(json.dumps(metrics, indent=2) + '\n')
print(f'Validated {len(metrics)} stereo WAVs: 60–220 ms, peak <= 0.4, non-silent, zero-boundary fades.')
