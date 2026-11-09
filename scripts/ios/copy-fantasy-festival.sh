#!/bin/sh
set -eu
: "${TARGET_BUILD_DIR:?}" "${UNLOCALIZED_RESOURCES_FOLDER_PATH:?}" "${CONFIGURATION:?}"

# Keep the fixture and all artist photos out of every non-Debug app bundle.
# Removing a previous copy also handles reusing a build products directory.
destination="$TARGET_BUILD_DIR/$UNLOCALIZED_RESOURCES_FOLDER_PATH/FantasyFestival"
if [ "$CONFIGURATION" = "Debug" ]; then
    source_directory="$SRCROOT/../shared/src/debugResources/FantasyFestival"
    test -f "$source_directory/program.json"
    mkdir -p "$destination"
    /usr/bin/rsync -a --delete "$source_directory/" "$destination/"
else
    rm -rf "$destination"
fi
