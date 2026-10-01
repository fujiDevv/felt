# Felt — Development, Architecture, and Design Process

Working name: **Felt**. A native macOS menu-bar app that gives trackpad gestures a recorded sound. Pinch, rotate, page swipe, Force Click, lookup, Mission Control, App Exposé, Show Desktop, space switch, and Notification Center each get one sample. No keyboard sounds. No ordinary click sounds. No gesture remapping.

The reference for product shape is Keeby (`getkeeby.com`) and, secondarily, Clacky (`clacky.app`). Keeby owns keys. Clacky owns clicks and scroll ticks. Felt owns the gestures both of them leave silent.

This document is the process: what to decide, in what order, and why. It is not a sprint plan with fake dates.

---

## 1. Product frame

### One sentence

Felt plays a short recorded sound when a Mac trackpad gesture happens, from the menu bar, offline, for $4.99 once.

### What it is not

- Not a BetterTouchTool clone. No custom chords, no remapped shortcuts, no window management.
- Not a fifth mechanical-keyboard app. Typing stays silent on purpose.
- Not Clacky. Normal taps, drags, and scroll ticks are out of v1. Force Click is the only pressure event, and it uses a different sample from a normal click.
- Not a cursor visualizer. Keeby has the keyboard overlay. Clacky has the ripple. Felt flashes a gesture name in the menu bar and stops there.

### Why the habit loop is weaker, and how the product answers

People type thousands of times a day and pinch dozens. Space switch, Show Desktop, and App Exposé are the gestures that actually fire all day. Those four whooshes are the retention feature. Pinch is the marketing feature, because it is the one a stranger can try on the website in five seconds.

### v1 gesture map

| Gesture | Sample family | Fire rule |
|---|---|---|
| Two-finger pinch in | Cloth, higher pitch | On magnify begin, one shot |
| Two-finger pinch out | Cloth, lower pitch | On magnify begin, one shot |
| Pinch release | Cloth tail | On magnify end, quiet |
| Two-finger rotate | Machine detent | Only after rotation passes a threshold |
| Two-finger page swipe | Paper slide | On swipe event, not on scroll pixels |
| Force Click | Machine, deeper than a tap | Pressure crosses the system force-click threshold |
| Three-finger lookup | Machine tick | On the lookup action |
| Mission Control | Whoosh, up | On the system action, not finger count |
| App Exposé | Whoosh, down | Same |
| Show Desktop | Whoosh, open | Same |
| Space / full-screen switch | Whoosh, lateral | On active-space change |
| Notification Center edge swipe | Curtain | On the panel appearing |

Four worlds, not thirty packs: **Paper**, **Cloth**, **Machine**, **Toy**. Free tier is Paper plus pinch only. Paid unlocks the other three worlds and every gesture.

### Explicit non-goals for v1

- Magic Mouse parity beyond what public events already provide. The site says built-in trackpad and Magic Trackpad.
- Private Multitouch framework (`MultitouchSupport`). That is how finger-counting tools work, and it is an App Store rejection risk.
- Continuous audio during a pinch. It becomes annoying in two minutes.
- Per-finger RGB, a desktop pet, a screen recorder, or a typing trainer.

---

## 2. Design process

Inspired by Keeby, not copied. Keeby’s page is a light gray field, one orange accent, a keycap mark, a two-line black headline, a single black pill, the price under the pill, then the product appearing as a Mac bezel. The instrument (a keyboard you can type on) sits further down and is the demo. Felt keeps that order and swaps the instrument.

### 2.1 Principles

1. The page is the product. A visitor hears a gesture before they read a feature.
2. One accent. Keeby’s orange keycap is the only saturated color on a near-white field. Felt uses one warm accent the same way. Working token: `#F5A524` on `#F4F4F5`, ink `#111111`.
3. One price sentence. `$4.99 · One-time purchase`, directly under the primary button. No monthly comparison table.
4. Privacy is a feature line, not a footer. “No network. No account. Nothing typed or gestured leaves the Mac.”
5. Menu bar, not Dock. Screenshots show the menu, the way Keeby shows its menu hanging off the bezel.
6. Short headlines, broken on purpose. Keeby: “Your keyboard, / but better.” Felt: “Your trackpad, / but better.”

### 2.2 Name and mark

Working name Felt. Short, physical, not a switch brand. Mark is a rounded square trackpad with two finger dots, in the accent color, the same scale as Keeby’s smiling keycap. Wordmark is lowercase, black, tight tracking. No icon salad in the nav. Nav is the mark plus one Download pill, same as Keeby.

If Felt is taken on the App Store, fallback names in the same shape: Glide, Pad, Thum. Do not use Swipe (generic) or Pinch (too narrow once whooshes are the daily sound).

