#!/usr/bin/env bash
# Build a locally signed APK. Signing credentials never enter Gradle or Git.
set -euo pipefail

repo_root="$(cd "$(dirname "$0")/../.." && pwd)"
cd "$repo_root"

export ANDROID_HOME="${ANDROID_HOME:-$HOME/Library/Android/sdk}"
if [[ -z "${JAVA_HOME:-}" && -x /usr/libexec/java_home ]]; then
  export JAVA_HOME="$(/usr/libexec/java_home -v 17)"
fi
build_tools="$ANDROID_HOME/build-tools/${ANDROID_BUILD_TOOLS_VERSION:-35.0.0}"
keystore="${RUDOLSTADT_KEYSTORE:-$HOME/.android/keystores/rudolstadt-release.p12}"
alias_name="${RUDOLSTADT_KEY_ALIAS:-rudolstadt-release}"
output="$repo_root/artifacts/android/rudolstadt-release.apk"

[[ -f "$keystore" ]] || { printf 'Missing release keystore: %s\n' "$keystore" >&2; exit 1; }
for tool in apksigner zipalign; do
  [[ -x "$build_tools/$tool" ]] || { printf 'Missing Android build tool: %s\n' "$build_tools/$tool" >&2; exit 1; }
done

env -u RUDOLSTADT_SIGNING_PASSWORD ./gradlew :androidApp:assembleRelease --console=plain "$@"
mkdir -p "$(dirname "$output")"
temporary_dir="$(mktemp -d "$repo_root/artifacts/android/.signing.XXXXXX")"
trap 'unset RUDOLSTADT_SIGNING_PASSWORD; rm -rf "$temporary_dir"' EXIT

if [[ -z "${RUDOLSTADT_SIGNING_PASSWORD:-}" ]]; then
  RUDOLSTADT_SIGNING_PASSWORD="$(/usr/bin/security find-generic-password \
    -a "$alias_name" -s de.leongeorgi.rudolstadt.android.release -w)"
fi
[[ -n "$RUDOLSTADT_SIGNING_PASSWORD" ]] || { printf 'Missing signing password.\n' >&2; exit 1; }
export RUDOLSTADT_SIGNING_PASSWORD

"$build_tools/zipalign" -P 16 -f 4 \
  androidApp/build/outputs/apk/release/androidApp-release-unsigned.apk \
  "$temporary_dir/aligned.apk"
"$build_tools/apksigner" sign --ks "$keystore" --ks-key-alias "$alias_name" \
  --ks-pass env:RUDOLSTADT_SIGNING_PASSWORD --key-pass env:RUDOLSTADT_SIGNING_PASSWORD \
  --v4-signing-enabled false --out "$temporary_dir/signed.apk" "$temporary_dir/aligned.apk"
unset RUDOLSTADT_SIGNING_PASSWORD
"$build_tools/apksigner" verify --verbose --print-certs "$temporary_dir/signed.apk"
"$build_tools/zipalign" -c -P 16 4 "$temporary_dir/signed.apk"
mv "$temporary_dir/signed.apk" "$output"
printf '\nSigned APK: %s\n' "$output"
