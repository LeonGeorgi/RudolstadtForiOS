#!/usr/bin/env bash
set -euo pipefail

project_root="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
serial="${ANDROID_SERIAL:?Set ANDROID_SERIAL to a dedicated, booted Android emulator.}"
app_id=de.leongeorgi.rudolstadt.android
apk="${PREBUILT_APK_PATH:-$project_root/androidApp/build/outputs/apk/debug/androidApp-debug.apk}"
output="${OUTPUT_ROOT:-$project_root/artifacts/screenshots/android}"
diagnostics="${DIAGNOSTICS_ROOT:-$output-diagnostics}"
adb="${ANDROID_HOME:+$ANDROID_HOME/platform-tools/}adb"
engine="${SCREENSHOT_ENGINE:-maestro}"
native_apk="${NATIVE_TEST_APK_PATH:-$project_root/androidScreenshotTests/build/outputs/apk/debug/androidScreenshotTests-debug.apk}"
native_package=de.leongeorgi.rudolstadt.screenshots
export MAESTRO_DRIVER_STARTUP_TIMEOUT="${MAESTRO_DRIVER_STARTUP_TIMEOUT:-120000}"

case "$engine" in maestro|native) ;; *) echo "Unknown screenshot engine: $engine" >&2; exit 1 ;; esac
tools=("$adb" python3)
if [[ "$engine" == maestro ]]; then tools+=(maestro); fi
for tool in "${tools[@]}"; do
    command -v "$tool" >/dev/null || { echo "Missing command: $tool" >&2; exit 1; }
done
[[ -f "$apk" ]] || { echo "Build :androidApp:assembleDebug or set PREBUILT_APK_PATH." >&2; exit 1; }
[[ "$("$adb" -s "$serial" shell getprop ro.kernel.qemu | tr -d '\r')" == 1 ]] || {
    echo 'Screenshots require a dedicated emulator, not a physical device.' >&2
    exit 1
}
mkdir -p "$output" "$diagnostics"

collect_diagnostics() {
    local status=$?
    if (( status != 0 )); then
        "$adb" -s "$serial" logcat -d > "$diagnostics/logcat.txt" 2>&1 || true
        "$adb" -s "$serial" exec-out screencap -p > "$diagnostics/failure.png" || true
        "$adb" -s "$serial" shell uiautomator dump /sdcard/screenshot-failure.xml || true
        "$adb" -s "$serial" pull /sdcard/screenshot-failure.xml "$diagnostics/hierarchy.xml" || true
    fi
}
trap collect_diagnostics EXIT

"$adb" -s "$serial" install -r "$apk"
if [[ "$engine" == native ]]; then
    [[ -f "$native_apk" ]] || { echo 'Build :androidScreenshotTests:assembleDebug first.' >&2; exit 1; }
    "$adb" -s "$serial" install -r "$native_apk"
fi
"$adb" -s "$serial" shell settings put global sysui_demo_allowed 1
"$adb" -s "$serial" shell am broadcast -a com.android.systemui.demo --es command enter
"$adb" -s "$serial" shell am broadcast -a com.android.systemui.demo --es command clock --es hhmm 0941
"$adb" -s "$serial" shell am broadcast -a com.android.systemui.demo --es command battery --es level 100 --es plugged false
"$adb" -s "$serial" shell am broadcast -a com.android.systemui.demo --es command notifications --es visible false

for locale in ${LOCALES:-de en}; do
    case "$locale" in
        de) locale_tag=de-DE ;;
        en) locale_tag=en-US ;;
        *) echo "Unsupported locale: $locale" >&2; exit 1 ;;
    esac
    "$adb" -s "$serial" shell am force-stop "$app_id"
    "$adb" -s "$serial" shell cmd locale set-app-locales "$app_id" --user 0 --locales "$locale_tag"
    for appearance in light dark; do
        case "$appearance" in light) night=no ;; dark) night=yes ;; esac
        "$adb" -s "$serial" shell cmd uimode night "$night"
        destination="$output/$locale/$appearance"
        [[ ! -e "$destination" ]] || { echo "Output already exists: $destination" >&2; exit 1; }
        if [[ "$engine" == native ]]; then
            capture="$diagnostics/$locale/$appearance/native"
            mkdir -p "$capture"
            "$adb" -s "$serial" shell am force-stop "$app_id"
            "$adb" -s "$serial" shell am instrument -w -r \
                -e class de.leongeorgi.rudolstadt.screenshots.MainScreenshots \
                -e screenshotLocale "$locale" \
                "$native_package/androidx.test.runner.AndroidJUnitRunner" \
                | tr -d '\r' | tee "$capture/instrumentation.log"
            if grep -Eq '^INSTRUMENTATION_STATUS_CODE: -' "$capture/instrumentation.log" || \
                ! grep -Eq '^OK \([1-9][0-9]* tests?\)$' "$capture/instrumentation.log"; then
                echo 'UI Automator instrumentation did not pass.' >&2
                exit 1
            fi
            remote_directory="$(sed -n 's/^INSTRUMENTATION_STATUS: screenshotDirectory=//p' "$capture/instrumentation.log" | tail -n 1)"
            [[ -n "$remote_directory" ]] || { echo 'UI Automator did not report screenshot output.' >&2; exit 1; }
            "$adb" -s "$serial" pull "$remote_directory/." "$capture/images"
        else
            for attempt in 1 2; do
                capture="$diagnostics/$locale/$appearance/attempt-$attempt"
                mkdir -p "$capture"
                set +e
                MAESTRO_CLI_NO_ANALYTICS=1 maestro test \
                    --udid "$serial" \
                    --test-output-dir "$capture" \
                    --format JUNIT --output "$capture/report.xml" \
                    --no-ansi \
                    "$project_root/.maestro/android-screenshots/screenshots.yaml" \
                    2>&1 | tee "$capture/maestro.log"
                maestro_status=$?
                set -e
                if (( maestro_status == 0 )); then
                    break
                fi
                if (( attempt == 1 )) && grep -Fq \
                    'Maestro Android driver did not start up in time' "$capture/maestro.log"; then
                    echo 'Maestro driver startup failed; retrying once with a fresh driver.'
                    "$adb" -s "$serial" shell am force-stop dev.mobile.maestro
                    "$adb" -s "$serial" shell am force-stop dev.mobile.maestro.test
                else
                    exit "$maestro_status"
                fi
            done
        fi
        python3 - "$capture" "$destination" <<'PY'
from pathlib import Path
import shutil
import sys

capture, destination = map(Path, sys.argv[1:])
names = ["01-schedule", "02-artists", "03-locations", "04-more"]
sources = {}
for name in names:
    matches = list(capture.rglob(name + ".png"))
    if len(matches) != 1:
        raise SystemExit(f"Expected one {name}.png, found {len(matches)}")
    sources[name] = matches[0]
destination.mkdir(parents=True)
for name, source in sources.items():
    shutil.copy2(source, destination / (name + ".png"))
PY
    done
done
echo "Screenshots written to $output"