### 2.3 Type and color

- Display: a tight grotesque, similar weight to Keeby’s headline. System stack is fine for v1 of the site: `ui-sans-serif, -apple-system, Inter`. Headline around 64–80px, weight 700, tracking slightly negative, line-height 0.95.
- Body: 16–18px, `#6B6B6B` on the gray field. Never a second accent color for body links. Links are ink, underlined on hover.
- Surfaces: page `#F4F4F5`, cards `#FFFFFF`, hairline `#E6E6E8`, pill button `#111111` with white label. Accent only on the mark, the active gesture label, and one focus ring.
- Radius: pills fully round. Cards 20–24px. The trackpad demo is a squircle, not a rectangle.
- Motion: 150–200ms ease-out. Gesture glow is a soft scale on the finger dots, not a bounce. Keeby’s keyboard lights a key. Felt lights a finger.

### 2.4 Site structure

Match Keeby’s scroll, beat for beat.

1. **Nav.** Mark + “felt”. Download pill, top right.
2. **Hero.** Mark. Headline. Subline: “Gesture sounds for Mac.” Black pill: Download for Mac. Price line. No email capture.
3. **Bezel.** A Mac window crop with the menu open: Enable Felt, world picker (Paper / Cloth / Machine / Toy), volume, “Quiet on calls”. Accent dot in the menu bar. Same composition as Keeby’s hero crop.
4. **Instrument.** A trackpad outline, centered, large. This is the Keeby keyboard block.
   - On a laptop with a trackpad, pinch, rotate, and two-finger swipe inside the outline play the real sample and light the gesture name.
   - On a desktop, dragging two cursors (or one drag with a modifier) fakes pinch and swipe. The page says so in one caption, not a modal.
   - A small counter: “12 pinches on this page.” Same energy as Clacky’s click total, smaller than Keeby’s keyboard so it does not compete with the trackpad.
5. **Four worlds.** Horizontal list, Keeby’s switch list. Paper is selected by default. Clicking a world retunes the demo. Free worlds are marked. Locked worlds still preview one shot, then show the price line again.
6. **Three feature rows**, not a grid of twelve.
   - Spatial. A pinch on the left side of the trackpad plays left. Same idea as Keeby’s L/R keys, applied to finger position.
   - Menu bar. One screenshot, captioned. “Switch worlds, tweak tone, mute an app.”
   - Private. Three lines: no account, no analytics, no network after download.
7. **Who it’s for.** One sentence for people who record tutorials: the whoosh is in system audio, so it lands in any recorder. No recorder feature of our own.
8. **Footer.** Support, privacy, and the Mac App Store line. Support page is Keeby’s shape: permissions first, contact last.

### 2.5 App UI

Keeby’s in-app UI is a menu, not a window. Felt is the same.

- Menu bar icon: the trackpad mark, template-style so it follows menu bar contrast. While a gesture plays, the icon ticks to the accent for 200ms. That is the whole visualizer.
- Menu sections, in order: Enable Felt. World (four items, checkmark). Volume slider. Quiet in these apps. Quiet on calls. Gesture toggles (pinch, rotate, swipe, force click, system whooshes) as one submenu. About, Quit.
- No onboarding window. First launch prompts for the permission, then the menu.
- Settings that do not fit the menu wait until v1.1. v1 ships with the menu only.

### 2.6 Sound design process

1. Record, do not synthesize. Keeby’s credibility is real switches. Felt’s credibility is real materials: paper, cloth, a camera shutter, a desk drawer.
2. One shot under 400ms for discrete gestures. Whooshes under 700ms. No loops.
3. A begin sample and an end sample for pinch only. Everything else is one shot.
4. Variation: two or three takes per gesture, picked at random, so a double space-switch does not sound like a loop. Same trick Keeby uses on key-down and key-up.
5. Normalize loudness across worlds so switching from Paper to Toy is not a volume jump.
6. Preview encodes for the site are short AAC. The app ships CAF or WAV, decoded once at launch.

### 2.7 Design review checklist

Before build, the page has to pass four tests:

- A stranger can make a sound in under five seconds without reading.
- The price is visible without scrolling on a 13-inch laptop.
- No section explains a feature the menu does not have.
- The page still works with audio blocked. Finger dots and the gesture name have to carry it.

---

## 3. Architecture

Native Swift. Menu-bar agent. No Electron, no web view in the app. The site is a separate static project.

### 3.1 Processes

