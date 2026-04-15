#!/usr/bin/env bash
set -euo pipefail

usage() {
  echo "Usage: $0 [--from-file <build-settings-file>]" >&2
}

if [[ $# -eq 0 ]]; then
  build_settings="$(
    xcodebuild \
      -project ClaudeIsland.xcodeproj \
      -target ClaudeIsland \
      -configuration Release \
      -derivedDataPath build \
      CODE_SIGN_IDENTITY="-" \
      CODE_SIGNING_REQUIRED=NO \
      CODE_SIGNING_ALLOWED=NO \
      DEVELOPMENT_TEAM="" \
      MACOSX_DEPLOYMENT_TARGET=15.0 \
      -showBuildSettings
  )"
elif [[ $# -eq 2 && "$1" == "--from-file" ]]; then
  build_settings="$(cat "$2")"
else
  usage
  exit 64
fi

target_build_dir="$(
  printf '%s\n' "$build_settings" |
    awk -F' = ' '$1 ~ /^[[:space:]]*TARGET_BUILD_DIR$/ { print $2; exit }'
)"
wrapper_name="$(
  printf '%s\n' "$build_settings" |
    awk -F' = ' '$1 ~ /^[[:space:]]*WRAPPER_NAME$/ { print $2; exit }'
)"

if [[ -z "$target_build_dir" || -z "$wrapper_name" ]]; then
  echo "Failed to resolve app bundle path from Xcode build settings." >&2
  exit 1
fi

printf '%s/%s\n' "$target_build_dir" "$wrapper_name"
