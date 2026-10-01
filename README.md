# Felt

A native macOS menu-bar app for small, soft gesture sounds. Open `Felt.xcodeproj` and run the Felt scheme, or open `build/Felt.app`. Requires macOS 15 or newer. Reopening the app shows its menu; there is no Dock window.

## Build 5: soft collection and new interface

The interface takes visual direction from [Supaste](https://www.supaste.com): a blue gradient, rounded controls, clear typography, and calm light/dark surfaces. Sound selection, preview and volume live in Sound; call muting, app muting and gesture switches live in Settings. More options opens Monitoring details, restore, About and Quit. Existing settings and four worlds are retained.

The sound library was regenerated with ElevenLabs Sound Effects v2 for a calm, soft, cute character. Mechanical clunks and retro computer tones were removed from the prompts. Every source is filtered to soften high frequencies, trimmed at onset, given a 6 ms attack and 25 ms fade, and mastered to a lower level. These are AI-generated sounds and still need human listening review.

| Cue | Duration |
|---|---:|
| Pinch in | 100 ms |
| Pinch out / world preview | 120 ms |
| Pinch release | 60 ms |
| Rotate | 80 ms |
| Page swipe | 140 ms |
| Force Click | 100 ms |
| Space / overview whoosh | 220 ms |
| Diagnostic tone | 140 ms |

84 bundled stereo 44.1 kHz, 16-bit WAVs: four worlds × seven cues × three subtle pitch variations. Samples are decoded once for the gesture engine. Explicit previews use an independent AVAudioPlayer. The diagnostic tone is a troubleshooting control, not a gesture sound.

`tools/generate_elevenlabs_sounds.py` reads a key from `ELEVENLABS_API_KEY` or stdin; it never stores or prints it. Current originals, prompts and request metadata are in `sound-design/elevenlabs-soft-v2`. Earlier generations remain in `sound-design/elevenlabs`, with the previous audition and validation report retained as `*-v1.*`. `sound-design/audition.mp3` plays the new collection in Paper, Cloth, Machine, Toy order, with cues in the table's order. App playback is offline.

`tools/validate_sounds.py` checks duration, format, non-silence, peak <= 0.4, and zero-boundary fades for all 84 WAVs. Metrics are in `sound-design/audio-validation.json`. The earlier procedural generator is a fallback; running it overwrites the bundled sounds.

## Detection and policy

- Listen-only session event tap using AppKit's gesture mask, with global/local NSEvent fallback. It subscribes to gesture types only and preserves the original event. No keyboard, ordinary clicks, mouse movement or scroll ticks are monitored. Physical global event delivery through the tap still needs validation; Input Monitoring approval alone does not establish that it works.
- Magnification begin/release, cumulative rotation past 8 degrees, page-swipe events, stage-2 pressure, and 80 ms classification debounce. Generic begin/end events reset phase-less sequences.
- NSWorkspace active-space notifications trigger space and full-screen whooshes.
- Experimental Mission Control / App Exposé detection polls public Dock window metadata every 200 ms. It checks a full-display layer-18 window plus layer-17 badges and triggers on entry only. It reads no window titles or screen contents and asks for no Accessibility or screen-recording access. This heuristic is not a documented OS contract, can miss empty overviews, and adds approximately 200 ms latency. Diagnostics retain the last observed Dock layers. A live Build 3 menu reported an overview entry and completed playback on this Mac; other versions and arrangements remain unverified.
- Show Desktop, lookup and Notification Center remain deferred because reliable public detection has not been established.
- Cursor-based stereo pan on the containing display; system whooshes are centered.
- Persistent enable, volume, world, gesture and per-app mute settings.
- Quiet on calls checks Core Audio process input activity every 750 ms. It also mutes during other microphone use. It does not record or request microphone permission. Monitoring pauses during sleep and resumes on wake.
- StoreKit 2 non-consumable `com.fujidevv.Felt.allWorlds`, verified entitlements and restore. Debug unlocks everything. Release defaults to Paper pinch only. No purchase was made by the implementation.

## Testing

```
xcodebuild -project Felt.xcodeproj -scheme Felt -destination 'platform=macOS' -only-testing:FeltTests test
python3 tools/validate_sounds.py
```

15 unit tests pass: classification, policy, persistence, bundled decode, offline audio rendering, live playback progress, independent preview, overview metadata and gesture masks. The menu smoke test passes; additional light/dark UI checks cover preview, volume and the Settings panel. Automated waveform/timeline checks cannot prove what a person hears.

The user heard the built-in macOS alert and Felt's diagnostic tone. Earlier previews and three-finger-up sounds were reported silent. Monitoring later showed a Mission Control / App Exposé entry. The new library still needs an audible gesture retest.

To test three fingers up: enable Felt, open Settings and enable System whooshes, then enter/exit Mission Control. More options → Monitoring details should show `Mission Control / App Exposé` and `Dock overview appeared`. This path does not depend on Input Monitoring and does not increment the input-event counter.

To test global pinch: enable Felt in System Settings → Privacy & Security → Input Monitoring, reopen Felt, then pinch in Safari. The global counter must rise and sound must play. A registered monitor is not sufficient evidence. Follow `docs/gesture-test-matrix.md` for physical acceptance.

## Release blockers

Physical trackpad / Magic Trackpad coverage, reliable global detection, human sound review, StoreKit testing, App Store review and CPU/memory/latency measurement remain pending. The 20 ms latency target is not met by the experimental overview polling. Create the product in App Store Connect and verify purchase/restore/revocation before distribution. The local build is ad-hoc signed for development, not a notarized release. No website is included.
