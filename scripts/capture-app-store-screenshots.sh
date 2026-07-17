#!/bin/bash

set -euo pipefail

readonly PROJECT_ROOT="$(cd "$(dirname "$0")/.." && pwd)"
readonly PROJECT_PATH="$PROJECT_ROOT/RudolstadtForiOS.xcodeproj"
readonly SCHEME="RudolstadtForiOS (iOS)"
readonly BUNDLE_ID="de.leongeorgi.RudolstadtForiOS"
readonly DERIVED_DATA_PATH="${DERIVED_DATA_PATH:-/tmp/RudolstadtAppStoreScreenshots}"
readonly FLOWS_PATH="$PROJECT_ROOT/.maestro/app-store-screenshots"
readonly FLOW_FILE="$FLOWS_PATH/app-store.yaml"
readonly OUTPUT_ROOT="${OUTPUT_ROOT:-$PROJECT_ROOT/AppStoreScreenshots}"
readonly DIAGNOSTICS_ROOT="${DIAGNOSTICS_ROOT:-${OUTPUT_ROOT%/}-diagnostics}"
readonly CAPTURE_ID="${CAPTURE_ID:-$(date +%Y-%m-%d_%H%M%S)}"
readonly DEVICE_ID="${DEVICE_ID:-${1:-}}"
readonly PREBUILT_APP_PATH="${PREBUILT_APP_PATH:-}"
readonly MAX_CAPTURE_ATTEMPTS=2

if [ -z "$DEVICE_ID" ]; then
  echo "Usage: DEVICE_ID=<simulator-udid> $0" >&2
  echo "Optional: LOCALES='de en' OUTPUT_ROOT=<path>" >&2
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

if [ ! -f "$FLOW_FILE" ]; then
  echo "Screenshot flow not found: $FLOW_FILE" >&2
  exit 1
fi

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

is_recoverable_driver_failure() {
  local diagnostics_path="$1"

  grep -R -E -q \
    -e 'Failed to connect to /127\.0\.0\.1' \
    -e 'Timed out while requesting screenshot' \
    "$diagnostics_path"
}

print_report_timings() {
  local report_path="$1"

  if [ ! -f "$report_path" ]; then
    return
  fi

  ruby -rrexml/document -e '
    document = REXML::Document.new(File.read(ARGV.fetch(0)))
    REXML::XPath.each(document, "//testcase") do |testcase|
      puts "Timing: #{testcase.attributes["name"]} #{testcase.attributes["time"]}s"
    end
  ' "$report_path"
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
driver_is_ready=false
capture_started_at="$(date +%s)"
capture_status=0

for locale in "${locales[@]}"; do
  app_locale="$(locale_identifier "$locale")"
  output_path="$OUTPUT_ROOT/$locale/$device_name/$CAPTURE_ID"
  attempts_root="$DIAGNOSTICS_ROOT/$locale/$device_name/$CAPTURE_ID"
  mkdir -p "$(dirname "$output_path")" "$attempts_root"
  xcrun simctl ui "$DEVICE_ID" appearance light

  echo "Capturing $locale/$device_name..."
  combination_started_at="$(date +%s)"
  locale_status=1

  for ((attempt = 1; attempt <= MAX_CAPTURE_ATTEMPTS; attempt++)); do
    attempt_output="$attempts_root/attempt-$attempt"
    mkdir -p "$attempt_output"
    echo "Capture attempt $attempt/$MAX_CAPTURE_ATTEMPTS for $locale/$device_name..."

    maestro_options=(--no-ansi)
    if [ "$driver_is_ready" = true ]; then
      maestro_options+=(--no-reinstall-driver)
    fi

    report_path="$attempt_output/maestro-report.xml"
    attempt_started_at="$(date +%s)"
    set +e
    MAESTRO_CLI_NO_ANALYTICS=1 maestro test \
      --udid "$DEVICE_ID" \
      --test-output-dir "$attempt_output" \
      --format JUNIT \
      --output "$report_path" \
      "${maestro_options[@]}" \
      -e APPLE_LANGUAGES="($locale)" \
      -e APPLE_LOCALE="$app_locale" \
      "$FLOW_FILE"
    maestro_status=$?
    set -e

    print_report_timings "$report_path"
    echo "Timing: $locale attempt $attempt $(( $(date +%s) - attempt_started_at ))s"

    if [ "$maestro_status" -eq 0 ]; then
      if [ -e "$output_path" ]; then
        echo "Capture output already exists: $output_path" >&2
        locale_status=1
        break
      fi

      mv "$attempt_output" "$output_path"
      driver_is_ready=true
      locale_status=0
      break
    fi

    locale_status="$maestro_status"
    driver_is_ready=false
    if
      [ "$attempt" -lt "$MAX_CAPTURE_ATTEMPTS" ] &&
      is_recoverable_driver_failure "$attempt_output"
    then
      echo "Maestro driver became unavailable; retrying with a fresh driver."
      continue
    fi

    break
  done

  echo "Timing: $locale capture $(( $(date +%s) - combination_started_at ))s"

  if [ "$locale_status" -ne 0 ]; then
    capture_status="$locale_status"
  fi
done

echo "Timing: all captures $(( $(date +%s) - capture_started_at ))s"
echo "Screenshots written to $OUTPUT_ROOT"

if [ "$capture_status" -ne 0 ]; then
  exit "$capture_status"
fi
