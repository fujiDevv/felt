# Hardware acceptance

Status: pending hardware execution. Automated classifier/policy tests do not replace this matrix.

Use the menu's More options → Monitoring details. Check the global counter while Felt is not frontmost. Test both supported OS majors before claiming support.

| Check | Expected |
|---|---|
| Built-in trackpad / Magic Trackpad, pinch in/out in Safari | One begin sound, quiet release; global counter increases |
| Rotate in Preview | One sound after 8 degrees, no stream of retriggers |
| Page swipe in Safari | One paper slide; normal scrolling stays silent |
| Force Click | Only stage 2 triggers; normal tap/click stays silent |
| Space / full-screen switch | One centered whoosh per change |
| Three/four fingers up, Mission Control | Experimental: one whoosh on entry; details show Dock overview appeared; no repeat while open or exit sound |
| App Exposé | Experimental shared overview whoosh; record whether Dock badge metadata is present |
| Normal Dock / Command-Tab / empty desktop | No false overview whoosh; record empty-window Mission Control behavior |
| External display and clamshell trackpad | Pan follows cursor position on the containing display |
| Call / other microphone capture | Quiet within one second with Quiet on calls enabled |
| Quiet on calls disabled | Microphone activity no longer mutes gestures |
| Muted frontmost app | Silent; another app plays normally |
| Output device changed mid-gesture | No crash or stuck audio; subsequent gestures work |
| Sleep / wake | No polling during sleep; detection and audio recover |
| Input Monitoring denied then enabled | UI updates after reopening menu; detection retested |
| Magic Mouse | Record which public events arrive; no parity promise |
| Release, no entitlement | Only Paper pinch plays; locked worlds can preview |
| StoreKit purchase / restore / revoke / offline | Verified entitlement controls premium; free pinch remains usable |

Measure resident memory, idle CPU and classified-event-to-sample latency on hardware. Targets: 40 MB, 0.5%, 20 ms. No claim that these budgets are met yet.