```
┌─────────────────────┐     events      ┌──────────────────────┐
│  Event tap          │ ───────────────▶│  Gesture classifier  │
│  global NSEvent     │                 │  begin / end / ignore│
│  + workspace notes  │                 └──────────┬───────────┘
└─────────────────────┘                            │ GestureEvent
                                                   ▼
                                        ┌──────────────────────┐
                                        │  Policy              │
                                        │  enabled, per-gesture│
                                        │  mute app, on-call   │
                                        └──────────┬───────────┘
                                                   │
                                                   ▼
                                        ┌──────────────────────┐
                                        │  Audio engine        │
                                        │  preloaded buffers   │
                                        │  pan by finger x     │
                                        └──────────────────────┘
```

One app, one process. `LSUIElement` so there is no Dock icon. No helper tool. No login item beyond “open at login” in v1.1 if people ask.

### 3.2 Event sources

Public API only.

| Source | Used for |
|---|---|
| `NSEvent.addGlobalMonitorForEvents`, mask `.magnify` | Pinch begin, change, end. `magnification` sign picks in vs out. |
| Same monitor, `.rotate` | Rotate. Ignore until `rotation` passes ~8 degrees. |
| Same monitor, `.swipe` | Page swipe. |
| Same monitor, `.pressure` | Force Click when pressure crosses the system threshold. |
| `NSWorkspace` active space notification | Space and full-screen switch whoosh. |
| `NSWorkspace.didActivateApplicationNotification` plus window-list delta, conservative | App Exposé / Mission Control only if the public signal is reliable. If it is flaky in testing, ship space-switch and desktop whoosh only, and cut the rest rather than guess. |
| Notification Center | Detect via the system notification of the panel if available. If not reliable without private API, cut it from v1. |

Scroll-wheel events are observed only to ignore them. A pinch must not also count as a scroll.

Debounce: 80ms per gesture class. A second pinch inside that window does not retrigger begin.

### 3.3 Why not a CGEvent tap for everything

Key apps need a tap because key-down is easy to miss otherwise. Gesture events already arrive on the global monitor on current macOS. Start there. A tap is extra entitlement surface and extra App Store review questions. Add one only if the global monitor drops magnify events while Felt is not frontmost. That test is a launch blocker, not an assumption.

### 3.4 Permissions

- Input Monitoring, if the global monitor requires it on the shipping OS. Keeby’s support page is written around this exact failure. Felt’s support page leads with the same fix: System Settings → Privacy & Security → Input Monitoring.
- No Accessibility permission in v1. Taking it “just in case” trains users to deny the prompt.
- No microphone. Samples are files in the bundle.
- No network entitlement. App Transport Security is irrelevant if the app never opens a socket. State this in the privacy nutrition label.

### 3.5 Audio engine

- `AVAudioEngine` attached to the output node, one player node per gesture class so a whoosh can overlap a pinch without cutting it.
- Buffers decoded once at launch, kept in memory. The library is small. Latency budget is under 20ms from classified event to first sample.
- Pan: map the event location’s x-position on the main display to a stereo pan. Headphones matter more than speakers. If the event has no location, pan center.
- Volume is a single gain on the mixer. Worlds do not have separate volumes in v1.
- On-call mute: observe the core audio “other audio is playing” / call-related route hint, and also a manual toggle. False positives are acceptable. A missed mute during a call is not.

### 3.6 Policy and persistence

`UserDefaults` is enough. No database.

- `enabled: Bool`
- `world: paper | cloth | machine | toy`
- `volume: Float`
- `mutedBundleIDs: [String]`
- `quietOnCalls: Bool`
- `gestures: [GestureID: Bool]`
- `licensed: Bool` once the receipt is checked

Frontmost app bundle id comes from `NSWorkspace.shared.frontmostApplication`. Mute list is edited from the menu: “Mute [current app]”.

### 3.7 Licensing

Mac App Store build: StoreKit 2, non-consumable, $4.99. Receipt check at launch. No server.

Direct build, only if the App Store rejects gesture monitoring: a license key checked offline against a public key baked into the app. Do not build both stores in v1. App Store first.

Free tier is a flag in the same binary, not a second app. Paper + pinch works without a purchase. Everything else checks `licensed`.

### 3.8 Site architecture

Static. No account, no backend.

- One page plus `/support` and `/privacy`.
- Audio previews fetched as small files, decoded in the browser, played on the gesture. Do not synthesize.
- Trackpad demo uses Pointer Events and, where the browser exposes it, gesture events. Fallback is drag-to-pinch.
- Counter is local to the tab. Do not ship Clacky’s global click counter in v1. A live worldwide counter needs a backend Felt does not have.
- Download button goes to the App Store listing. No DMG until a direct build exists.

### 3.9 Repo layout

```
felt/
  app/                  Swift package, menu bar agent
    Sources/Felt/
      App.swift
      EventMonitor.swift
      Classifier.swift
      Policy.swift
      AudioEngine.swift
      Menu.swift
      License.swift
    Resources/Sounds/{paper,cloth,machine,toy}/
  site/                 static hero, demo, support
  docs/                 this process, gesture test matrix
```

