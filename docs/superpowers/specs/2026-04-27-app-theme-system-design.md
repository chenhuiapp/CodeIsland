# App Theme System — Design Spec

**Date:** 2026-04-27
**Status:** Approved (design phase) — pending implementation plan
**Author:** chenhuiapp (designed with Claude)

## Goal

Add a second, independent **App Theme** picker to the Settings window of CodeIsland (post-UI-overhaul `main`). The App Theme governs the appearance of the **Settings window only** — chrome, illustrations, and tab icons — and is selected independently of the existing notch theme.

The first App Theme plugin is `tempo.bundle` (already authored at `~/Downloads/tmp/island/tempo-theme/tempo.bundle`). The plugin's `Resources/plugin.json` schema is treated as a **fixed input** to this design — the system must load it without modification.

## Non-Goals

- Modifying the existing notch theme system (`NotchTheme`, `ThemeRegistry`, `ThemeTokens`, `ThemeResolver`, `NotchPaletteModifier`, `NotchCustomizationSettingsView`). All untouched.
- Theming surfaces beyond the Settings window (e.g. Chat view, Plugin store, Pair-phone view, Notch interior). Out of scope for this iteration.
- Reusing `feat/context`'s settings-theme code. That code is **reference only** — this work is built fresh on `main`, fitting `main`'s conventions.
- Loading App Themes from `~/.config/codeisland/`. Plugin-only loading for v1; user-directory loading is a future increment.

## Architecture

A new App Theme subsystem parallel to (and independent of) main's notch theme system. Same shape, no shared types.

```
                                NativePluginManager.$loadedPlugins
                                          │  (Combine subscription)
                                          ▼
   ┌─────────────────────────────┐    AppThemeRegistry             ┌────────────────────────┐
   │     Built-in default        │    @Published availableThemes ──┤  AppThemePickerCard    │
   │  (mirrors current settings  │    descriptor(for:)             │  (Appearance tab,      │
   │   appearance)               │    displayName(for:)            │   above NotchCust.)    │
   └────────────┬────────────────┘                                 └───────────┬────────────┘
                │ feeds                                                        │ writes
                ▼                                                              ▼
   ┌─────────────────────────────┐   activate(descriptor:)          ┌────────────────────────┐
   │       AppThemeStore         │ ◄──────────────────────────────  │  user clicks a card    │
   │  @Published palette         │   reset()                        └────────────────────────┘
   │  @Published activeThemeID   │
   └────────────┬────────────────┘
                │ palette read at every render
                ▼
   ┌─────────────────────────────┐
   │   SystemSettingsView.Theme  │   reads AppThemeStore.shared.palette[role]
   │   (existing static enum)    │   if present, else falls back to
   │                             │   ThemeResolver(notchTheme).<role>.
   └─────────────────────────────┘
```

### Boundaries

- `AppThemeRegistry` knows plugin discovery + manifest decoding only. Doesn't know what's "active."
- `AppThemeStore` knows the active theme's resolved palette + persistence only. Doesn't talk to plugins; receives a manifest from the registry on activation.
- `SystemSettingsView.Theme` (existing static enum) is the single style sink for the Settings window. Only its source changes: App Theme palette first, notch fallback second.
- Notch theme system is untouched.

## Components

### New files

| Path | Role |
|---|---|
| `ClaudeIsland/Models/AppThemeID.swift` | `RawRepresentable, Codable, Hashable, Identifiable` ID type. Mirrors `NotchThemeID`. Has built-in `.default`. |
| `ClaudeIsland/Models/AppThemeManifest.swift` | `Codable` types matching tempo's `plugin.json` `settings` block (`colorScheme`, `sidebar`, `detail`, `illustrations`, `icons`). Outer wrapper decodes `{ type, id, settings }` so we can filter `type == "theme"`. |
| `ClaudeIsland/Models/AppThemePalette.swift` | Resolved value type (`Equatable`). Color roles are `Color?` so a manifest can partially override; consumer falls back when nil. Optional `illustrations` (`[URL]` + duration + transition) and `icons` (`[String: String]` SF-Symbol map). Static `.default` matches main's current settings appearance. Factory `from(manifest:bundleResourcesURL:)`. |
| `ClaudeIsland/Models/AppThemeRegistry.swift` | `@MainActor ObservableObject`, `static let shared`. `@Published availableThemes: [AppThemeDescriptor]`. Built-in `.default` first. Subscribes to `NativePluginManager.shared.$loadedPlugins`; on each emission scans every loaded bundle's `Contents/Resources/plugin.json`, decodes only `type == "theme"` entries with a `settings` block. Dedup by `id`. |
| `ClaudeIsland/Core/AppThemeStore.swift` | `@MainActor ObservableObject`, `static let shared`. `@Published palette: AppThemePalette = .default`, `@Published activeThemeID: AppThemeID?`. Persists ID under `AppTheme.activeThemeID` UserDefault. `activate(descriptor:)`, `reset()`. |
| `ClaudeIsland/UI/Helpers/AppThemeReader.swift` | Tiny `.appThemed()` modifier injecting `AppThemeStore.shared` as `@EnvironmentObject`, used at the settings-window root. |
| `ClaudeIsland/UI/Views/AppThemePickerCard.swift` | New card UI for the Appearance tab. Two-column grid mirroring `NotchCustomizationSettingsView`'s pattern but rendered with settings-style miniatures. Iterates `AppThemeRegistry.shared.availableThemes`. Click → `AppThemeStore.shared.activate(descriptor:)`. |

