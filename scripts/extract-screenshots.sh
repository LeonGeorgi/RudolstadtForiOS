#!/bin/bash

set -euo pipefail

if [ "$#" -ne 2 ]; then
  echo "Usage: $0 <result-bundle-path> <output-path>" >&2
  exit 1
fi

RESULT_BUNDLE_PATH="$1"
OUTPUT_PATH="$2"

rm -rf "$OUTPUT_PATH"
mkdir -p "$OUTPUT_PATH"

if [ ! -d "$RESULT_BUNDLE_PATH" ]; then
  echo "Result bundle not found at $RESULT_BUNDLE_PATH"
  exit 0
fi

xcrun xcresulttool export attachments \
  --path "$RESULT_BUNDLE_PATH" \
  --output-path "$OUTPUT_PATH"

find "$OUTPUT_PATH" -type f \
  ! -name '*.png' \
  ! -name 'manifest.json' \
  -delete
