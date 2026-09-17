# WirePods — Automatic Audio Handoff: Mac (YouTube) ↔ iPhone (Reels)

**Wired Apple earbuds plugged into the MacBook only. Watch YouTube on the Mac, switch to Reels on the phone — sound stays in the same earbuds, no extra hardware.**

> **Honest ceiling first:** With zero extra hardware and stock iOS, there is **no single setup that is both fully automatic and covers every app including Reels** without jailbreaking. macOS cannot be a Bluetooth audio receiver, and iOS sandboxes system audio. This repo implements everything that **is** possible on stock OS — and documents what isn't — so you don't waste weeks hitting a wall.

---

## What you get in this repo (three paths)

| Path | What it does | Trade-off | Setup time |
|------|--------------|-----------|------------|
| **A — Zero code, works today** | Any app including Reels → wired earbuds on Mac via AirPlay Screen Mirroring | One manual tap per switch | 2 minutes |
| **B — This repo: automatic, zero taps** | Your own audio app auto-routes to Mac via AirPlay + signals Mac to duck | Only covers audio **your app** plays (iOS sandbox wall) | Build + install below |
| **C — Jailbreak only** | Automatic + any app | Requires eligible chip/iOS, disables sandboxing | Device-dependent |

**Pick the trade-off that matches what you actually want.** This repo ships Path B fully, plus one-tap instructions for Path A and eligibility notes for Path C.

---

## How Path B works (what this code does)

```
┌─────────────┐   Bonjour / Multipeer   ┌──────────────┐
│ iPhone App  │◄──────────────────────►│ Mac Menu Bar │
│ (WirePods)  │  JSON: claim/duck/paus  │ (WirePodsMac)│
│             │                        │              │
│ AVFoundation│  ── AirPlay audio ──►  │ AirPlay      │
│ plays your  │     (Wi-Fi, stock)      │ Receiver ON  │
│ content &   │                        │ → wired buds │
│ auto-picks  │                        │              │
│ AirPlay→Mac │                        │ SCaptureKit ─┼─► streams Mac audio
│ when foregr.│                        │ → iPhone app │   to phone (vice-versa)
└─────────────┘                        └──────────────┘
```

### Handoff triggers (no manual AirPlay tap after first time)

- **iPhone foreground + playback start** → app advertises `_wirepods._tcp` via Bonjour, connects to Mac, sends `claim:iphone`. If user previously picked "MacName AirPlay" in the route picker, iOS remembers it and reconnects automatically next time.
- **Mac becomes active** (browser frontmost / media key / click "Active: Mac" in menu bar) → Mac sends `claim:mac`, iPhone ducks/pauses.
- **Either side stops** → sends `release`, other side resumes.

### Why it can't be 100% tap-free for arbitrary apps

- iOS requires a **user gesture** to show `AVRoutePickerView` the first time you pick an AirPlay target. Apple provides no public API to force a route programmatically (private API `MPAVRoutingController` would get App Store rejected). After the first pick, iOS will auto-reconnect to the same target if it's available.
- iOS does not let any app intercept **Reels / YouTube app** audio unless you own the playback (`AVAudioSession` is per-app). That's the sandbox wall Path C bypasses with a jailbreak hook.
- macOS → iPhone audio can't use AirPlay (iPhone is not an AirPlay receiver). This repo uses **ScreenCaptureKit (macOS 13+)** to capture system audio and streams it over the local network to the iPhone app. Requires Screen Recording permission once.

---

## Quick start — Path A (universal, manual, test this first)

1. Mac: **System Settings → General → AirDrop & Continuity → AirPlay Receiver ON**, Allow for Current User.
2. Plug wired buds into Mac, select them as output (Option-click volume icon).
3. Same Apple ID + same Wi-Fi (or cable) on both devices.
4. iPhone: **Control Center → Screen Mirroring → select your Mac**. Everything — Reels, YouTube, any app — now plays through the Mac → wired buds.
5. Stop: Screen Mirroring → Stop Mirroring.

> Yes this needs a tap each way and shows a mirrored window. It's the only zero-hardware way to cover arbitrary apps today. Try it before building anything.

---

## Install Path B (automatic, for content you control)

### Requirements

- Mac: macOS 14+ (Sonoma), Xcode 15+, wired buds plugged into Mac
- iPhone: iOS 17+, same Wi-Fi as Mac, Apple ID signed in
- Both: Developer Mode enabled to sideload (free Apple ID works for 7-day cert, paid for longer)

### 1. Clone & open

```bash
git clone git@github.com:vraj00222/wirepods.git
cd wirepods
open WirePodsMac/WirePodsMac.xcodeproj
open WirePodsiOS/WirePodsiOS.xcodeproj
# or open Package.swift in Xcode to see Shared core
```

### 2. Mac companion