### Tests (new)

| Path | Coverage |
|---|---|
| `ClaudeIslandTests/AppThemeManifestDecodingTests.swift` | Tempo fixture decode; `type != "theme"` skip; missing `settings` skip; partial-color manifest; malformed hex tolerated (resolution fails later, not at decode). |
| `ClaudeIslandTests/AppThemePaletteTests.swift` | `.default` non-nil for every role; `from(manifest:bundleResourcesURL:)` resolves valid hex → `Color`, invalid hex → `nil`; partial manifest leaves other roles nil; missing illustration files filtered out; all-missing illustrations → `palette.illustrations == nil`. |
| `ClaudeIslandTests/AppThemeRegistryTests.swift` | Built-in default first; theme plugins appended; non-theme bundles skipped; duplicate ids deduped (first wins); unloading drops descriptor; missing `activeThemeID` after reload triggers `AppThemeStore.shared.reset()`. Uses injected fake `loadedPlugins`. |
| `ClaudeIslandTests/AppThemeStoreTests.swift` | Initial state honors persisted UserDefault; `activate` updates palette + ID + persistence; `reset` clears all three; subsequent `activate` cleanly replaces. Uses injected `UserDefaults`. |
| `scripts/test-app-theme-tempo-fixture.swift` | Standalone Swift script. Loads the actual tempo `plugin.json` + asset GIFs from a fixtures path; asserts `colorScheme == .light`, all 5 sidebar + 6 detail roles non-nil, 3 illustration URLs resolved, 4 icon names mapped. Catches schema regressions outside Xcode. |

### Touched main files

| Path | Change |
|---|---|
| `ClaudeIsland/App/AppDelegate.swift` | At launch: `_ = AppThemeRegistry.shared` (kicks off Combine subscription); inject `AppThemeStore.shared` into the settings window's hosting environment. |
| `ClaudeIsland/UI/Views/SystemSettingsView.swift` | (a) `AppearanceTab`: insert new `SettingsCard` containing `AppThemePickerCard()` above the existing notch customization card. (b) `Theme` static enum: route every read through `appPalette.role ?? resolver.role`. (c) Settings root: `@StateObject private var appThemeStore = AppThemeStore.shared` so palette swaps re-render. |

### What stays untouched

- `NotchTheme.swift`, `ThemeTokens.swift`, `ThemeRegistry.swift`, `ThemeResolver.swift`, `NotchPaletteModifier.swift`, `NotchCustomizationSettingsView.swift`.
- `NativePluginManager.swift` — registry observes the existing `$loadedPlugins`; no plugin-loader edits.

## Data Flow

### Cold start (active theme persisted from previous session)

```
1. App launch
   AppDelegate.applicationDidFinishLaunching
   ├── _ = AppThemeRegistry.shared
   │     reads UserDefaults `AppTheme.activeThemeID` → seeds pendingActivateID
   │     availableThemes = [.default]
   │     subscribes to NativePluginManager.shared.$loadedPlugins
   └── _ = AppThemeStore.shared
         palette = .default; activeThemeID = persisted ID

2. NativePluginManager finishes scanning bundles
   $loadedPlugins emits → AppThemeRegistry.loadAll()
   ├── decode each bundle's Contents/Resources/plugin.json
   ├── keep entries with type == "theme" && settings != nil
   ├── dedup by id, append to availableThemes
   └── if availableThemes contains pendingActivateID:
         AppThemeStore.shared.activate(descriptor: …)
```

### User picks a theme

```
Click in AppThemePickerCard
   └── AppThemeStore.shared.activate(descriptor: tappedDescriptor)
         palette = AppThemePalette.from(manifest:, bundleResourcesURL:)
         activeThemeID = descriptor.id
         UserDefaults.set(id) → "AppTheme.activeThemeID"

objectWillChange fires
   ├── SystemSettingsView root re-evaluates
   ├── Theme.* static vars re-read appPalette.role ?? resolver.role
   └── every settings surface re-renders

Click "Default" tile (or reset action)
   └── AppThemeStore.shared.reset()
         palette = .default; activeThemeID = nil; UserDefaults.removeObject(forKey:)
```

### Plugin install / uninstall at runtime

