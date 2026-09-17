#!/bin/bash
set -e
# Regenerate Xcode projects from templates (used if you add files)
echo "Regenerating WirePods Xcode projects..."
python3 /tmp/gen_pbx.py "$(pwd)"
python3 /tmp/patch_pbx.py "$(pwd)"
echo "Done. Open WirePodsMac/WirePodsMac.xcodeproj and WirePodsiOS/WirePodsiOS.xcodeproj in Xcode."
