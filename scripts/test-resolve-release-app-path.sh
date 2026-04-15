#!/usr/bin/env bash
set -euo pipefail

script_dir="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
tmp_file="$(mktemp)"
trap 'rm -f "$tmp_file"' EXIT

cat >"$tmp_file" <<'EOF'
Build settings for action build and target ClaudeIsland:
    TARGET_BUILD_DIR = /tmp/DerivedData/Build/Products/Release
    WRAPPER_NAME = Mio Island.app
EOF

actual="$(bash "$script_dir/resolve-release-app-path.sh" --from-file "$tmp_file")"
expected="/tmp/DerivedData/Build/Products/Release/Mio Island.app"

if [[ "$actual" != "$expected" ]]; then
  echo "expected: $expected" >&2
  echo "actual:   $actual" >&2
  exit 1
fi

echo "ok"
