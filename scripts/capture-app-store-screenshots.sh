#!/bin/bash

set -euo pipefail

readonly PROJECT_ROOT="$(cd "$(dirname "$0")/.." && pwd)"
readonly PROJECT_PATH="$PROJECT_ROOT/RudolstadtForiOS.xcodeproj"
readonly SCHEME="RudolstadtForiOS (iOS)"
readonly BUNDLE_ID="de.leongeorgi.RudolstadtForiOS"
readonly DERIVED_DATA_PATH="${DERIVED_DATA_PATH:-/tmp/RudolstadtAppStoreScreenshots}"
readonly FLOWS_PATH="$PROJECT_ROOT/.maestro/app-store-screenshots"
readonly OUTPUT_ROOT="${OUTPUT_ROOT:-$PROJECT_ROOT/AppStoreScreenshots}"
readonly DEVICE_ID="${DEVICE_ID:-${1:-}}"

if [ -z "$DEVICE_ID" ]; then
  echo "Usage: DEVICE_ID=<simulator-udid> $0" >&2
  echo "Optional: LOCALES='de en' APPEARANCES='light dark' OUTPUT_ROOT=<path>" >&2
  exit 1
fi

for command in xcodebuild xcrun maestro; do
  if ! command -v "$command" >/dev/null 2>&1; then
    echo "Required command not found: $command" >&2
    exit 1
  fi
done

locale_identifier() {
  case "$1" in
    de) echo "de_DE" ;;
    en) echo "en_US" ;;
    *)
      echo "Unsupported locale: $1" >&2
      exit 1
      ;;
  esac
}

device_name="$({
  xcrun simctl list devices --json | \
    ruby -rjson -e '
      id = ARGV.fetch(0)
      devices = JSON.parse(STDIN.read).fetch("devices").values.flatten
      match = devices.find { |device| device["udid"] == id }
      abort("Simulator not found: #{id}") unless match
      puts match.fetch("name").gsub(/[^A-Za-z0-9._-]+/, "_")
    ' "$DEVICE_ID"
})"

xcrun simctl boot "$DEVICE_ID" 2>/dev/null || true
xcrun simctl bootstatus "$DEVICE_ID" -b

echo "Building $SCHEME for $device_name..."
xcodebuild build \
  -quiet \
  -project "$PROJECT_PATH" \
  -scheme "$SCHEME" \
  -configuration Debug \
  -destination "platform=iOS Simulator,id=$DEVICE_ID" \
  -derivedDataPath "$DERIVED_DATA_PATH"

readonly APP_PATH="$DERIVED_DATA_PATH/Build/Products/Debug-iphonesimulator/Rudolstadt.app"
if [ ! -d "$APP_PATH" ]; then
  echo "Built app not found at $APP_PATH" >&2
  exit 1
fi

xcrun simctl install "$DEVICE_ID" "$APP_PATH"
xcrun simctl privacy "$DEVICE_ID" grant location "$BUNDLE_ID" 2>/dev/null || true
xcrun simctl status_bar "$DEVICE_ID" override \
  --time 09:41 \
  --batteryState charged \
  --batteryLevel 100 \
  --wifiBars 3 \
  --cellularBars 4

cleanup() {
  xcrun simctl status_bar "$DEVICE_ID" clear >/dev/null 2>&1 || true
}
trap cleanup EXIT

read -r -a locales <<< "${LOCALES:-de en}"
read -r -a appearances <<< "${APPEARANCES:-light}"

for locale in "${locales[@]}"; do
  app_locale="$(locale_identifier "$locale")"

  for appearance in "${appearances[@]}"; do
    if [ "$appearance" != "light" ] && [ "$appearance" != "dark" ]; then
      echo "Unsupported appearance: $appearance" >&2
      exit 1
    fi

    output_path="$OUTPUT_ROOT/$locale/$appearance/$device_name"
    mkdir -p "$output_path"
    xcrun simctl ui "$DEVICE_ID" appearance "$appearance"

    for flow in "$FLOWS_PATH"/*.yaml; do
      flow_name="$(basename "$flow" .yaml)"
      echo "Capturing $locale/$appearance/$device_name/$flow_name..."

      xcrun simctl terminate "$DEVICE_ID" "$BUNDLE_ID" >/dev/null 2>&1 || true
      SIMCTL_CHILD_APP_STORE_SCREENSHOT_APPEARANCE="$appearance" \
        xcrun simctl launch --terminate-running-process \
          "$DEVICE_ID" \
          "$BUNDLE_ID" \
          -screenshotMode YES \
          -AppleLanguages "($locale)" \
          -AppleLocale "$app_locale" >/dev/null

      MAESTRO_CLI_NO_ANALYTICS=1 maestro test \
        --udid "$DEVICE_ID" \
        --test-output-dir "$output_path" \
        --no-ansi \
        "$flow"
    done
  done
done

echo "Screenshots written to $OUTPUT_ROOT"
