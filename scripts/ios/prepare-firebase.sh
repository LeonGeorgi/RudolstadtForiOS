#!/bin/sh
set -eu

# Generate the target's Info.plist so fresh Firebase SDK files also configure the
# Google callback scheme. The checked-in source plist is never modified by a build.
config="$SRCROOT/iOS/GoogleService-Info.plist"
generated="$DERIVED_FILE_DIR/Firebase-App-Info.plist"
destination="$TARGET_BUILD_DIR/$UNLOCALIZED_RESOURCES_FOLDER_PATH/GoogleService-Info.plist"
mkdir -p "$DERIVED_FILE_DIR"
cp "$SRCROOT/RudolstadtForiOS--iOS--Info.plist" "$generated"
if [ -f "$config" ]; then
    mkdir -p "$(dirname "$destination")"
    cp "$config" "$destination"
    scheme=$(/usr/libexec/PlistBuddy -c 'Print :REVERSED_CLIENT_ID' "$config" 2>/dev/null || true)
    if [ -n "$scheme" ]; then
        case "$scheme" in
            *[!a-zA-Z0-9.-]*) echo 'error: Invalid Google REVERSED_CLIENT_ID in Firebase configuration.' >&2; exit 1 ;;
        esac
        /usr/libexec/PlistBuddy -c 'Add :CFBundleURLTypes array' "$generated"
        /usr/libexec/PlistBuddy -c 'Add :CFBundleURLTypes:0 dict' "$generated"
        /usr/libexec/PlistBuddy -c 'Add :CFBundleURLTypes:0:CFBundleURLSchemes array' "$generated"
        /usr/libexec/PlistBuddy -c "Add :CFBundleURLTypes:0:CFBundleURLSchemes:0 string $scheme" "$generated"
    fi
else
    rm -f "$destination"
fi
