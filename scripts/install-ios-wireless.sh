#!/bin/bash
set -e
# WirePods iPhone wireless install helper (first time still needs cable to trust, then no cable)
# Usage: ./scripts/install-ios-wireless.sh
# Prereq: iPhone 17 on same Wi-Fi, unlocked, Developer Mode enabled

say() { printf "\033[1m[iOS]\033[0m %s\n" "$*"; }
ok() { printf "  ✓ %s\n" "$*"; }
warn() { printf "  ⚠ %s\n" "$*"; }

say "WirePods iOS wireless helper"

if [ ! -f "WirePodsiOS/WirePodsiOS.xcodeproj/project.pbxproj" ]; then echo "Run from wirepods/ root"; exit 1; fi

# Show destinations
say "Looking for iPhone on same Wi-Fi (Connect via Network)..."
if /Applications/Xcode.app/Contents/Developer/usr/bin/xcodebuild -project WirePodsiOS/WirePodsiOS.xcodeproj -scheme WirePodsiOS -showdestinations 2>&1 | grep -q "iPhone"; then ok "Found iPhone destination"; else warn "No wireless iPhone yet — first do ONE cable run: open WirePodsiOS.xcodeproj → select iPhone via cable → Run → then in Xcode: Window → Devices & Simulators → check 'Connect via Network' → unplug"; fi

cat <<'EOF'
Steps (once via cable, then wireless forever):

1. Cable iPhone to Mac → open WirePodsiOS/WirePodsiOS.xcodeproj → Signing → your Team → select iPhone → ⌘R → allow Local Network on iPhone → tap AirPlay → pick Mac once → Done.
2. Unplug cable. In Xcode: Window → Devices and Simulators → select iPhone → ✓ Connect via Network.
3. Next time: just ./scripts/install-ios-wireless.sh or Xcode → select iPhone (now shows as network icon) → ⌘R — no cable.

EOF

read -p "Build & install to wireless iPhone now? [y/N] " ans
if [[ "$ans" == y* ]]; then
  # Try wireless build (best-effort)
  DEVELOPER_DIR=/Applications/Xcode.app/Contents/Developer /Applications/Xcode.app/Contents/Developer/usr/bin/xcodebuild -project WirePodsiOS/WirePodsiOS.xcodeproj -scheme WirePodsiOS -destination 'generic/platform=iOS' -allowProvisioningUpdates CODE_SIGNING_ALLOWED=YES build 2>&1 | tail -20
  ok "Build attempted — check Xcode for signing if failed"
fi
