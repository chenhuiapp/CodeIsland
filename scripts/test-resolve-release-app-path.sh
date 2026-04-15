#!/usr/bin/env bash
set -euo pipefail

script_dir="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
tmp_file="$(mktemp)"
tmp_dir="$(mktemp -d)"
trap 'rm -f "$tmp_file"; rm -rf "$tmp_dir"' EXIT

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

fake_bin_dir="$tmp_dir/bin"
mkdir -p "$fake_bin_dir"

cat >"$fake_bin_dir/xcodebuild" <<'EOF'
#!/usr/bin/env bash
printf '%s\n' "$@" >"$TMP_ARGS_FILE"
cat <<'SETTINGS'
Build settings for action build and target ClaudeIsland:
    TARGET_BUILD_DIR = /tmp/DerivedData/Build/Products/Release
    WRAPPER_NAME = Mio Island.app
SETTINGS
EOF
chmod +x "$fake_bin_dir/xcodebuild"

args_file="$tmp_dir/xcodebuild-args.txt"
PATH="$fake_bin_dir:$PATH" TMP_ARGS_FILE="$args_file" bash "$script_dir/resolve-release-app-path.sh" >/dev/null

if ! grep -Fx -- "-scheme" "$args_file" >/dev/null; then
  echo "xcodebuild invocation is missing -scheme" >&2
  cat "$args_file" >&2
  exit 1
fi

if ! grep -Fx -- "ClaudeIsland" "$args_file" >/dev/null; then
  echo "xcodebuild invocation is missing the ClaudeIsland scheme value" >&2
  cat "$args_file" >&2
  exit 1
fi

if grep -Fx -- "-target" "$args_file" >/dev/null; then
  echo "xcodebuild invocation should not pass -target when using -scheme" >&2
  cat "$args_file" >&2
  exit 1
fi

echo "ok scheme"
