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

MANIFEST_PATH="$OUTPUT_PATH/manifest.json"

if [ -f "$MANIFEST_PATH" ]; then
  RENAMED_OUTPUT_PATH="$OUTPUT_PATH/renamed"
  mkdir -p "$RENAMED_OUTPUT_PATH"

  ruby -rjson -rfileutils <<'RUBY' "$OUTPUT_PATH" "$MANIFEST_PATH" "$RENAMED_OUTPUT_PATH"
output_path, manifest_path, renamed_output_path = ARGV
manifest = JSON.parse(File.read(manifest_path))

def sanitize(value)
  value.to_s.gsub(/[^A-Za-z0-9._-]+/, "_").gsub(/\A_+|_+\z/, "")
end

manifest.each do |test_details|
  attachments = test_details["attachments"] || []

  attachments.each do |attachment|
    exported_name = attachment["exportedFileName"]
    next unless exported_name

    source_path = File.join(output_path, exported_name)
    next unless File.file?(source_path)

    configuration = sanitize(attachment["configurationName"])
    device = sanitize(attachment["deviceName"])
    human_name = sanitize(attachment["suggestedHumanReadableName"])

    target_dir = File.join(renamed_output_path, configuration, device)
    FileUtils.mkdir_p(target_dir)

    extension = File.extname(exported_name)
    target_name = "#{human_name}#{extension}"
    target_path = File.join(target_dir, target_name)

    if File.exist?(target_path)
      base = File.basename(target_name, extension)
      counter = 2
      loop do
        candidate = File.join(target_dir, "#{base}_#{counter}#{extension}")
        unless File.exist?(candidate)
          target_path = candidate
          break
        end
        counter += 1
      end
    end

    FileUtils.cp(source_path, target_path)
  end
end
RUBY

  find "$OUTPUT_PATH" -mindepth 1 -maxdepth 1 ! -name 'renamed' ! -name 'manifest.json' -exec rm -rf {} +
  find "$RENAMED_OUTPUT_PATH" -mindepth 1 -maxdepth 1 -exec mv {} "$OUTPUT_PATH" \;
  rmdir "$RENAMED_OUTPUT_PATH"
fi

find "$OUTPUT_PATH" -type f \
  ! -name '*.png' \
  ! -name 'manifest.json' \
  -delete
