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
readonly PREBUILT_APP_PATH="${PREBUILT_APP_PATH:-}"

if [ -z "$DEVICE_ID" ]; then
  echo "Usage: DEVICE_ID=<simulator-udid> $0" >&2
  echo "Optional: LOCALES='de en' APPEARANCES='light dark' OUTPUT_ROOT=<path>" >&2
  exit 1
fi

required_commands=(xcrun maestro ruby)
if [ -z "$PREBUILT_APP_PATH" ]; then
  required_commands+=(xcodebuild)
fi

for command in "${required_commands[@]}"; do
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

boot_started_at="$(date +%s)"
xcrun simctl boot "$DEVICE_ID" 2>/dev/null || true
xcrun simctl bootstatus "$DEVICE_ID" -b
echo "Timing: simulator boot $(( $(date +%s) - boot_started_at ))s"

if [ -n "$PREBUILT_APP_PATH" ]; then
  app_path="$PREBUILT_APP_PATH"
  echo "Using prebuilt app at $app_path"
else
  build_started_at="$(date +%s)"
  echo "Building $SCHEME for $device_name..."
  xcodebuild build \
    -quiet \
    -project "$PROJECT_PATH" \
    -scheme "$SCHEME" \
    -configuration Debug \
    -destination "platform=iOS Simulator,id=$DEVICE_ID" \
    -derivedDataPath "$DERIVED_DATA_PATH"
  echo "Timing: app build $(( $(date +%s) - build_started_at ))s"
  app_path="$DERIVED_DATA_PATH/Build/Products/Debug-iphonesimulator/Rudolstadt.app"
fi

if [ ! -d "$app_path" ]; then
  echo "App not found at $app_path" >&2
  exit 1
fi

install_started_at="$(date +%s)"
xcrun simctl install "$DEVICE_ID" "$app_path"
xcrun simctl privacy "$DEVICE_ID" grant location "$BUNDLE_ID" 2>/dev/null || true
xcrun simctl status_bar "$DEVICE_ID" override \
  --time 09:41 \
  --batteryState charged \
  --batteryLevel 100 \
  --wifiBars 3 \
  --cellularBars 4
echo "Timing: app install and simulator setup $(( $(date +%s) - install_started_at ))s"

cleanup() {
  xcrun simctl status_bar "$DEVICE_ID" clear >/dev/null 2>&1 || true
}
trap cleanup EXIT

read -r -a locales <<< "${LOCALES:-de en}"
read -r -a appearances <<< "${APPEARANCES:-light}"
flow_files=("$FLOWS_PATH"/[0-9][0-9]-*.yaml)
driver_is_ready=false
capture_started_at="$(date +%s)"

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

    echo "Capturing $locale/$appearance/$device_name..."
    combination_started_at="$(date +%s)"
    maestro_options=()
    if [ "$driver_is_ready" = true ]; then
      maestro_options+=(--no-reinstall-driver)
    fi

    report_path="$output_path/maestro-report.xml"
    set +e
    MAESTRO_CLI_NO_ANALYTICS=1 maestro test \
      --udid "$DEVICE_ID" \
      --test-output-dir "$output_path" \
      --no-ansi \
      --format JUNIT \
      --output "$report_path" \
      "${maestro_options[@]}" \
      -e APPLE_LANGUAGES="($locale)" \
      -e APPLE_LOCALE="$app_locale" \
      "${flow_files[@]}"
    maestro_status=$?
    set -e

    driver_is_ready=true
    if [ -f "$report_path" ]; then
      ruby -rrexml/document -e '
        document = REXML::Document.new(File.read(ARGV.fetch(0)))
        REXML::XPath.each(document, "//testcase") do |testcase|
          puts "Timing: #{testcase.attributes["name"]} #{testcase.attributes["time"]}s"
        end
      ' "$report_path"
    fi
    echo "Timing: $locale/$appearance capture $(( $(date +%s) - combination_started_at ))s"

    if [ "$maestro_status" -ne 0 ]; then
      exit "$maestro_status"
    fi
  done
done

echo "Timing: all captures $(( $(date +%s) - capture_started_at ))s"
echo "Screenshots written to $OUTPUT_ROOT"
