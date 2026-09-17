# Architecture

## The constraint that shapes everything

Wired earbuds plug into **one jack** — the Mac. So phone audio must arrive at the Mac wirelessly. With zero extra hardware, the only stock channel is Wi-Fi (AirPlay). macOS cannot be a Bluetooth audio receiver, and iOS cannot be an AirPlay receiver.

```
Wired buds ──jack──► Mac ──Wi-Fi AirPlay──► iPhone (needs to push)
Wired buds ◄─jack── Mac ◄──Wi-Fi custom stream── iPhone (Mac captures + streams)
```

## Components

### Shared/WirePodsCore

- `HandoffProtocol.swift` — newline-delimited JSON messages (`claim`, `release`, `duck`, `resume`, `heartbeat`, `capability`), plus `HandoffStateMachine` with 800 ms debounce.
- `BonjourTransport.swift` — `NWListener` + `NWBrowser` for `_wirepods._tcp`, handles connect, framing, broadcast.
- `AudioFocusController.swift` — platform-agnostic controller that wraps transport + state machine, exposes `focus`, `peerConnected`, `onShouldDuck/Resume`.

### WirePodsMac (macOS 14, menu bar)

- `WirePodsMacApp.swift` — `NSStatusItem` + `NSPopover` hosting `MenuBarView`.
- `MenuBarView.swift` — shows AirPlay Receiver status, focus, wired output name, claim/release buttons.
- `AirPlayReceiverChecker.swift` — heuristic check + opens System Settings.
- `SystemAudioDevice.swift` — `CoreAudio` probe for default output name.
- `SystemAudioStreamer.swift` — `ScreenCaptureKit` captures system audio, streams via `NWListener` `_wirepods-audio._tcp` (PCM with 4-byte header).
- `BrowserMediaController.swift` — AppleScript to pause YouTube tabs in Safari/Chrome/Arc.

### WirePodsiOS (iOS 17, SwiftUI)

- `WirePodsApp.swift` — sets `AVAudioSession` `.playback` + `.allowAirPlay`, posts foreground/background notifications.
- `ContentView.swift` + `PlayerCard` — player UI, AirPlay picker, handoff buttons, "Listen to Mac" toggle.
- `PlayerViewModel.swift` — `AVPlayer` with demo HLS, progress, `allowsExternalPlayback = true`, claim/release on play/pause.
- `AirPlayPickerView.swift` — `AVRoutePickerView` wrapper (one-time tap required).
- `IOSFocusController.swift` — wraps `AudioFocusController(device:.iphone)` + `MacAudioReceiver` (browses `_wirepods-audio._tcp`, decodes PCM via `AVAudioEngine`).

## Handoff state machine

```
         claim(iphone)             claim(mac)
idle ───────────────► iphoneActive ◄────────────── idle
  ▲                    │    │                     ▲
  │ release(iphone)    │    │ release(mac)        │ release
  └────────────────────┘    └─────────────────────┘

- Any `claim` moves focus to claimer.
- `release` only clears focus if releaser currently holds it.
- `duck`/`heartbeat`/`capability` are informational.
- Debounce: same-device claims within 800 ms are dropped.
```

## Why not fully automatic for Reels

- `AVAudioSession` is per-app. No app can read or redirect another app's audio without jailbreak.
- `AVRoutePickerView` requires a user gesture to present the picker the first time. No public API to force a route.
- iPhone is not an AirPlay receiver, so Mac→iPhone must use a custom stream (ScreenCaptureKit) rather than AirPlay.

## Future work

- Opus encode the Mac→iPhone stream (currently raw PCM).
- Browser extension instead of AppleScript for more reliable YouTube pause.
- Add latency measurement and auto-delay compensation.
