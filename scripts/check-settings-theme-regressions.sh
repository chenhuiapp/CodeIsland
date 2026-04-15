#!/usr/bin/env bash
set -euo pipefail

fail=0

check_no_matches() {
  local pattern="$1"
  shift

  if rg -n -- "$pattern" "$@"; then
    echo >&2
    echo "ERROR: Forbidden pattern matched: $pattern" >&2
    echo "Searched paths: $*" >&2
    fail=1
  else
    local status=$?
    if [[ $status -ne 1 ]]; then
      echo "ERROR: rg failed with status $status while searching: $pattern" >&2
      exit "$status"
    fi
  fi
}

# Migrated settings path should not reuse notch menu rows / legacy settings components.
# Use word boundaries to avoid false positives like `SettingsScreenPickerRow(`.
check_no_matches '\bLanguageRow\s*\(' \
  ClaudeIsland/UI/Views/SystemSettingsView.swift \
  ClaudeIsland/UI/Components/Settings
check_no_matches '\bAccessibilityRow\s*\(' \
  ClaudeIsland/UI/Views/SystemSettingsView.swift \
  ClaudeIsland/UI/Components/Settings
check_no_matches '\bThresholdPickerRow\s*\(' \
  ClaudeIsland/UI/Views/SystemSettingsView.swift \
  ClaudeIsland/UI/Components/Settings
check_no_matches '\bScreenPickerRow\s*\(' \
  ClaudeIsland/UI/Views/SystemSettingsView.swift \
  ClaudeIsland/UI/Components/Settings
check_no_matches '\bSoundPickerRow\s*\(' \
  ClaudeIsland/UI/Views/SystemSettingsView.swift \
  ClaudeIsland/UI/Components/Settings
check_no_matches '\bThemePickerCard\b' \
  ClaudeIsland/UI/Views/SystemSettingsView.swift \
  ClaudeIsland/UI/Components/Settings

# Migrated settings path should not regress to hardcoded literal colors.
check_no_matches 'Color\.white\.opacity|TerminalColors\.green|\.fill\(Color\.white\)|Color\.black\b|(^|[^A-Za-z0-9_])\.black\b' \
  ClaudeIsland/UI/Components/Settings \
  ClaudeIsland/UI/Views/SystemSettingsView.swift

exit "$fail"
