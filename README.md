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
- macOS → iPhone audio can't use AirPlay (iPhone is not an AirPlay receiver). Mac→iPhone streaming (ScreenCaptureKit) is disabled by default for your use-case — you look at the iPhone screen, so only iPhone→Mac via AirPlay is needed. No Screen Recording prompt.

---

## Quick start — Path A (universal, manual, test this first)

1. Mac: **System Settings → General → AirDrop & Continuity → AirPlay Receiver ON**, Allow for Current User.
2. Plug wired buds into Mac, select them as output (Option-click volume icon).
3. Same Apple ID + same Wi-Fi (or cable) on both devices.
4. iPhone: **Control Center → Screen Mirroring → select your Mac**. Everything — Reels, YouTube, any app — now plays through the Mac → wired buds.
5. Stop: Screen Mirroring → Stop Mirroring.

> Yes this needs a tap each way and shows a mirrored window. It's the only zero-hardware way to cover arbitrary apps today. Try it before building anything.

---

## Install — simplest (no cable needed after first run)

> **Your setup:** M4 MacBook Pro + iPhone 17, same Wi-Fi, wired buds in Mac. No cable needed after the first iPhone build.

### One-liner on Mac (automates checks)

```bash
git clone git@github.com:vraj00222/wirepods.git
cd wirepods
curl -fsSL https://vraj00222.github.io/wirepods-website/install-mac.sh | bash
# or: ./scripts/install-mac.sh
./scripts/doctor.sh  # verify everything ✓
```

What that script automates: checks macOS 14+ & Xcode, downloads `WirePodsMac.zip` → `/Applications`, checks Wi-Fi SSID (must match iPhone) + wired buds, hints if AirPlay Receiver is off, launches 🎧 menu bar.

### iPhone — one cable build, then wireless on same Wi-Fi

```bash
open WirePodsiOS/WirePodsiOS.xcodeproj
# Signing → your Team → select iPhone 17 via cable → ⌘R → allow Local Network → tap AirPlay → pick Mac once → Done — hands-free
# Then: Xcode → Window → Devices and Simulators → iPhone → ✓ Connect via Network → unplug cable
# Next time (no cable): ./scripts/install-ios-wireless.sh  or Xcode → select iPhone (network icon) → ⌘R
```

After that pairing, **no cable, no taps**: play in WirePods iPhone app → sound in Mac's wired buds; play YouTube on Mac → `SystemAudioMonitor` auto-claims and iPhone ducks.

> Prefer the pretty site? https://vraj00222.github.io/wirepods-website/ — Download for Mac + Download for iPhone buttons + copy-paste one-liner.

### Requirements (same as above)

- Mac: macOS 14+, Xcode 15+, wired buds plugged into Mac, same Wi-Fi + same Apple ID
- iPhone: iOS 17+, same Wi-Fi, Developer Mode for sideload (free Apple ID = 7-day cert)

### Manual fallback (if scripts fail)

Mac companion: open `WirePodsMac/WirePodsMac.xcodeproj` → Signing → Run (⌘R) → check AirPlay Receiver enabled. No Screen Recording needed.
iPhone: open `WirePodsiOS/WirePodsiOS.xcodeproj` → Signing → Run on device → allow Local Network → AirPlay pick once.

### Vice-versa (Mac audio → phone)

Optional: `Listen to Mac` is off by default — you watch the iPhone screen, only iPhone → Mac via AirPlay is needed.

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
| Screen Recording | Mac | Only if you toggle 'Listen to Mac' (Mac→iPhone) | Not needed for your use-case (iPhone→Mac) |
| Accessibility | Mac (optional) | AppleScript pause of Chrome/Safari YouTube tabs | Yes — then manual pause |

No data leaves the LAN. No third-party SDKs. No analytics.

---

## Troubleshooting

- **Mac not appearing in AirPlay picker**: Same Wi-Fi, same Apple ID, AirPlay Receiver ON, firewall allows incoming. Try wired iPhone via cable — lower latency.
- **Route picker won't auto-select**: iOS requires first manual pick. Tap the AirPlay icon once and pick your Mac; next time it auto-connects if Mac is advertising.
- **Mac→iPhone stream**: disabled by default (you look at iPhone screen — only iPhone→Mac needed).
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