```
Install tempo.bundle
   NativePluginManager updates loadedPlugins
   └── AppThemeRegistry.loadAll() re-runs
         availableThemes now contains "tempo"
         picker grid re-renders with the new tile

Uninstall the active app theme
   NativePluginManager updates loadedPlugins (tempo gone)
   └── AppThemeRegistry.loadAll() re-runs
         availableThemes drops "tempo"
         registry sees activeThemeID no longer present →
         AppThemeStore.shared.reset()
```

### Render-time fallback

```
SystemSettingsView.Theme.sidebarFill
  → if appPalette.sidebar.fill != nil → return appPalette.sidebar.fill
  → else                              → return resolver.overlay.opacity(0.94)

(Same shape for every role. Roles tempo doesn't override keep deriving from notch theme.)
```

With **no app theme picked**, the Appearance tab looks exactly as it does on main today. With **tempo picked**, sidebar/detail/cardFill/cardBorder/subtle/accent/illustrations/icons swap to tempo; all other roles still track the notch theme.

## Error Handling & Edge Cases

| Failure mode | Behavior |
|---|---|
| `plugin.json` missing, unreadable, malformed | Registry logs warning, skips bundle, continues. Never throws. |
| Manifest decodes but `type != "theme"` or `settings` missing | Silently skipped. |
| Hex string in a color role fails to parse | Role resolves to `nil`. Consumer falls back to notch-derived value. Rest of palette still loads. |
| Illustration file path doesn't resolve under the bundle's `Resources/` | Entry dropped from URL list. If all entries fail, `palette.illustrations = nil` and the sidebar skips the illustration view. |
| Icon SF-Symbol name invalid | SwiftUI renders nothing for unknown symbols; no crash. No pre-validation. |
| Persisted `activeThemeID` references a theme no longer in `availableThemes` | After every `loadAll`, registry checks; if missing, calls `AppThemeStore.shared.reset()`. UserDefault cleared. |
| Two plugins ship the same `id` | First-seen wins (dedup). Second logged and dropped. |
| Same plugin appears twice in `loadedPlugins` (defensive) | Same dedup catches it. |
| Settings window opens before `NativePluginManager` finished scanning | Picker initially shows only built-in default. Combine emission re-renders the grid when ready. |
| User picks a theme then immediately opens a sub-tab | `objectWillChange` triggers full re-render — no stale colors. |
| `colorScheme` declared `"light"` while macOS is Dark Mode (or vice-versa) | When an app theme is active, settings root applies `.preferredColorScheme(palette.colorScheme)` so SwiftUI system controls match the theme. When no app theme is active, no override — system mode flows through. |
| Notch theme changed while an app theme is active | App-theme roles continue to override; un-overridden roles shift to the new notch theme. |
| App theme reset while inside the settings window | Standard `objectWillChange` re-render. |
| Decoding races (registry on background queue, store `@MainActor`) | Both types `@MainActor`; activation hops to MainActor explicitly when invoked from registry's Combine sink. |

**Opinionated call:** Hex strings and SF-Symbol names are not validated at decode time. Validation is implicit at render (parse fails → nil → fallback). Keeps the manifest decoder small and matches main's existing `ThemeColorToken(hex:)` philosophy.

## Testing Strategy

Mirrors main's pattern — XCTest for pure types, `scripts/test-*.swift` for fixture verification. No SwiftUI snapshot tests.

**Test order during implementation (TDD):**
1. `AppThemeManifestDecodingTests` — pins the contract against tempo's existing JSON.
2. `AppThemePaletteTests`.
3. `AppThemeRegistryTests`.
4. `AppThemeStoreTests`.
5. `scripts/test-app-theme-tempo-fixture.swift`.
6. UI integration last, after all pure-type tests are green.

**Explicitly NOT tested:**
- SwiftUI view rendering (main doesn't snapshot-test SwiftUI; visual verification more reliable).
- `Theme` enum re-render plumbing (testing standard Combine + SwiftUI behavior).
- `colorScheme` override (SwiftUI primitive; visual verification).

## Open Questions

None at design time. The plugin schema is fixed by the existing tempo bundle, and every architectural choice has been made above.

## References

- Existing tempo plugin: `~/Downloads/tmp/island/tempo-theme/tempo.bundle`
- Main's notch theme system (mirrored pattern):
  - `ClaudeIsland/Models/NotchTheme.swift`
  - `ClaudeIsland/Models/ThemeTokens.swift`
  - `ClaudeIsland/Models/ThemeRegistry.swift`
  - `ClaudeIsland/UI/Helpers/ThemeResolver.swift`
- Main's plugin loader: `ClaudeIsland/Services/Plugin/NativePluginManager.swift`
- Main's settings entry point: `ClaudeIsland/UI/Views/SystemSettingsView.swift` (`AppearanceTab`, `Theme` static enum line 232)
- Reference (do not copy): `feat/context` branch — `SettingsThemePalette.swift`, `SettingsThemeStore.swift`, `SettingsThemePickerRow.swift`
