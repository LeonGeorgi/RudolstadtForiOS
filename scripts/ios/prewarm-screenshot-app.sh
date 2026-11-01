#!/usr/bin/env bash
set -euo pipefail
device_id="${DEVICE_ID:?Set DEVICE_ID to a dedicated simulator.}"
read -r -a locales <<< "${LOCALES:-de en}"
locale="${locales[0]}"
case "$locale" in
    de) identifier=de_DE ;;
    en) identifier=en_US ;;
    *) echo "Unsupported locale: $locale" >&2; exit 1 ;;
esac
# Fresh CI simulators initialize app/runtime caches slowly. Start the seeded app
# while the automation runner initializes, before its first launch deadline.
# Both engines include this setup in their measured wall time.
xcrun simctl launch --terminate-running-process "$device_id" \
    de.leongeorgi.RudolstadtForiOS -screenshotMode YES \
    -screenshotAppearance light -AppleLanguages "($locale)" -AppleLocale "$identifier"
