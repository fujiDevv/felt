"""Generate Felt's soft micro-cue library with ElevenLabs Sound Effects v2.
API key is read from ELEVENLABS_API_KEY or stdin, never saved or printed.
Run with --limit 1 to audition first; rerun to resume cached generations.
28 API generations produce 84 mastered, subtly pitch-varied WAVs.
"""
import argparse, array, json, math, os, ssl, subprocess, sys, urllib.request, urllib.error, wave
from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]
SOURCE = ROOT / 'sound-design' / 'elevenlabs-soft-v2'
DEST = ROOT / 'Felt' / 'Sounds'
MATERIALS = {
 'paper': 'a tiny soft fingertip pat on smooth cotton paper, a warm airy rounded texture',
 'cloth': 'one plush felt fingertip tap, velvety soft and reassuring, muted warm low mids',
 'machine': 'one cushioned tiny ceramic touch, silky rounded soft pluck, modern and delicate',
 'toy': 'one tiny soft silicone bubble pop, cute rounded and gentle, like a plush toy'
}
ACTIONS = {
 'pinchIn': 'a tiny rising soft squeeze, one gentle pip lasting about 100 milliseconds',
 'pinchOut': 'a tiny falling rounded opening, one gentle plop lasting about 120 milliseconds',
 'pinchEnd': 'a faint fluffy release, a soft little breath lasting about 60 milliseconds',
 'rotate': 'a miniature soft padded tick lasting about 80 milliseconds, no metallic click',
 'swipe': 'a tiny velvety airy swip lasting about 140 milliseconds, smooth and friendly',
 'forceClick': 'one soft rounded low pop lasting about 100 milliseconds, no sharp attack',
 'spaceSwitch': 'a tiny soft cloud swish lasting about 220 milliseconds, airy and reassuring'
}
DURATIONS = {'pinchIn': .10, 'pinchOut': .12, 'pinchEnd': .06, 'rotate': .08, 'swipe': .14, 'forceClick': .10, 'spaceSwitch': .22}

def master(source, dest, gesture, ratio):
    decoded = subprocess.run(['ffmpeg', '-v', 'error', '-i', str(source), '-af', 'highpass=f=90,lowpass=f=3600', '-f', 's16le', '-ac', '1', '-ar', '44100', '-'],
                             capture_output=True, check=True).stdout
    values = array.array('h'); values.frombytes(decoded)
    peak = max(abs(x) for x in values)
    if peak < 100: raise RuntimeError('Generated audio is silent; originals retained, no replacement.')
    threshold = max(50, peak*.025)
    onset = next(i for i,x in enumerate(values) if abs(x) > threshold)
    start = max(0, onset - 220)
    count = int(DURATIONS[gesture] * 44100)
    result = []
    for i in range(count):
        at = start + i*ratio
        j = int(at)
        if j+1 >= len(values): sample = 0
        else: sample = values[j]*(1-(at-j)) + values[j+1]*(at-j)
        # Rounded 6 ms onset and 25 ms tail prevent sharp edges in these tiny cues.
        sample *= min(1, i/265) * min(1, (count-1-i)/1103)
        result.append(sample)
    rms = math.sqrt(sum(x*x for x in result)/len(result)) / 32768
    peak = max(abs(x) for x in result)/32768
    if rms < .001: raise RuntimeError('Mastered audio too quiet; review the source.')
    gain = min((.025 if gesture == 'pinchEnd' else .055)/rms, .40/max(peak, 1e-8))
    pcm = array.array('h')
    for sample in result:
        v = int(max(-32767,min(32767,sample*gain)))
        pcm.extend((v,v))
    with wave.open(str(dest), 'wb') as f:
        f.setnchannels(2); f.setsampwidth(2); f.setframerate(44100); f.writeframes(pcm.tobytes())

parser = argparse.ArgumentParser()
parser.add_argument('--limit', type=int, default=28)
args = parser.parse_args()
key = os.environ.get('ELEVENLABS_API_KEY') or sys.stdin.readline().strip()
if not key: sys.exit('An ElevenLabs API key is required via environment or stdin.')
SOURCE.mkdir(parents=True, exist_ok=True)
manifest_path = SOURCE / 'manifest.json'
manifest = json.loads(manifest_path.read_text()) if manifest_path.exists() else {}
requests_made = 0
for world, material in MATERIALS.items():
    for gesture, action in ACTIONS.items():
        name = f'{world}-{gesture}'
        source = SOURCE / f'{name}.mp3'
        prompt = f'Calm cute modern UI micro-sound. {material}. {action}. One audible dry cue immediately at the start. Safe, soft, warm. No retro computer beeps, bells, harsh clicks, speech, music, ambience, reverb or repeats.'
        if not source.exists():
            if requests_made >= args.limit: continue
            request = urllib.request.Request('https://api.elevenlabs.io/v1/sound-generation?output_format=mp3_44100_128',
                data=json.dumps({'text':prompt,'duration_seconds':.5,
                                 'prompt_influence':.65,'model_id':'eleven_text_to_sound_v2','loop':False}).encode(),
                headers={'xi-api-key':key,'Content-Type':'application/json'},method='POST')
            try:
                with urllib.request.urlopen(request, timeout=120, context=ssl.create_default_context(cafile="/etc/ssl/cert.pem")) as response:
                    body = response.read()
                    if not response.headers.get('Content-Type','').startswith(('audio/','application/octet-stream')):
                        sys.exit('Unexpected API response type; stopped without exposing response contents.')
                    source.write_bytes(body)
                    manifest[name] = {'provider':'ElevenLabs','model':'eleven_text_to_sound_v2','prompt':prompt,
                                      'character_cost':response.headers.get('character-cost'),
                                      'request_id':response.headers.get('request-id'),
                                      'generated_duration':.5,
                                      'mastered_duration':DURATIONS[gesture], 'variants':'pitch ratios 1.00, 0.96, 1.04'}
                    manifest_path.write_text(json.dumps(manifest, indent=2)+'\n')
            except urllib.error.HTTPError as error:
                # Only print whitelisted diagnostic fields; never print request headers or key.
                try:
                    detail=json.loads(error.read()).get('detail',{})
                    status=detail.get('status','unknown') if isinstance(detail,dict) else 'unknown'
                except Exception: status='unknown'
                sys.exit(f'ElevenLabs returned HTTP {error.code}, status {status}. Stopped; no automatic paid retry.')
            except urllib.error.URLError:
                sys.exit('Network connection to api.elevenlabs.io failed. No key or response contents logged.')
            requests_made += 1
        for variation, ratio in enumerate([1.,.96,1.04],1):
            master(source, DEST/f'{name}-{variation}.wav', gesture, ratio)
        print(f'Mastered {name}: three WAV variants', flush=True)
print(f'Completed {len(manifest)} source generations; {requests_made} new API calls.', flush=True)