### 3.10 Performance budget

- Idle CPU under 0.5%. The monitor is the only always-on work.
- Resident memory under 40 MB including decoded samples.
- No wakeups while the lid is closed beyond what the system already does.

---

## 4. Development process

### 4.1 Order of work

Build the sound path before the menu. A menu that cannot play a pinch is a mock.

1. **Spike, one day.** Global monitor on `.magnify` while the app is not frontmost. Log begin and end. If events do not arrive, stop and re-scope before any UI. This is the risk that kills the product.
2. **Audio path.** Load Paper pinch samples. Play on magnify begin. Pan stubbed to center.
3. **Classifier.** In vs out, rotate threshold, swipe, pressure threshold. Unit-test the classifier with recorded `NSEvent` fixtures, not with a human trackpad, so regressions are visible.
4. **System gestures.** Space-change whoosh only. Add Exposé, desktop, and Notification Center one at a time, each behind a flag, each cut if flaky.
5. **Policy.** Enable flag, mute frontmost app, quiet-on-calls.
6. **Menu.** Keeby-shaped. Worlds switch the sample folder.
7. **License gate.** Free vs paid.
8. **Site.** Instrument first, bezel second, copy last. The demo is the acceptance test for the brand.
9. **Support page.** Written from the real permission failure, not from a template.

### 4.2 Test matrix

Manual, on hardware. The classifier tests do not replace this.

| Device | Must pass |
|---|---|
| Apple Silicon MacBook, built-in trackpad | Pinch in, pinch out, rotate, page swipe, Force Click, space switch |
| Magic Trackpad | Same set |
| Magic Mouse | Document what fires. Do not promise the rest. |
| External display + lid closed, Magic Trackpad | Pan uses the display the cursor is on |
| Zoom or FaceTime call | Quiet-on-calls mutes within one second |
| Audio device switch mid-gesture | No crash, no stuck player |

macOS floor: current and previous major version. Do not claim older.

### 4.3 Failure states

- Permission off: menu shows one line, “Turn on Input Monitoring”, deep-linking to System Settings. No sound, no nag window.
- Sample missing: skip that gesture, log locally, do not alert.
- License unreadable: stay on the free tier. Never brick pinch.

### 4.4 Release

- Notarized if direct. App Store build is notarized by review.
- Privacy nutrition label: no data collected.
- What’s new, first version: the four worlds and the gesture list. No “performance improvements”.
- A 15-second screen recording of a pinch and a space switch, audio on. That clip is the launch post. The site already is the demo.

### 4.5 v1.1, only if v1 is used

- Open at login.
- Per-gesture volume.
- Bring-your-own sample for a single gesture, files stay on disk.
- A whoosh when the menu itself opens. Cute, easy to cut.

Not on the list until someone asks: Windows, iOS, a browser extension, keyboard sounds.

---

## 5. Copy deck

Use these lines. Do not expand them into paragraphs on the page.

- Headline: “Your trackpad, but better.”
- Subline: “Gesture sounds for Mac.”
- Price: “$4.99 · One-time purchase”
- Privacy: “No network. No account. Gestures stay on your Mac.”
- Demo caption: “Pinch the pad. Desktop users can drag.”
- Worlds label: “Paper, Cloth, Machine, Toy.”
- Force Click line: “A deeper click than a tap.”
- Recording line: “The whoosh is in the recording, if your recorder grabs system audio.”
- Support title: “No sound”
- Support first step: “System Settings → Privacy & Security → Input Monitoring. Turn Felt on. Reopen it.”

---

## 6. Decision log

| Decision | Choice | Rejected |
|---|---|---|
| Surface | Menu bar agent | Dock app, windowed settings |
| Detection | Public global monitor + workspace notes | Private Multitouch finger counting |
| Library | Four material worlds | Switch-brand packs, synthesized tones |
| Visualizer | Menu bar tick | Cursor ripple, on-screen trackpad |
| Commerce | App Store non-consumable, free pinch tier | Subscription, account-gated license |
| Site | Static, page is the instrument | Marketing page with a muted video only |
| Overlap with Keeby and Clacky | None on purpose | Keyboard samples, ordinary click samples |

---

## 7. Open questions

These block a build step, not the design.

1. Does `.magnify` arrive on a global monitor when Felt is not frontmost, on the oldest macOS we claim? Spike before menu work.
2. Can Mission Control and App Exposé be inferred from public workspace signals reliably enough to ship, or do they slip to v1.1?
3. Is the name Felt clear on the App Store, or does it read as a notes app? Check before the listing, not after the icon is drawn.
