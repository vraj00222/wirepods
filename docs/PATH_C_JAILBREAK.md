# Path C — Jailbreak (automatic + universal)

Only route to "automatic + any app including Reels" with no extra hardware, because it hooks the system audio layer directly.

## Step 0 — check eligibility before planning

Public jailbreaks as of Sep 2026 only cover specific chip/iOS combos (roughly A8–A17, M1/M2, several capped below newest iOS). **No public jailbreak for A18/A19 (iPhone 16/17 class) on iOS 26.**

Look up your exact model + iOS version on a live tracker (e.g. iClarified jailbreak guide). If not covered, this path is closed today.

## If eligible

1. Install the jailbreak tool matching your chip/iOS.
2. Find or build a tweak that hooks `AVAudioSession` / ` mediaserverd` and redirects system output to an AirPlay target based on your trigger.

This is systems/security engineering, not app dev.

## Real costs

- Disables broad sandbox protections.
- Breaks on iOS update.
- No warranty/App Store coverage.
- Banking apps may refuse to run.
