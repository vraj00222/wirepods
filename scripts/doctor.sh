#!/bin/bash
# WirePods doctor — checks everything that can be checked automatically, no taps

set -e
say() { printf "\033[1m[doctor]\033[0m %s\n" "$*"; }
ok() { printf "  ✓ %s\n" "$*"; }
warn() { printf "  ⚠ %s\n" "$*"; }
fail() { printf "  ✗ %s\n" "$*"; }

say "WirePods doctor (M4 + iPhone 17, same Wi-Fi, wired buds on Mac)"

# WirePodsMac installed?
if [ -d "/Applications/WirePodsMac.app" ]; then ok "WirePodsMac installed at /Applications"; else warn "WirePodsMac not in /Applications — run ./scripts/install-mac.sh"; fi
if pgrep -q WirePodsMac; then ok "WirePodsMac running (menu bar 🎧)"; else warn "WirePodsMac not running — open /Applications/WirePodsMac.app"; fi

# Wired buds
if system_profiler SPAudioDataType 2>/dev/null | grep -qi "headphone"; then ok "Audio reports headphones (wired buds likely)"; else warn "Wired buds not detected — plug into Mac jack & select via Option-click volume"; fi

# Wi-Fi
WIFI=$(networksetup -listallhardwareports 2>/dev/null | grep -A1 "Wi-Fi" | grep Device | awk '{print $2}')
SSID=$(networksetup -getairportnetwork "$WIFI" 2>/dev/null | sed 's/You are not associated.*//;s/Current Wi-Fi Network: //')
if [ -n "$SSID" ]; then ok "Wi-Fi SSID: $SSID — make iPhone join same"; else fail "No Wi-Fi — pair must be same network"; fi
if ping -c1 -t2 1.1.1.1 >/dev/null 2>&1; then ok "Internet reachable"; else warn "No internet — local Bonjour still works same Wi-Fi"; fi

# AirPlay Receiver
if defaults read com.apple.AirPlayReceiver AirPlayReceiverEnabled 2>&1 | grep -q 1; then ok "AirPlay Receiver ON"; else warn "AirPlay Receiver may be OFF — System Settings → General → AirDrop & Continuity → ON"; fi

# Bonjour
say "Scanning _wirepods._tcp for 3s (Bonjour)..."
if timeout 3 dns-sd -B _wirepods._tcp 2>&1 | grep -q wirepods; then ok "Bonjour _wirepods._tcp advertising seen"; else warn "No _wirepods peer yet — open WirePods iPhone app on same Wi-Fi"; fi || true

# Xcode
if [ -d "/Applications/Xcode.app" ]; then ok "Xcode at /Applications/Xcode.app ($( /Applications/Xcode.app/Contents/Developer/usr/bin/xcodebuild -version 2>&1 | head -1 ))"; else warn "Xcode not at /Applications/Xcode.app — iPhone build needs it"; fi

# iPhone via network
say "iPhone over Wi-Fi (no cable needed after first trust):"
if DEVELOPER_DIR=/Applications/Xcode.app/Contents/Developer xcrun devicectl list devices 2>&1 | grep -iq "iphone"; then ok "devicectl sees iPhone (network)"; else warn "No iPhone via network — first run needs cable once, then Product → Destination → check 'Connect via Network'"; fi || true

say "Done. If all ✓, test: iPhone Play → Mac buds, Mac YouTube → auto back. Same Wi-Fi required after this — no cable."
