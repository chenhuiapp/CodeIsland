# Settings Theme Regression Cleanup Design

Date: 2026-04-14
Status: Approved design, pending written-spec review
Branch: `refactor/theme`

## Context

`89105545` established the pluggable settings theme system, but left several settings rows using hardcoded notch-era colors and control styling. `d70e81ac` improved part of that work by migrating some rows to `SettingsThemeStore` and by wiring `NSWindow.appearance`, but it only fixed a subset of the regressions and introduced a settings-window responsiveness regression when the `cmux Connection` tab mounts.

Confirmed behavior from the screenshot set and branch analysis:

- Fixed by `d70e81ac`
  - `Appearance > Theme`
  - `Appearance > Screen`
  - `Notifications > Notification Sound`
  - AppKit light-theme mismatch shown in `v3`
- Not fixed by `d70e81ac`
  - `Notifications > Usage Warning`
  - `General > Language`
  - `General > Accessibility`
- Regression introduced by `d70e81ac`
  - Entering `cmux Connection` leaves the app in a frozen state after the tab mounts

The user explicitly chose a broad cleanup approach to prevent future regressions rather than a narrow patch.

## Goals

1. Remove the settings window's dependency on notch-menu row implementations for the affected controls.
2. Make the migrated settings controls fully palette-driven under `SettingsThemeStore`.
3. Eliminate remaining hardcoded white/green styling in the migrated settings path.
4. Restore full interactivity when opening `cmux Connection`.
5. Keep `NSWindow` light/dark appearance syncing only if it can be made safe and passive.

## Non-Goals

- Full cleanup of every notch or menu component in the app.
- A full redesign of the settings window layout.
- Changes to non-settings theming systems.
- Changes to the cmux relay protocol itself beyond what is needed to restore responsiveness.

## Decision Summary

The fix will be architectural, not patch-by-patch:

- Create a settings-specific component layer under `ClaudeIsland/UI/Components/Settings/`.
- Stop reusing `LanguageRow`, `AccessibilityRow`, and `ThresholdPickerRow` from `NotchMenuView.swift` inside the settings window.
- Normalize the affected settings rows onto a single theme-aware component model that reads semantic roles from `SettingsThemePalette`.
- Isolate `cmux Connection` diagnostics from the view body and from main-actor blocking work.
- Keep or discard `NSWindow.appearance` based on whether it can be implemented without reintroducing hangs. Stability wins over perfect AppKit appearance fidelity.

## Architecture

### 1. Settings-Specific Component Boundary

Add a settings-only component layer:

- `ClaudeIsland/UI/Components/Settings/SettingsDisclosureRow.swift`
- `ClaudeIsland/UI/Components/Settings/SettingsSelectableOptionRow.swift`
- `ClaudeIsland/UI/Components/Settings/SettingsSegmentedChoiceRow.swift`
- `ClaudeIsland/UI/Components/Settings/SettingsPermissionRow.swift`

Responsibility split:

- `NotchMenuView.swift`
  - Continues to own notch/menu presentation patterns.
  - May keep its own hardcoded styling if needed for the notch path.
- `SystemSettingsView.swift`
  - Uses only settings-native components.
  - Must not embed notch-menu-specific rows.

Rule:

- Concrete row views are not shared across the notch menu and the settings window.
- Only small, theme-agnostic helpers may be shared between the two UI systems.

### 2. Settings Row Migration

Migrate the confirmed regression surfaces to settings-native components:

- `ThemePickerCard`
  - Keep as settings-native, but convert it to the shared disclosure/selectable-option primitives.
- `ScreenPickerRow`
  - Convert to a thin wrapper over the new settings disclosure/selectable-option primitives.
- `SoundPickerRow`
  - Convert to a thin wrapper over the new settings disclosure/selectable-option primitives.
- `ThresholdPickerRow`
  - Replace the `NotchMenuView` version in settings with a new settings-native segmented-choice row.
- `LanguageRow`
  - Replace the `NotchMenuView` version in settings with a new settings-native disclosure/selectable-option row.
- `AccessibilityRow`
  - Replace the `NotchMenuView` version in settings with a new settings-native permission/status row.

This removes the current split-brain behavior where part of the settings window is theme-aware and part of it still renders with notch-menu assumptions.

## Theme Rules

Settings-window code must follow these rules:

1. Use semantic palette roles only.
2. Do not use raw `.white.opacity(...)`, `.black`, or `TerminalColors.green` in the migrated settings path.
3. If a new visual state is needed, add a semantic role to `SettingsThemePalette` rather than introducing a one-off literal.

This rule applies to:

- foreground text
- status dots
- selected indicators
- hover fills
- segmented choice backgrounds
- permission row action buttons

The palette already covers most of the needed surface area. If a missing role is discovered during migration, the palette may be extended, but only in a way that preserves the default theme's current appearance.

## `NSWindow.appearance` Strategy

`d70e81ac` added a `Combine` observer in `SystemSettingsWindow` that reacts to `SettingsThemeStore` updates and mutates `NSWindow.appearance`. That behavior fixed the AppKit mismatch shown in `v3`, but it is not required if it compromises stability.

