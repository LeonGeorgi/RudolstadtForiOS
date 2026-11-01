#!/usr/bin/env bash
set -euo pipefail

project_root="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
export ANDROID_HOME="${ANDROID_HOME:-$HOME/Library/Android/sdk}"
if [[ -z "${JAVA_HOME:-}" ]]; then
    export JAVA_HOME="$(/usr/libexec/java_home -v 17)"
fi

adb="$ANDROID_HOME/platform-tools/adb"
emulator="$ANDROID_HOME/emulator/emulator"
avd="${ANDROID_AVD_NAME:-Rudolstadt_API_36}"
port="${ANDROID_EMULATOR_PORT:-5554}"
serial="emulator-$port"
app_id="de.leongeorgi.rudolstadt.android"
output="$project_root/artifacts/android"

if [[ ! -x "$adb" || ! -x "$emulator" ]]; then
    echo "Android SDK or emulator missing. See androidApp/README.md." >&2
    exit 1
fi
if ! "$emulator" -list-avds | grep -Fxq "$avd"; then
    echo "AVD '$avd' missing. See androidApp/README.md." >&2
    exit 1
fi

cd "$project_root"
./gradlew :androidApp:assembleDebug --console=plain
mkdir -p "$output"
"$adb" start-server

if [[ "$("$adb" -s "$serial" get-state 2>/dev/null || true)" == "device" ]]; then
    running_avd="$("$adb" -s "$serial" emu avd name | tr -d '\r' | head -n 1)"
    if [[ "$running_avd" != "$avd" ]]; then
        echo "$serial is running '$running_avd'. Set ANDROID_EMULATOR_PORT to a free even port." >&2
        exit 1
    fi
else
    # A separate session keeps the emulator window alive after this script exits.
    python3 - "$emulator" "$avd" "$port" "$output/emulator.log" <<'PY'
import subprocess
import sys

emulator, avd, port, log_path = sys.argv[1:]
with open(log_path, "w") as log:
    subprocess.Popen(
        [emulator, "-avd", avd, "-port", port, "-no-boot-anim", "-no-audio"],
        stdin=subprocess.DEVNULL,
        stdout=log,
        stderr=subprocess.STDOUT,
        start_new_session=True,
    )
PY
fi

deadline=$((SECONDS + 180))
until [[ "$("$adb" -s "$serial" shell getprop sys.boot_completed 2>/dev/null | tr -d '\r')" == "1" ]]; do
    if (( SECONDS >= deadline )); then
        echo "Emulator did not boot within 180 seconds. See $output/emulator.log." >&2
        exit 1
    fi
    sleep 2
done

"$adb" -s "$serial" install -r "$project_root/androidApp/build/outputs/apk/debug/androidApp-debug.apk"
"$adb" -s "$serial" shell am start -W -n "$app_id/.MainActivity"
echo "Rudolstadt is running on $serial ($avd)."
