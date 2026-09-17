#!/bin/bash
set -e
echo "== WirePods — Running tests =="

# Shared core via SwiftPM
if [ -f "Package.swift" ]; then
  echo "-- Building WirePodsCore (SwiftPM) --"
  swift build 2>&1 | tail -n 30
  if [ -d "Shared/Tests" ]; then
    echo "-- Running WirePodsCoreTests --"
    swift test 2>&1 | tail -n 50
  else
    echo "(no Shared/Tests yet — skipping swift test)"
  fi
fi

# Xcode builds (if projects exist and xcodebuild available)
if command -v xcodebuild >/dev/null 2>&1; then
  if [ -d "WirePodsMac/WirePodsMac.xcodeproj" ]; then
    echo "-- Checking WirePodsMac scheme --"
    xcodebuild -project WirePodsMac/WirePodsMac.xcodeproj -list 2>&1 | head -n 20 || true
  fi
  if [ -d "WirePodsiOS/WirePodsiOS.xcodeproj" ]; then
    echo "-- Checking WirePodsiOS scheme --"
    xcodebuild -project WirePodsiOS/WirePodsiOS.xcodeproj -list 2>&1 | head -n 20 || true
  fi
else
  echo "xcodebuild not found — skipping Xcode checks"
fi

echo "== Done =="
