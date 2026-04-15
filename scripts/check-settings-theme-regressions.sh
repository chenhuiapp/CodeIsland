#!/usr/bin/env bash
set -euo pipefail

fail=0

search_matches() {
  local pattern="$1"
  shift

  if command -v rg >/dev/null 2>&1; then
    rg -n -- "$pattern" "$@"
    return $?
  fi

  CHECK_SETTINGS_PATTERN="$pattern" perl - "$@" <<'PERL'
use strict;
use warnings;
use File::Find;

my $pattern = $ENV{CHECK_SETTINGS_PATTERN};
my $regex = qr/$pattern/;
my $matched = 0;

my $scan_file = sub {
    my ($file) = @_;

    open my $fh, '<', $file or die "ERROR: failed to read $file: $!\n";
    my $line_number = 0;
    while (my $line = <$fh>) {
        $line_number++;
        if ($line =~ /$regex/) {
            print "${file}:${line_number}:${line}";
            $matched = 1;
        }
    }
};

for my $path (@ARGV) {
    if (-d $path) {
        find(
            {
                no_chdir => 1,
                wanted => sub {
                    return unless -f $_;
                    $scan_file->($File::Find::name);
                },
            },
            $path
        );
    } elsif (-f $path) {
        $scan_file->($path);
    } else {
        die "ERROR: search path does not exist: $path\n";
    }
}

exit($matched ? 0 : 1);
PERL
}

check_no_matches() {
  local pattern="$1"
  shift

  if search_matches "$pattern" "$@"; then
    echo >&2
    echo "ERROR: Forbidden pattern matched: $pattern" >&2
    echo "Searched paths: $*" >&2
    fail=1
  else
    local status=$?
    if [[ $status -ne 1 ]]; then
      echo "ERROR: search failed with status $status while searching: $pattern" >&2
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