Decision:

- Keep `NSWindow.appearance` support only if it can be implemented as a passive, one-way update path.
- Do not keep a window-level reactive mechanism if it is part of the freeze path or creates event-loop churn.

Preferred fallback order:

1. Safe, passive `NSWindow.appearance` syncing
2. SwiftUI color-scheme propagation only

The project should prefer a minor AppKit styling mismatch over a frozen settings window.

## `cmux Connection` Freeze Remediation

### Working Hypothesis

The `cmux Connection` tab already existed before `d70e81ac`, and its view body was not changed in that commit. The freeze therefore appears to be an interaction between existing tab-load diagnostics and the new shared settings-window lifecycle behavior added in `d70e81ac`.

There is also a separate responsiveness smell in the current implementation:

- `CmuxConnectionTab` runs `.task { await refresh() }` immediately on mount.
- `refresh()` calls `TerminalWriter.shared.probeConnection()`.
- `TerminalWriter` is `@MainActor`.
- `probeConnection()` performs automation-permission probing synchronously through `probeAutomationPermission()`.

Even if the precise freeze mechanism is not fully proven yet, the design must make tab entry non-blocking by construction.

### Remediation Design

Introduce a dedicated diagnostics model, for example:

- `ClaudeIsland/Services/Sync/CmuxConnectionDiagnosticsService.swift`
- `ClaudeIsland/UI/ViewModels/CmuxConnectionViewModel.swift`

Responsibilities:

- `CmuxConnectionDiagnosticsService`
  - Runs probe steps off the main actor.
  - Wraps shell, process, and automation-permission checks behind async APIs.
  - Returns a single snapshot value for UI consumption.
- `CmuxConnectionViewModel`
  - Owns UI state: idle, loading, loaded, failed.
  - Starts loading when the tab appears.
  - Publishes results back to the main actor.
  - Supports cancellation when the tab disappears or a new refresh starts.

Behavioral requirements:

- Entering the `cmux Connection` tab must render immediately.
- The tab must remain interactive while diagnostics load.
- Slow or blocked probes must degrade into timeout/error states rather than freezing the window.

### Main-Actor Rule

No diagnostic probe step may synchronously block the main actor.

In particular:

- permission probing
- process enumeration
- env inspection
- shell-backed diagnostics

must all execute behind async boundaries that do not pin the settings view to the main thread.

## Data Flow

After cleanup, the relevant settings flow becomes:

1. `SystemSettingsWindow` creates the settings content with `SettingsThemeStore`.
2. Settings-native row components read semantic palette values.
3. User interaction updates app state through existing selectors or stores.
4. The `cmux Connection` tab asks its view model to load diagnostics.
5. The view model asks the diagnostics service for a snapshot.
6. The diagnostics service performs off-main work and returns a snapshot.
7. The view model publishes the result back to the UI.

This isolates theming, interaction, and diagnostics so future settings work does not need to touch notch rows or window-lifecycle plumbing.

## Error Handling

### Theme Cleanup

- Missing palette roles should fail at compile time by requiring explicit palette additions.
- Missing theme plugin data should continue to fall back to `SettingsThemePalette.default`.

### Diagnostics

- Failed probe steps should produce partial diagnostic results, not a hung UI.
- Timeouts should surface as status text or unknown-state indicators.
- A diagnostics failure must not prevent tab rendering or navigation away from the tab.

### Appearance Sync

- If passive `NSWindow.appearance` syncing still causes responsiveness issues, remove it rather than layering more observers onto the window.

## Validation Plan

### Functional Acceptance

- `Appearance`
  - `Theme` and `Screen` remain readable under light themes.
- `Notifications`
  - `Notification Sound` and `Usage Warning` remain readable under light themes.
- `General`
  - `Language`, `Accessibility`, and proxy field presentation remain readable under light themes.
- `cmux Connection`
  - entering the tab does not freeze the app
  - the tab renders immediately and loads diagnostics asynchronously

### Structural Acceptance

- `SystemSettingsView` no longer embeds notch-menu row implementations for the migrated controls.
- The migrated settings path has no raw white/green literals.
- The diagnostics load path is no longer architected around main-actor blocking work.

### Verification Work

- Add unit coverage where low-cost and stable, especially around extracted helper logic and diagnostics state handling.
- Run repository verification that is feasible in this environment.
- Perform a targeted source scan for forbidden raw color literals in the migrated settings path.
- If native macOS UI interaction cannot be fully exercised here, record that limitation explicitly and rely on static verification plus the normal GitHub Actions build pipeline.

## Implementation Notes For The Follow-Up Plan

The implementation plan should break work into these chunks:

1. Extract settings-native row primitives.
2. Migrate `Theme`, `Screen`, `Notification Sound`, `Usage Warning`, `Language`, and `Accessibility`.
3. Re-evaluate or remove the `NSWindow.appearance` observer path.
4. Extract cmux diagnostics loading into a dedicated service and view model.
5. Add verification and regression guards.