1. Open `WirePodsMac/WirePodsMac.xcodeproj`.
2. Signing: select your Team (free Apple ID ok).
3. Run (⌘R). Grant **Screen Recording** when prompted (needed for Mac→iPhone streaming). App appears as 🎧 in menu bar.
4. Check **AirPlay Receiver** shows "Enabled" (it will prompt to open System Settings if off). Enable **Launch at Login**.

### 3. iPhone app

1. Open `WirePodsiOS/WirePodsiOS.xcodeproj`.
2. Signing → your Team.
3. Run on device (not simulator — AirPlay + Bonjour need real device). Grant **Local Network** permission.
4. First launch: tap the **AirPlay** button in the player and pick your **Mac** (e.g. "Vraj's MacBook AirPlay"). This one-time pick is remembered.
5. Play something inside the WirePods player. Audio should now come from the Mac's wired buds. Switch to Mac YouTube, press pause/play — watch the status flip.

### 4. Vice-versa (Mac audio → phone speaker/buds if plugged into phone)

- In the iPhone app, tap **Listen to Mac**. The Mac will start its ScreenCaptureKit stream; audio from the Mac (YouTube etc.) plays on the phone.

---

## Project structure

```
wirepods/
├── Shared/                # WirePodsCore — Bonjour discovery, HandoffProtocol, models
│   └── Sources/WirePodsCore/
├── WirePodsMac/           # macOS 14 menu bar app
│   ├── WirePodsMac.xcodeproj
│   └── Sources/
│       ├── App/           # AppDelegate, MenuBar, StatusItem
│       ├── Signaling/     # Bonjour browser/advertiser, Multipeer session
│       ├── Audio/         # AirPlay receiver check, ScreenCaptureKit streamer
│       └── Automation/    # AppleScript helpers to pause/play browser media
├── WirePodsiOS/           # iOS 17 SwiftUI app
│   ├── WirePodsiOS.xcodeproj
│   └── Sources/
│       ├── App/
│       ├── Player/        # AVFoundation player + AVRoutePickerView
│       └── Signaling/
├── docs/
│   ├── PATH_A_MANUAL.md
│   ├── PATH_C_JAILBREAK.md
│   └── ARCHITECTURE.md
└── scripts/
    ├── generate_projects.sh
    └── test.sh
```

## Branching model

- `main` — stable, tagged releases
- `feat/macos-companion` — macOS menu bar + signaling
- `feat/ios-player` — iOS player + AirPlay routing
- `feat/bonjour-handoff` — shared core + auto-handoff state machine
- `feat/mac-audio-stream` — ScreenCaptureKit Mac→iPhone streaming

Each branch is pushed independently and tested via `scripts/test.sh` before merging.

---

## Permissions — what you'll be asked and why

| Permission | Where | Why | Can say no? |
|---|---|---|---|
| Local Network | iPhone + Mac | Bonjour discovery `_wirepods._tcp` | No — handoff won't find peer |
| Screen Recording | Mac | ScreenCaptureKit system audio capture for Mac→iPhone | Yes — then Mac→iPhone streaming disabled, iPhone→Mac still works |
| Accessibility | Mac (optional) | AppleScript pause of Chrome/Safari YouTube tabs | Yes — then manual pause |

No data leaves the LAN. No third-party SDKs. No analytics.

---

## Troubleshooting

- **Mac not appearing in AirPlay picker**: Same Wi-Fi, same Apple ID, AirPlay Receiver ON, firewall allows incoming. Try wired iPhone via cable — lower latency.
- **Route picker won't auto-select**: iOS requires first manual pick. Tap the AirPlay icon once and pick your Mac; next time it auto-connects if Mac is advertising.
- **Mac→iPhone stream silent**: Check Mac System Settings → Privacy → Screen Recording → WirePodsMac is enabled (restart app after).
- **Handoff flaps**: Keep devices on same Wi-Fi band (both 5 GHz). The app debounces claims by 800 ms.

---

## What this repo will NOT do (so you don't file a bug for an iOS wall)

- Auto-capture Instagram Reels / YouTube app audio without you tapping Screen Mirroring or without jailbreak. Apple sandboxes this. Path A is the stock workaround.
- Programmatically force an AirPlay route without any user gesture — private API exists but would be App Store rejected and breaks on updates.
- Run on A18/A19 + iOS 26 jailbreak path today — no public jailbreak exists for those chips as of Sep 2026. See `docs/PATH_C_JAILBREAK.md`.

---

## License

MIT — see LICENSE.

## Contributing

PRs welcome. Run `scripts/test.sh` before pushing. See `docs/ARCHITECTURE.md` for the handoff state machine.

---

Built for the exact scenario: **wired earbuds in the Mac, YouTube on Mac → Reels on iPhone, sound never leaves the buds.**
