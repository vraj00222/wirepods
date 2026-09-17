#!/bin/bash
set -e
# WirePods — one-liner Mac installer (M4, macOS 14+)
# Usage: curl -fsSL https://vraj00222.github.io/wirepods-website/install-mac.sh | bash
# Does: checks deps, installs WirePodsMac to /Applications, launches, checks AirPlay + wired buds + Wi-Fi

REPO="vraj00222/wirepods"
ZIP_URL="https://github.com/$REPO/releases/latest/download/WirePodsMac.zip"
APP_PATH="/Applications/WirePodsMac.app"
DERIVED="/tmp/WirePodsMac.zip"

say() { printf "\033[1m[WirePods]\033[0m %s\n" "$*"; }
ok() { printf "  ✓ %s\n" "$*"; }
warn() { printf "  ! %s\n" "$*"; }
fail() { printf "  ✗ %s\n" "$*"; }

# 1. macOS version
OS_VER=$(sw_vers -productVersion)
say "Checking macOS $OS_VER (need 14+)..."
if [[ "${OS_VER%%.*}" -lt 14 ]]; then fail "need macOS 14+"; exit 1; else ok "macOS $OS_VER"; fi

# 2. Xcode check (optional, for building from source if zip fails)
if xcode-select -p >/dev/null 2>&1; then ok "Xcode tools present"; else warn "Xcode CLI tools missing — install via xcode-select --install"; fi

# 3. Download WirePodsMac
if [ -d "$APP_PATH" ]; then warn "Existing $APP_PATH will be replaced"; rm -rf "$APP_PATH"; fi
say "Downloading WirePodsMac.zip..."
if curl -fsSL -o "$DERIVED" "$ZIP_URL"; then
  ok "Downloaded $DERIVED"
  ditto -xk "$DERIVED" /tmp/
  # ditto creates /tmp/WirePodsMac.app
  if [ -d "/tmp/WirePodsMac.app" ]; then
    mv /tmp/WirePodsMac.app "$APP_PATH"
    ok "Installed to $APP_PATH"
  else
    fail "Unzip failed"; exit 1
  fi
else
  warn "Release download failed — trying build from source..."
  if [ -f "WirePodsMac/WirePodsMac.xcodeproj/project.pbxproj" ]; then
    DEVELOPER_DIR=/Applications/Xcode.app/Contents/Developer /Applications/Xcode.app/Contents/Developer/usr/bin/xcodebuild -project WirePodsMac/WirePodsMac.xcodeproj -scheme WirePodsMac -configuration Release CODE_SIGNING_ALLOWED=NO build >/tmp/wirepods-build.log 2>&1 && ok "Built from source" || { fail "Build failed — see /tmp/wirepods-build.log"; exit 1; }
    # Find built app
    APP_BIN=$(find ~/Library/Developer/Xcode/DerivedData -name "WirePodsMac.app" -path "*Release*" | head -1)
    if [ -n "$APP_BIN" ] && [ -d "$APP_BIN" ]; then cp -R "$APP_BIN" "$APP_PATH" && ok "Copied $APP_BIN → $APP_PATH"; fi
  else
    fail "No source found and release download failed. Run: git clone git@github.com:$REPO.git && cd wirepods && $0"; exit 1
  fi
fi

# 4. Wired earbuds check — no Screen Recording needed for your use-case
say "Checking wired output (only needs earbuds in Mac jack — no Screen Recording)..."
ok "If earbuds are plugged, select them: Option-click volume icon → choose 'External Headphones' (no Screen Recording prompt)"

# 5. Wi-Fi check
WIFI=$(networksetup -listallhardwareports 2>/dev/null | grep -A1 "Wi-Fi" | grep Device | awk '{print $2}')
SSID=$(networksetup -getairportnetwork "$WIFI" 2>/dev/null | sed 's/You are not associated with an AirPort network.//;s/Current Wi-Fi Network: //')
if [ -n "$SSID" ]; then ok "Wi-Fi: $SSID (same Wi-Fi as iPhone required)"; else warn "Wi-Fi not associated — connect same Wi-Fi as iPhone"; fi

# 6. AirPlay Receiver hint
say "Checking AirPlay Receiver (needs manual ON once)..."
defaults read com.apple.AirPlayReceiver AirPlayReceiverEnabled 2>/dev/null | grep -q 1 && ok "AirPlay Receiver likely enabled" || warn "Open System Settings → General → AirDrop & Continuity → AirPlay Receiver ON (allow Current User)"

# 7. Launch
say "Launching WirePodsMac..."
open "$APP_PATH" && ok "Launched — look for 🎧 in menu bar" || warn "Launch failed — try open $APP_PATH manually"

# 8. Next steps
cat <<EOF

Done. Next (no cable needed after this):

1. Keep Mac's wired earbuds plugged (🎧 stays on Mac)
2. Same Wi-Fi on iPhone + Mac (checked: $SSID)
3. Install iPhone app once via Xcode (one cable build, then wireless):
     git clone git@github.com:$REPO.git
     open WirePodsiOS/WirePodsiOS.xcodeproj  # select iPhone 17 → Trust → Run → allow Local Network
   After first run: Xcode → unplug cable → iPhone stays “Connected via Network”
4. On iPhone: tap AirPlay → pick your Mac once → Done — hands-free

Test (no cable): Play in WirePods iPhone app → sound in Mac's wired buds. Play YouTube on Mac → auto-hands back.

Doctor: ./scripts/doctor.sh
EOF
