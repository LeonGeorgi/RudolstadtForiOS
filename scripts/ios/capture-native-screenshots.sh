#!/usr/bin/env bash
set -euo pipefail
project_root="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
device_id="${DEVICE_ID:?Set DEVICE_ID to a dedicated simulator.}"
derived_data="${DERIVED_DATA_PATH:-/tmp/RudolstadtNativeScreenshotDerivedData}"
output="${OUTPUT_ROOT:-$project_root/artifacts/screenshots/xctest}"
diagnostics="${DIAGNOSTICS_ROOT:-$output-diagnostics}"
capture_id="${CAPTURE_ID:-$(date +%Y-%m-%d_%H%M%S)}"
test_run="${XCTEST_RUN_FILE:-}"
mkdir -p "$diagnostics"
read -r -a locales <<< "${LOCALES:-de en}"
selectors=()
for locale in "${locales[@]}"; do
    case "$locale" in
        de) selectors+=('-only-testing:Tests iOS/NativeScreenshotTests/testGermanScreenshots') ;;
        en) selectors+=('-only-testing:Tests iOS/NativeScreenshotTests/testEnglishScreenshots') ;;
        *) echo "Unsupported locale: $locale" >&2; exit 1 ;;
    esac
done
if [[ -z "$test_run" ]]; then
    started=$SECONDS
    xcodebuild build-for-testing -quiet \
        -project "$project_root/iosApp/RudolstadtForiOS.xcodeproj" \
        -scheme 'Native Screenshots' -configuration Debug \
        -destination "platform=iOS Simulator,id=$device_id" \
        -derivedDataPath "$derived_data" 2>&1 | tee "$diagnostics/build.log"
    test_run="$(python3 - "$derived_data" <<'PY'
from pathlib import Path
import sys
files = sorted((Path(sys.argv[1]) / 'Build/Products').glob('*.xctestrun'), key=lambda p: p.stat().st_mtime)
if not files:
    raise SystemExit('No native screenshot test run was built')
print(files[-1])
PY
)"
    python3 - "$diagnostics/build.json" "$test_run" "$derived_data/Build/Products/Debug-iphonesimulator/Rudolstadt.app" "$((SECONDS-started))" <<'PY'
from pathlib import Path
import json, sys
Path(sys.argv[1]).write_text(json.dumps({'test_run':sys.argv[2], 'app':sys.argv[3], 'build_seconds':int(sys.argv[4])}, indent=2))
PY
fi
if [[ "${BUILD_ONLY:-0}" == 1 ]]; then exit 0; fi
[[ -f "$test_run" ]] || { echo "Test run missing: $test_run" >&2; exit 1; }
xcrun simctl boot "$device_id" 2>/dev/null || true
xcrun simctl bootstatus "$device_id" -b
app_path="${PREBUILT_APP_PATH:-$(dirname "$test_run")/Debug-iphonesimulator/Rudolstadt.app}"
xcrun simctl install "$device_id" "$app_path"
xcrun simctl privacy "$device_id" grant location de.leongeorgi.RudolstadtForiOS
xcrun simctl status_bar "$device_id" override --time 9:41 --dataNetwork wifi --batteryState charged --batteryLevel 100 --wifiBars 3 --cellularBars 4
trap 'xcrun simctl status_bar "$device_id" clear >/dev/null 2>&1 || true' EXIT
set +e
xcodebuild test-without-building \
    -xctestrun "$test_run" -destination "platform=iOS Simulator,id=$device_id" \
    -collect-test-diagnostics never \
    -test-timeouts-enabled YES -default-test-execution-time-allowance 300 \
    -parallel-testing-enabled NO -resultBundlePath "$diagnostics/results.xcresult" \
    "${selectors[@]}" 2>&1 | tee "$diagnostics/test.log"
status=$?
set -e
if [[ -d "$diagnostics/results.xcresult" ]]; then
    xcrun xcresulttool export attachments --path "$diagnostics/results.xcresult" --output-path "$diagnostics/attachments"
fi
if (( status != 0 )); then exit "$status"; fi
device_name="$(xcrun simctl list devices --json | python3 -c 'import json,sys; print(next(d["name"] for ds in json.load(sys.stdin)["devices"].values() for d in ds if d["udid"]==sys.argv[1]).replace(" ","_"))' "$device_id")"
python3 "$project_root/scripts/ios/export_native_screenshots.py" \
    "$diagnostics/attachments" "$output" --device "$device_name" \
    --capture-id "$capture_id" --locales "${locales[@]}"
