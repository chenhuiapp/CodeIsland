# App Theme System Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Add an independent App Theme picker to the Settings window of CodeIsland (post-UI-overhaul `main`), driven by a separate plugin theme system that loads `tempo.bundle` unmodified.

**Architecture:** A new App Theme subsystem mirrors the existing `NotchTheme` / `ThemeRegistry` / `ThemeResolver` triplet — same shape, no shared types. `AppThemeRegistry` discovers plugins via `NativePluginManager.$loadedPlugins` (Combine), `AppThemeStore` holds the active palette and persists the ID, `AppThemePickerCard` renders the picker grid. `SystemSettingsView`'s existing static `Theme` enum keeps every settings color centralized — only its source changes (App palette first, notch fallback second).

**Tech Stack:** Swift 5.9+, SwiftUI (macOS 26.x), Combine, `@MainActor` ObservableObjects. No new dependencies.

---

## Pre-flight (read before starting any task)

- **Branch:** `feat/app-theme` (already created, spec committed at `d62081f9`).
- **Synchronized folder:** `ClaudeIsland/` is a `PBXFileSystemSynchronizedRootGroup` — any `.swift` file dropped under it is auto-included in the app target. **No `project.pbxproj` edits needed for new sources.**
- **Test convention:** This project has no Xcode test target. Standalone Swift scripts under `scripts/` are the runtime authority (`swift scripts/test-foo.swift`). XCTest files under `ClaudeIslandTests/` are scaffolding for if/when a test target is wired up — they ship alongside scripts but are not executed.
  - Script convention: inline a copy of the type-under-test, then assert against it. See `scripts/test-completion-panel-state.swift` for the canonical example. The header comment in each script states: *"Copy of X + nested types (kept in sync with ClaudeIsland/Y/X.swift)"*.
- **Tempo fixture path:** `~/Downloads/tmp/island/tempo-theme/tempo.bundle/` — the actual bundle is read by Task 9's end-to-end fixture script. Manifest at `Contents/Resources/plugin.json`, illustration GIFs at `Contents/Resources/assets/illus_{1,2,3}.gif`.
- **Build command:** `xcodebuild -project ClaudeIsland.xcodeproj -scheme ClaudeIsland -configuration Debug build` (run from repo root).
- **Color(hex:) helper:** Already exists in main (used by `ThemeColorToken.color`). Confirm at the start of Task 4 by grepping; if missing, add it inside `AppThemePalette.swift` rather than introducing a separate Color extension.

---

## Task 1: AppThemeID — RawRepresentable identity type

**Files:**
- Create: `ClaudeIsland/Models/AppThemeID.swift`
- Test: `scripts/test-app-theme-id.swift`
- Scaffold: `ClaudeIslandTests/AppThemeIDTests.swift`

- [ ] **Step 1: Write the failing standalone test script**

Create `scripts/test-app-theme-id.swift`:

```swift
#!/usr/bin/env swift
import Foundation

// === Copy of AppThemeID (kept in sync with
//     ClaudeIsland/Models/AppThemeID.swift) ===

struct AppThemeID: RawRepresentable, Codable, Hashable, Identifiable {
    let rawValue: String
    var id: String { rawValue }
    init(rawValue: String) { self.rawValue = rawValue }
    static let `default` = AppThemeID(rawValue: "default")
}

// === Tests ===

func assertEqual<T: Equatable>(_ a: T, _ b: T, _ label: String) {
    if a != b {
        print("FAIL: \(label)\n  got:      \(a)\n  expected: \(b)")
        exit(1)
    }
}

let id1 = AppThemeID(rawValue: "tempo")
let id2 = AppThemeID(rawValue: "tempo")
let id3 = AppThemeID(rawValue: "default")

assertEqual(id1, id2, "rawValue equality")
assertEqual(id1.hashValue, id2.hashValue, "hashValue equality")
assertEqual(id1.id, "tempo", "Identifiable.id mirrors rawValue")
assertEqual(AppThemeID.default, id3, "static .default constant")

// Codable round-trip
let encoded = try JSONEncoder().encode(id1)
let decoded = try JSONDecoder().decode(AppThemeID.self, from: encoded)
assertEqual(decoded, id1, "Codable round-trip")

// Hash uniqueness
let set: Set<AppThemeID> = [id1, id2, id3]
assertEqual(set.count, 2, "Set deduplicates equal IDs")

print("PASS: AppThemeID — \(set.count == 2 ? 5 : 0)/5 assertions")
```

- [ ] **Step 2: Run the script — should pass (it tests its own inline copy)**

Run: `swift scripts/test-app-theme-id.swift`
Expected: `PASS: AppThemeID — 5/5 assertions`

- [ ] **Step 3: Create the production file mirroring the inline copy**

Create `ClaudeIsland/Models/AppThemeID.swift`:

```swift
//
//  AppThemeID.swift
//  ClaudeIsland
//
//  Identity type for the App Theme system. Mirrors NotchThemeID's shape
//  but is a distinct type — App Theme and Notch Theme are independent.
//

import Foundation

struct AppThemeID: RawRepresentable, Codable, Hashable, Identifiable {
    let rawValue: String
    var id: String { rawValue }

    init(rawValue: String) {
        self.rawValue = rawValue
    }

    /// Built-in default theme — equivalent to no override applied.
    static let `default` = AppThemeID(rawValue: "default")
}
```

- [ ] **Step 4: Build the app to verify the new file compiles**

Run: `xcodebuild -project ClaudeIsland.xcodeproj -scheme ClaudeIsland -configuration Debug build -quiet`
Expected: exit 0, no errors.

- [ ] **Step 5: Create XCTest scaffolding**

Create `ClaudeIslandTests/AppThemeIDTests.swift`:

```swift
//
//  AppThemeIDTests.swift
//  ClaudeIslandTests
//
//  Note: project has no XCTest target. Runtime authority is
//  scripts/test-app-theme-id.swift.
//

import XCTest
@testable import ClaudeIsland

final class AppThemeIDTests: XCTestCase {
    func testRawValueEquality() {
        XCTAssertEqual(AppThemeID(rawValue: "tempo"), AppThemeID(rawValue: "tempo"))
    }

    func testIdentifiableMirrorsRawValue() {
        XCTAssertEqual(AppThemeID(rawValue: "tempo").id, "tempo")
    }

    func testDefaultConstant() {
        XCTAssertEqual(AppThemeID.default, AppThemeID(rawValue: "default"))
    }

    func testCodableRoundTrip() throws {
        let id = AppThemeID(rawValue: "tempo")
        let encoded = try JSONEncoder().encode(id)
        let decoded = try JSONDecoder().decode(AppThemeID.self, from: encoded)
        XCTAssertEqual(decoded, id)
    }

    func testHashableSetDedup() {
        let set: Set<AppThemeID> = [
            AppThemeID(rawValue: "tempo"),
            AppThemeID(rawValue: "tempo"),
            AppThemeID(rawValue: "default"),
        ]
        XCTAssertEqual(set.count, 2)
    }
}
```

- [ ] **Step 6: Commit**

```bash
rtk git add scripts/test-app-theme-id.swift ClaudeIsland/Models/AppThemeID.swift ClaudeIslandTests/AppThemeIDTests.swift
rtk git commit -m "feat(app-theme): add AppThemeID identity type"
```

---

## Task 2: AppThemeManifest — Codable types matching tempo's plugin.json

**Files:**
- Create: `ClaudeIsland/Models/AppThemeManifest.swift`
- Test: `scripts/test-app-theme-manifest.swift`
- Scaffold: `ClaudeIslandTests/AppThemeManifestTests.swift`

- [ ] **Step 1: Write the failing test script**

Create `scripts/test-app-theme-manifest.swift`:

```swift
#!/usr/bin/env swift
import Foundation

// === Copy of AppThemeManifest types (kept in sync with
//     ClaudeIsland/Models/AppThemeManifest.swift) ===

struct AppThemePluginManifest: Decodable {
    let type: String
    let id: String
    let name: String?
    let settings: AppThemeManifestSettings?
}

struct AppThemeManifestSettings: Decodable, Equatable {
    let colorScheme: String?
    let sidebar: AppThemeSidebarColors?
    let detail: AppThemeDetailColors?
    let illustrations: AppThemeIllustrationsManifest?
    let icons: [String: String]?
}

struct AppThemeSidebarColors: Decodable, Equatable {
    let fill: String?
    let text: String?
    let selected: String?
    let selectedText: String?
    let border: String?
}

struct AppThemeDetailColors: Decodable, Equatable {
    let fill: String?
    let text: String?
    let cardFill: String?
    let cardBorder: String?
    let subtle: String?
    let accent: String?
}

struct AppThemeIllustrationsManifest: Decodable, Equatable {
    let files: [String]
    let cycleDuration: Double?
    let transition: String?
}

// === Tests ===

func assert(_ cond: Bool, _ label: String) {
    if !cond { print("FAIL: \(label)"); exit(1) }
}

let decoder = JSONDecoder()

// Test 1: Decode tempo's full plugin.json
let tempoJSON = #"""
{
  "type": "theme",
  "id": "tempo",
  "name": "Tempo",
  "settings": {
    "colorScheme": "light",
    "sidebar": {
      "fill": "#F5F5F3", "text": "#1A1A1A", "selected": "#1A1A1A",
      "selectedText": "#F5F5F3", "border": "#E0E0E0"
    },
    "detail": {
      "fill": "#FFFFFF", "text": "#1A1A1A", "cardFill": "#F0F0EE",
      "cardBorder": "#E0E0E0", "subtle": "#8A8A8A", "accent": "#34C759"
    },
    "illustrations": {
      "files": ["assets/illus_1.gif", "assets/illus_2.gif"],
      "cycleDuration": 8, "transition": "crossfade"
    },
    "icons": {
      "general": "gearshape", "appearance": "paintbrush.pointed.fill"
    }
  }
}
"""#
let tempo = try decoder.decode(AppThemePluginManifest.self, from: Data(tempoJSON.utf8))
assert(tempo.type == "theme", "tempo type")
assert(tempo.id == "tempo", "tempo id")
assert(tempo.name == "Tempo", "tempo name")
assert(tempo.settings?.colorScheme == "light", "tempo colorScheme")
assert(tempo.settings?.sidebar?.fill == "#F5F5F3", "tempo sidebar.fill")
assert(tempo.settings?.detail?.accent == "#34C759", "tempo detail.accent")
assert(tempo.settings?.illustrations?.files.count == 2, "tempo illustrations count")
assert(tempo.settings?.illustrations?.cycleDuration == 8, "tempo cycleDuration")
assert(tempo.settings?.icons?["general"] == "gearshape", "tempo icon general")

// Test 2: Non-theme plugin still decodes (filter happens in registry)
let buddyJSON = #"{"type":"buddy","id":"x","settings":null}"#
let buddy = try decoder.decode(AppThemePluginManifest.self, from: Data(buddyJSON.utf8))
assert(buddy.type == "buddy", "non-theme type preserved")
assert(buddy.settings == nil, "non-theme settings nil")

// Test 3: Theme manifest with missing settings still decodes
let bareThemeJSON = #"{"type":"theme","id":"bare"}"#
let bare = try decoder.decode(AppThemePluginManifest.self, from: Data(bareThemeJSON.utf8))
assert(bare.settings == nil, "missing settings → nil")

// Test 4: Partial settings (only sidebar)
let partialJSON = #"""
{"type":"theme","id":"p","settings":{"sidebar":{"fill":"#000000"}}}
"""#
let partial = try decoder.decode(AppThemePluginManifest.self, from: Data(partialJSON.utf8))
assert(partial.settings?.sidebar?.fill == "#000000", "partial sidebar fill")
assert(partial.settings?.sidebar?.text == nil, "partial missing text → nil")
assert(partial.settings?.detail == nil, "partial missing detail → nil")
assert(partial.settings?.icons == nil, "partial missing icons → nil")

// Test 5: Malformed hex tolerated at decode (raw string preserved)
let malformedJSON = #"""
{"type":"theme","id":"m","settings":{"detail":{"accent":"not-a-hex"}}}
"""#
let malformed = try decoder.decode(AppThemePluginManifest.self, from: Data(malformedJSON.utf8))
assert(malformed.settings?.detail?.accent == "not-a-hex", "malformed hex preserved")

print("PASS: AppThemeManifest — 13/13 assertions")
```

- [ ] **Step 2: Run the script**

Run: `swift scripts/test-app-theme-manifest.swift`
Expected: `PASS: AppThemeManifest — 13/13 assertions`

- [ ] **Step 3: Create the production file**

Create `ClaudeIsland/Models/AppThemeManifest.swift`:

```swift
//
//  AppThemeManifest.swift
//  ClaudeIsland
//
//  Codable types matching the `settings` block of an App Theme plugin's
//  Contents/Resources/plugin.json. Schema is fixed by the existing
//  tempo.bundle and must decode it byte-for-byte.
//

import Foundation

struct AppThemePluginManifest: Decodable {
    let type: String
    let id: String
    let name: String?
    let settings: AppThemeManifestSettings?
}

struct AppThemeManifestSettings: Decodable, Equatable {
    let colorScheme: String?
    let sidebar: AppThemeSidebarColors?
    let detail: AppThemeDetailColors?
    let illustrations: AppThemeIllustrationsManifest?
    let icons: [String: String]?
}

struct AppThemeSidebarColors: Decodable, Equatable {
    let fill: String?
    let text: String?
    let selected: String?
    let selectedText: String?
    let border: String?
}

struct AppThemeDetailColors: Decodable, Equatable {
    let fill: String?
    let text: String?
    let cardFill: String?
    let cardBorder: String?
    let subtle: String?
    let accent: String?
}

struct AppThemeIllustrationsManifest: Decodable, Equatable {
    let files: [String]
    let cycleDuration: Double?
    let transition: String?
}
```

- [ ] **Step 4: Build to verify compilation**

Run: `xcodebuild -project ClaudeIsland.xcodeproj -scheme ClaudeIsland -configuration Debug build -quiet`
Expected: exit 0.

- [ ] **Step 5: Create XCTest scaffolding**

Create `ClaudeIslandTests/AppThemeManifestTests.swift`:

```swift
//
//  AppThemeManifestTests.swift
//  ClaudeIslandTests
//
//  Note: project has no XCTest target. Runtime authority is
//  scripts/test-app-theme-manifest.swift.
//

import XCTest
@testable import ClaudeIsland

final class AppThemeManifestTests: XCTestCase {
    private let decoder = JSONDecoder()

    func testDecodesTempoFullManifest() throws {
        let json = """
        {"type":"theme","id":"tempo","name":"Tempo","settings":{
          "colorScheme":"light",
          "sidebar":{"fill":"#F5F5F3","text":"#1A1A1A","selected":"#1A1A1A","selectedText":"#F5F5F3","border":"#E0E0E0"},
          "detail":{"fill":"#FFFFFF","text":"#1A1A1A","cardFill":"#F0F0EE","cardBorder":"#E0E0E0","subtle":"#8A8A8A","accent":"#34C759"},
          "illustrations":{"files":["a.gif","b.gif"],"cycleDuration":8,"transition":"crossfade"},
          "icons":{"general":"gearshape","appearance":"paintbrush.pointed.fill"}
        }}
        """
        let m = try decoder.decode(AppThemePluginManifest.self, from: Data(json.utf8))
        XCTAssertEqual(m.type, "theme")
        XCTAssertEqual(m.settings?.colorScheme, "light")
        XCTAssertEqual(m.settings?.sidebar?.fill, "#F5F5F3")
        XCTAssertEqual(m.settings?.illustrations?.files.count, 2)
        XCTAssertEqual(m.settings?.icons?["general"], "gearshape")
    }

    func testDecodesNonThemePluginType() throws {
        let json = #"{"type":"buddy","id":"x","settings":null}"#
        let m = try decoder.decode(AppThemePluginManifest.self, from: Data(json.utf8))
        XCTAssertEqual(m.type, "buddy")
        XCTAssertNil(m.settings)
    }

    func testDecodesThemeWithoutSettings() throws {
        let json = #"{"type":"theme","id":"bare"}"#
        let m = try decoder.decode(AppThemePluginManifest.self, from: Data(json.utf8))
        XCTAssertNil(m.settings)
    }

    func testPartialSettingsLeavesOtherSectionsNil() throws {
        let json = #"{"type":"theme","id":"p","settings":{"sidebar":{"fill":"#000000"}}}"#
        let m = try decoder.decode(AppThemePluginManifest.self, from: Data(json.utf8))
        XCTAssertEqual(m.settings?.sidebar?.fill, "#000000")
        XCTAssertNil(m.settings?.sidebar?.text)
        XCTAssertNil(m.settings?.detail)
        XCTAssertNil(m.settings?.icons)
    }

    func testMalformedHexPreservedAtDecode() throws {
        let json = #"{"type":"theme","id":"m","settings":{"detail":{"accent":"not-a-hex"}}}"#
        let m = try decoder.decode(AppThemePluginManifest.self, from: Data(json.utf8))
        XCTAssertEqual(m.settings?.detail?.accent, "not-a-hex")
    }
}
```

- [ ] **Step 6: Commit**

```bash
rtk git add scripts/test-app-theme-manifest.swift ClaudeIsland/Models/AppThemeManifest.swift ClaudeIslandTests/AppThemeManifestTests.swift
rtk git commit -m "feat(app-theme): add AppThemeManifest decoding"
```

---

## Task 3: AppThemePalette — resolved palette type with default

**Files:**
- Create: `ClaudeIsland/Models/AppThemePalette.swift` (types + `.default`; factory comes in Task 4)
- Test: `scripts/test-app-theme-palette-default.swift`
- Scaffold: `ClaudeIslandTests/AppThemePaletteDefaultTests.swift`

- [ ] **Step 1: Verify `Color(hex:)` exists in main**

Run: `rtk git grep -n "Color(hex:" -- 'ClaudeIsland/' | head -5`
Expected: at least one result (used by `ThemeColorToken.color`).

If missing, add this extension at the top of `AppThemePalette.swift` in Step 3:

```swift
private extension Color {
    init(hex: String) {
        let cleaned = hex.hasPrefix("#") ? String(hex.dropFirst()) : hex
        var v: UInt64 = 0
        Scanner(string: cleaned).scanHexInt64(&v)
        let r = Double((v >> 16) & 0xFF) / 255.0
        let g = Double((v >> 8) & 0xFF) / 255.0
        let b = Double(v & 0xFF) / 255.0
        self.init(red: r, green: g, blue: b)
    }
}
```

- [ ] **Step 2: Write the failing test script**

Create `scripts/test-app-theme-palette-default.swift`:

```swift
#!/usr/bin/env swift
import Foundation
import SwiftUI

// === Copy of AppThemePalette types (kept in sync with
//     ClaudeIsland/Models/AppThemePalette.swift) ===

struct AppThemeIllustrations: Equatable {
    let urls: [URL]
    let cycleDuration: TimeInterval
    let transition: AppThemeIllustrationTransition
}

enum AppThemeIllustrationTransition: String, Equatable {
    case crossfade
    case cut
}

struct AppThemePalette: Equatable {
    let colorScheme: ColorScheme?
    let sidebarFill: Color?
    let sidebarText: Color?
    let sidebarSelected: Color?
    let sidebarSelectedText: Color?
    let sidebarBorder: Color?
    let detailFill: Color?
    let detailText: Color?
    let cardFill: Color?
    let cardBorder: Color?
    let subtle: Color?
    let accent: Color?
    let illustrations: AppThemeIllustrations?
    let icons: [String: String]?

    static let `default` = AppThemePalette(
        colorScheme: nil,
        sidebarFill: nil, sidebarText: nil, sidebarSelected: nil,
        sidebarSelectedText: nil, sidebarBorder: nil,
        detailFill: nil, detailText: nil, cardFill: nil,
        cardBorder: nil, subtle: nil, accent: nil,
        illustrations: nil, icons: nil
    )
}

// === Tests ===

func assert(_ cond: Bool, _ label: String) {
    if !cond { print("FAIL: \(label)"); exit(1) }
}

let p = AppThemePalette.default

assert(p.colorScheme == nil, "default colorScheme nil")
assert(p.sidebarFill == nil, "default sidebarFill nil")
assert(p.sidebarText == nil, "default sidebarText nil")
assert(p.sidebarSelected == nil, "default sidebarSelected nil")
assert(p.sidebarSelectedText == nil, "default sidebarSelectedText nil")
assert(p.sidebarBorder == nil, "default sidebarBorder nil")
assert(p.detailFill == nil, "default detailFill nil")
assert(p.detailText == nil, "default detailText nil")
assert(p.cardFill == nil, "default cardFill nil")
assert(p.cardBorder == nil, "default cardBorder nil")
assert(p.subtle == nil, "default subtle nil")
assert(p.accent == nil, "default accent nil")
assert(p.illustrations == nil, "default illustrations nil")
assert(p.icons == nil, "default icons nil")
assert(p == AppThemePalette.default, "default == default")

// Equatable round-trip on illustrations
let i1 = AppThemeIllustrations(urls: [URL(fileURLWithPath: "/x")], cycleDuration: 8, transition: .crossfade)
let i2 = AppThemeIllustrations(urls: [URL(fileURLWithPath: "/x")], cycleDuration: 8, transition: .crossfade)
assert(i1 == i2, "illustrations equatable")

print("PASS: AppThemePalette default — 16/16 assertions")
```

- [ ] **Step 3: Run the script**

Run: `swift scripts/test-app-theme-palette-default.swift`
Expected: `PASS: AppThemePalette default — 16/16 assertions`

- [ ] **Step 4: Create the production file (types + `.default` only — factory in Task 4)**

Create `ClaudeIsland/Models/AppThemePalette.swift`:

```swift
//
//  AppThemePalette.swift
//  ClaudeIsland
//
//  Resolved value type for an active App Theme. Every color role is
//  optional — a manifest may override only a subset, and the consumer
//  falls back to the notch theme for any nil role. The default palette
//  has every role nil, so "no app theme active" matches main's behavior
//  exactly (settings derive entirely from the notch theme).
//

import SwiftUI

struct AppThemePalette: Equatable {
    let colorScheme: ColorScheme?

    // Sidebar (5 roles)
    let sidebarFill: Color?
    let sidebarText: Color?
    let sidebarSelected: Color?
    let sidebarSelectedText: Color?
    let sidebarBorder: Color?

    // Detail (6 roles)
    let detailFill: Color?
    let detailText: Color?
    let cardFill: Color?
    let cardBorder: Color?
    let subtle: Color?
    let accent: Color?

    // Extensions
    let illustrations: AppThemeIllustrations?
    let icons: [String: String]?

    static let `default` = AppThemePalette(
        colorScheme: nil,
        sidebarFill: nil, sidebarText: nil, sidebarSelected: nil,
        sidebarSelectedText: nil, sidebarBorder: nil,
        detailFill: nil, detailText: nil, cardFill: nil,
        cardBorder: nil, subtle: nil, accent: nil,
        illustrations: nil, icons: nil
    )
}

struct AppThemeIllustrations: Equatable {
    let urls: [URL]
    let cycleDuration: TimeInterval
    let transition: AppThemeIllustrationTransition
}

enum AppThemeIllustrationTransition: String, Equatable {
    case crossfade
    case cut
}
```

- [ ] **Step 5: Build to verify compilation**

Run: `xcodebuild -project ClaudeIsland.xcodeproj -scheme ClaudeIsland -configuration Debug build -quiet`
Expected: exit 0.

- [ ] **Step 6: Create XCTest scaffolding**

Create `ClaudeIslandTests/AppThemePaletteDefaultTests.swift`:

```swift
import XCTest
@testable import ClaudeIsland

final class AppThemePaletteDefaultTests: XCTestCase {
    func testDefaultHasAllRolesNil() {
        let p = AppThemePalette.default
        XCTAssertNil(p.colorScheme)
        XCTAssertNil(p.sidebarFill)
        XCTAssertNil(p.sidebarText)
        XCTAssertNil(p.sidebarSelected)
        XCTAssertNil(p.sidebarSelectedText)
        XCTAssertNil(p.sidebarBorder)
        XCTAssertNil(p.detailFill)
        XCTAssertNil(p.detailText)
        XCTAssertNil(p.cardFill)
        XCTAssertNil(p.cardBorder)
        XCTAssertNil(p.subtle)
        XCTAssertNil(p.accent)
        XCTAssertNil(p.illustrations)
        XCTAssertNil(p.icons)
    }

    func testDefaultEquatable() {
        XCTAssertEqual(AppThemePalette.default, AppThemePalette.default)
    }

    func testIllustrationsEquatable() {
        let a = AppThemeIllustrations(urls: [URL(fileURLWithPath: "/x")], cycleDuration: 8, transition: .crossfade)
        let b = AppThemeIllustrations(urls: [URL(fileURLWithPath: "/x")], cycleDuration: 8, transition: .crossfade)
        XCTAssertEqual(a, b)
    }
}
```

- [ ] **Step 7: Commit**

```bash
rtk git add scripts/test-app-theme-palette-default.swift ClaudeIsland/Models/AppThemePalette.swift ClaudeIslandTests/AppThemePaletteDefaultTests.swift
rtk git commit -m "feat(app-theme): add AppThemePalette type with default"
```

---

## Task 4: AppThemePalette factory — resolve manifest into palette

**Files:**
- Modify: `ClaudeIsland/Models/AppThemePalette.swift` (add `from(manifest:bundleResourcesURL:)` factory + helpers)
- Test: `scripts/test-app-theme-palette-factory.swift`
- Scaffold: `ClaudeIslandTests/AppThemePaletteFactoryTests.swift`

- [ ] **Step 1: Write the failing test script**

Create `scripts/test-app-theme-palette-factory.swift`. Inline copies of `AppThemeManifestSettings` and `AppThemePalette` (mirror Tasks 2 & 3), then add the factory inline and assert. Key test cases:

```swift
#!/usr/bin/env swift
import Foundation
import SwiftUI

// === Copies of AppThemeManifest, AppThemePalette, AppThemeIllustrations
//     (kept in sync with ClaudeIsland/Models/{AppThemeManifest,AppThemePalette}.swift) ===
// (Inline both type sets verbatim — same as Tasks 2 and 3.)

// --- (paste AppThemeManifestSettings, AppThemeSidebarColors, AppThemeDetailColors,
//      AppThemeIllustrationsManifest from Task 2 here) ---

// --- (paste AppThemePalette, AppThemeIllustrations, AppThemeIllustrationTransition from Task 3 here) ---

// === Hex parser ===
private extension Color {
    init?(hexValidating hex: String) {
        let cleaned = hex.hasPrefix("#") ? String(hex.dropFirst()) : hex
        guard cleaned.count == 6, cleaned.allSatisfy({ $0.isHexDigit }) else { return nil }
        var v: UInt64 = 0
        Scanner(string: cleaned).scanHexInt64(&v)
        let r = Double((v >> 16) & 0xFF) / 255.0
        let g = Double((v >> 8) & 0xFF) / 255.0
        let b = Double(v & 0xFF) / 255.0
        self.init(red: r, green: g, blue: b)
    }
}

// === Factory ===
extension AppThemePalette {
    static func from(
        manifest: AppThemeManifestSettings,
        bundleResourcesURL: URL?
    ) -> AppThemePalette {
        let scheme: ColorScheme? = {
            switch manifest.colorScheme?.lowercased() {
            case "light": return .light
            case "dark":  return .dark
            default:      return nil
            }
        }()

        let illus: AppThemeIllustrations? = {
            guard let m = manifest.illustrations, let base = bundleResourcesURL else { return nil }
            let urls: [URL] = m.files.compactMap { rel in
                let u = base.appendingPathComponent(rel)
                return FileManager.default.fileExists(atPath: u.path) ? u : nil
            }
            guard !urls.isEmpty else { return nil }
            let transition: AppThemeIllustrationTransition = {
                switch m.transition?.lowercased() {
                case "cut": return .cut
                default:    return .crossfade
                }
            }()
            return AppThemeIllustrations(
                urls: urls,
                cycleDuration: m.cycleDuration ?? 8,
                transition: transition
            )
        }()

        return AppThemePalette(
            colorScheme: scheme,
            sidebarFill:         manifest.sidebar?.fill.flatMap(Color.init(hexValidating:)),
            sidebarText:         manifest.sidebar?.text.flatMap(Color.init(hexValidating:)),
            sidebarSelected:     manifest.sidebar?.selected.flatMap(Color.init(hexValidating:)),
            sidebarSelectedText: manifest.sidebar?.selectedText.flatMap(Color.init(hexValidating:)),
            sidebarBorder:       manifest.sidebar?.border.flatMap(Color.init(hexValidating:)),
            detailFill:          manifest.detail?.fill.flatMap(Color.init(hexValidating:)),
            detailText:          manifest.detail?.text.flatMap(Color.init(hexValidating:)),
            cardFill:            manifest.detail?.cardFill.flatMap(Color.init(hexValidating:)),
            cardBorder:          manifest.detail?.cardBorder.flatMap(Color.init(hexValidating:)),
            subtle:              manifest.detail?.subtle.flatMap(Color.init(hexValidating:)),
            accent:              manifest.detail?.accent.flatMap(Color.init(hexValidating:)),
            illustrations: illus,
            icons: manifest.icons
        )
    }
}

// === Tests ===
func assert(_ cond: Bool, _ label: String) {
    if !cond { print("FAIL: \(label)"); exit(1) }
}

let tmp = FileManager.default.temporaryDirectory.appendingPathComponent("app-theme-test-\(UUID().uuidString)")
try FileManager.default.createDirectory(at: tmp, withIntermediateDirectories: true)
let assets = tmp.appendingPathComponent("assets")
try FileManager.default.createDirectory(at: assets, withIntermediateDirectories: true)
try Data().write(to: assets.appendingPathComponent("illus_1.gif"))
try Data().write(to: assets.appendingPathComponent("illus_2.gif"))
defer { try? FileManager.default.removeItem(at: tmp) }

// Test 1: Full manifest resolves all roles
let fullSettings = AppThemeManifestSettings(
    colorScheme: "light",
    sidebar: AppThemeSidebarColors(fill: "#F5F5F3", text: "#1A1A1A", selected: "#1A1A1A", selectedText: "#F5F5F3", border: "#E0E0E0"),
    detail: AppThemeDetailColors(fill: "#FFFFFF", text: "#1A1A1A", cardFill: "#F0F0EE", cardBorder: "#E0E0E0", subtle: "#8A8A8A", accent: "#34C759"),
    illustrations: AppThemeIllustrationsManifest(files: ["assets/illus_1.gif", "assets/illus_2.gif"], cycleDuration: 8, transition: "crossfade"),
    icons: ["general": "gearshape"]
)
let full = AppThemePalette.from(manifest: fullSettings, bundleResourcesURL: tmp)
assert(full.colorScheme == .light, "full colorScheme=light")
assert(full.sidebarFill != nil, "full sidebarFill non-nil")
assert(full.detailFill != nil, "full detailFill non-nil")
assert(full.accent != nil, "full accent non-nil")
assert(full.illustrations?.urls.count == 2, "full illustrations 2 URLs")
assert(full.illustrations?.cycleDuration == 8, "full cycleDuration")
assert(full.illustrations?.transition == .crossfade, "full transition")
assert(full.icons?["general"] == "gearshape", "full icons general")

// Test 2: Invalid hex → nil for that role; rest of palette intact
let badHex = AppThemeManifestSettings(
    colorScheme: nil,
    sidebar: AppThemeSidebarColors(fill: "not-hex", text: "#000000", selected: nil, selectedText: nil, border: nil),
    detail: nil, illustrations: nil, icons: nil
)
let bad = AppThemePalette.from(manifest: badHex, bundleResourcesURL: nil)
assert(bad.sidebarFill == nil, "invalid hex → sidebarFill nil")
assert(bad.sidebarText != nil, "valid hex → sidebarText non-nil")

// Test 3: Partial manifest leaves untouched roles nil
let partial = AppThemeManifestSettings(
    colorScheme: nil,
    sidebar: AppThemeSidebarColors(fill: "#FFFFFF", text: nil, selected: nil, selectedText: nil, border: nil),
    detail: nil, illustrations: nil, icons: nil
)
let pp = AppThemePalette.from(manifest: partial, bundleResourcesURL: nil)
assert(pp.sidebarFill != nil, "partial sidebarFill set")
assert(pp.sidebarText == nil, "partial sidebarText nil")
assert(pp.detailFill == nil, "partial detailFill nil")
assert(pp.illustrations == nil, "partial illustrations nil")

// Test 4: Missing illustration files filtered
let missingIllus = AppThemeManifestSettings(
    colorScheme: nil, sidebar: nil, detail: nil,
    illustrations: AppThemeIllustrationsManifest(files: ["assets/missing.gif"], cycleDuration: 8, transition: "crossfade"),
    icons: nil
)
let mi = AppThemePalette.from(manifest: missingIllus, bundleResourcesURL: tmp)
assert(mi.illustrations == nil, "all-missing illustrations → nil")

// Test 5: Mixed missing/present — only present URLs kept
let mixedIllus = AppThemeManifestSettings(
    colorScheme: nil, sidebar: nil, detail: nil,
    illustrations: AppThemeIllustrationsManifest(files: ["assets/illus_1.gif", "assets/missing.gif"], cycleDuration: 8, transition: "crossfade"),
    icons: nil
)
let mx = AppThemePalette.from(manifest: mixedIllus, bundleResourcesURL: tmp)
assert(mx.illustrations?.urls.count == 1, "mixed illustrations: 1 URL kept")

// Test 6: Unknown transition string → defaults to crossfade
let unknownTrans = AppThemeManifestSettings(
    colorScheme: nil, sidebar: nil, detail: nil,
    illustrations: AppThemeIllustrationsManifest(files: ["assets/illus_1.gif"], cycleDuration: 5, transition: "wobble"),
    icons: nil
)
let ut = AppThemePalette.from(manifest: unknownTrans, bundleResourcesURL: tmp)
assert(ut.illustrations?.transition == .crossfade, "unknown transition → crossfade")

// Test 7: nil bundleResourcesURL with illustrations → nil
let noBundle = AppThemeManifestSettings(
    colorScheme: nil, sidebar: nil, detail: nil,
    illustrations: AppThemeIllustrationsManifest(files: ["x.gif"], cycleDuration: 8, transition: "crossfade"),
    icons: nil
)
let nb = AppThemePalette.from(manifest: noBundle, bundleResourcesURL: nil)
assert(nb.illustrations == nil, "nil bundleResourcesURL → illustrations nil")

print("PASS: AppThemePalette factory — 18/18 assertions")
```

- [ ] **Step 2: Run the script**

Run: `swift scripts/test-app-theme-palette-factory.swift`
Expected: `PASS: AppThemePalette factory — 18/18 assertions`

- [ ] **Step 3: Modify production file — append factory + hex helper**

Append to `ClaudeIsland/Models/AppThemePalette.swift` (after the existing types):

```swift
// MARK: - Manifest → palette factory

extension AppThemePalette {
    static func from(
        manifest: AppThemeManifestSettings,
        bundleResourcesURL: URL?
    ) -> AppThemePalette {
        let scheme: ColorScheme? = {
            switch manifest.colorScheme?.lowercased() {
            case "light": return .light
            case "dark":  return .dark
            default:      return nil
            }
        }()

        let illustrations: AppThemeIllustrations? = {
            guard let m = manifest.illustrations, let base = bundleResourcesURL else { return nil }
            let urls: [URL] = m.files.compactMap { rel in
                let u = base.appendingPathComponent(rel)
                return FileManager.default.fileExists(atPath: u.path) ? u : nil
            }
            guard !urls.isEmpty else { return nil }
            let transition: AppThemeIllustrationTransition = {
                switch m.transition?.lowercased() {
                case "cut": return .cut
                default:    return .crossfade
                }
            }()
            return AppThemeIllustrations(
                urls: urls,
                cycleDuration: m.cycleDuration ?? 8,
                transition: transition
            )
        }()

        return AppThemePalette(
            colorScheme: scheme,
            sidebarFill:         manifest.sidebar?.fill.flatMap(Color.init(appThemeHex:)),
            sidebarText:         manifest.sidebar?.text.flatMap(Color.init(appThemeHex:)),
            sidebarSelected:     manifest.sidebar?.selected.flatMap(Color.init(appThemeHex:)),
            sidebarSelectedText: manifest.sidebar?.selectedText.flatMap(Color.init(appThemeHex:)),
            sidebarBorder:       manifest.sidebar?.border.flatMap(Color.init(appThemeHex:)),
            detailFill:          manifest.detail?.fill.flatMap(Color.init(appThemeHex:)),
            detailText:          manifest.detail?.text.flatMap(Color.init(appThemeHex:)),
            cardFill:            manifest.detail?.cardFill.flatMap(Color.init(appThemeHex:)),
            cardBorder:          manifest.detail?.cardBorder.flatMap(Color.init(appThemeHex:)),
            subtle:              manifest.detail?.subtle.flatMap(Color.init(appThemeHex:)),
            accent:              manifest.detail?.accent.flatMap(Color.init(appThemeHex:)),
            illustrations: illustrations,
            icons: manifest.icons
        )
    }
}

// Validating hex initializer scoped to this module so we don't collide
// with NotchTheme's `Color(hex:)` (which silently accepts garbage).
private extension Color {
    init?(appThemeHex hex: String) {
        let cleaned = hex.hasPrefix("#") ? String(hex.dropFirst()) : hex
        guard cleaned.count == 6, cleaned.allSatisfy({ $0.isHexDigit }) else { return nil }
        var v: UInt64 = 0
        Scanner(string: cleaned).scanHexInt64(&v)
        let r = Double((v >> 16) & 0xFF) / 255.0
        let g = Double((v >> 8) & 0xFF) / 255.0
        let b = Double(v & 0xFF) / 255.0
        self.init(red: r, green: g, blue: b)
    }
}
```

- [ ] **Step 4: Build to verify compilation**

Run: `xcodebuild -project ClaudeIsland.xcodeproj -scheme ClaudeIsland -configuration Debug build -quiet`
Expected: exit 0.

- [ ] **Step 5: Create XCTest scaffolding**

Create `ClaudeIslandTests/AppThemePaletteFactoryTests.swift` mirroring the script's 7 test groups (full / invalid hex / partial / missing illustrations / mixed illustrations / unknown transition / nil bundle URL). Use the same fixture-directory approach: `FileManager.default.temporaryDirectory.appendingPathComponent("app-theme-test-\(UUID())")` with `defer` cleanup.

- [ ] **Step 6: Commit**

```bash
rtk git add scripts/test-app-theme-palette-factory.swift ClaudeIsland/Models/AppThemePalette.swift ClaudeIslandTests/AppThemePaletteFactoryTests.swift
rtk git commit -m "feat(app-theme): add AppThemePalette manifest factory"
```

---

## Task 5: AppThemeStore + AppThemeDescriptor — active palette + persistence

**Files:**
- Create: `ClaudeIsland/Models/AppThemeDescriptor.swift`
- Create: `ClaudeIsland/Core/AppThemeStore.swift`
- Test: `scripts/test-app-theme-store.swift`
- Scaffold: `ClaudeIslandTests/AppThemeStoreTests.swift`

- [ ] **Step 1: Write the failing test script**

Create `scripts/test-app-theme-store.swift`. Inline copies of `AppThemeID`, `AppThemeManifestSettings` shells, `AppThemePalette` (with `.default` only — no need for the full factory), `AppThemeDescriptor`, and a stub `AppThemeStore` class (use the production code shape below). Key test cases:

1. Initial state with empty UserDefaults: palette = `.default`, activeThemeID = nil.
2. Initial state with persisted ID "tempo": activeThemeID = `AppThemeID("tempo")`, palette still = `.default` (palette gets resolved on activate, not on read).
3. `activate(descriptor:)` with built-in descriptor (manifest = nil) → palette = `.default`, activeThemeID = descriptor.id, UserDefaults set.
4. `activate(descriptor:)` with plugin descriptor (manifest set) → palette resolved from manifest, activeThemeID set, UserDefaults set.
5. `reset()` → palette = `.default`, activeThemeID = nil, UserDefaults removed.
6. Two activations replace cleanly (second wins, no leaked state).

Use a per-test isolated `UserDefaults(suiteName: "AppThemeStoreTest-\(UUID)")!` and `removeSuite(named:)` cleanup.

- [ ] **Step 2: Run the script**

Run: `swift scripts/test-app-theme-store.swift`
Expected: `PASS: AppThemeStore — N/N assertions`

- [ ] **Step 3: Create production files**

Create `ClaudeIsland/Models/AppThemeDescriptor.swift`:

```swift
//
//  AppThemeDescriptor.swift
//  ClaudeIsland
//
//  An entry in AppThemeRegistry.availableThemes — represents one selectable
//  theme. Built-in default has manifest = nil; plugin themes carry their
//  decoded manifest and bundle resources URL so the store can resolve the
//  palette on activation.
//

import Foundation

struct AppThemeDescriptor: Equatable, Identifiable {
    let id: AppThemeID
    let displayName: String
    let manifest: AppThemeManifestSettings?
    let bundleResourcesURL: URL?
    let source: Source

    enum Source: Equatable {
        case builtIn
        case plugin(pluginID: String)
    }
}
```

Create `ClaudeIsland/Core/AppThemeStore.swift`:

```swift
//
//  AppThemeStore.swift
//  ClaudeIsland
//
//  Holds the active App Theme palette and persists the selected theme ID.
//  Independent of NotchCustomizationStore — the App Theme picker drives
//  the Settings window only; the notch picker drives the notch.
//

import Combine
import Foundation
import SwiftUI

@MainActor
final class AppThemeStore: ObservableObject {
    static let shared = AppThemeStore()

    @Published private(set) var palette: AppThemePalette = .default
    @Published private(set) var activeThemeID: AppThemeID?

    private let defaults: UserDefaults
    private static let activeIDKey = "AppTheme.activeThemeID"

    init(defaults: UserDefaults = .standard) {
        self.defaults = defaults
        if let raw = defaults.string(forKey: Self.activeIDKey) {
            self.activeThemeID = AppThemeID(rawValue: raw)
        }
        // palette stays at `.default` until a descriptor activates — the
        // bundle resources may not be reachable yet at init time.
    }

    /// Activate a theme. For built-in descriptors (manifest = nil), the
    /// palette resets to `.default`. For plugin descriptors, the palette
    /// is resolved from the manifest using the plugin's resources URL.
    func activate(descriptor: AppThemeDescriptor) {
        if let manifest = descriptor.manifest {
            palette = AppThemePalette.from(
                manifest: manifest,
                bundleResourcesURL: descriptor.bundleResourcesURL
            )
        } else {
            palette = .default
        }
        activeThemeID = descriptor.id
        defaults.set(descriptor.id.rawValue, forKey: Self.activeIDKey)
    }

    /// Revert to the default palette and clear persistence.
    func reset() {
        palette = .default
        activeThemeID = nil
        defaults.removeObject(forKey: Self.activeIDKey)
    }
}
```

- [ ] **Step 4: Build to verify compilation**

Run: `xcodebuild -project ClaudeIsland.xcodeproj -scheme ClaudeIsland -configuration Debug build -quiet`
Expected: exit 0.

- [ ] **Step 5: Create XCTest scaffolding**

Create `ClaudeIslandTests/AppThemeStoreTests.swift` covering the same 6 cases. Use `UserDefaults(suiteName:)` per test for isolation, with `tearDown` cleanup.

- [ ] **Step 6: Commit**

```bash
rtk git add scripts/test-app-theme-store.swift ClaudeIsland/Models/AppThemeDescriptor.swift ClaudeIsland/Core/AppThemeStore.swift ClaudeIslandTests/AppThemeStoreTests.swift
rtk git commit -m "feat(app-theme): add AppThemeDescriptor and AppThemeStore"
```

---

## Task 6: AppThemeRegistry — built-in default only

**Files:**
- Create: `ClaudeIsland/Models/AppThemeRegistry.swift`
- Test: `scripts/test-app-theme-registry-builtin.swift`
- Scaffold: `ClaudeIslandTests/AppThemeRegistryBuiltInTests.swift`

- [ ] **Step 1: Write the failing test script**

Inline a minimal `AppThemeRegistry` with built-in default only (no plugin discovery, no Combine subscription yet). Tests:

1. `availableThemes` contains exactly `[builtInDefault]`.
2. `descriptor(for: .default)` returns the built-in default.
3. `descriptor(for: AppThemeID("tempo"))` returns built-in default (fallback).
4. `displayName(for: .default)` == "Default".

- [ ] **Step 2: Run the script**

Run: `swift scripts/test-app-theme-registry-builtin.swift`
Expected: `PASS: AppThemeRegistry built-in — 4/4 assertions`

- [ ] **Step 3: Create production file (built-in only — discovery + reconciliation in Tasks 7-8)**

Create `ClaudeIsland/Models/AppThemeRegistry.swift`:

```swift
//
//  AppThemeRegistry.swift
//  ClaudeIsland
//
//  Discovers App Theme descriptors: a hard-coded built-in default plus
//  any plugin-provided themes (loaded in Task 7 via NativePluginManager
//  Combine subscription). Mirrors main's ThemeRegistry shape.
//

import Combine
import Foundation

@MainActor
final class AppThemeRegistry: ObservableObject {
    static let shared = AppThemeRegistry()

    @Published private(set) var availableThemes: [AppThemeDescriptor]

    private let store: AppThemeStore
    private var cancellables: Set<AnyCancellable> = []

    init(store: AppThemeStore = .shared) {
        self.store = store
        self.availableThemes = Self.builtInDescriptors
    }

    var themeIDs: [AppThemeID] { availableThemes.map(\.id) }

    func descriptor(for id: AppThemeID) -> AppThemeDescriptor {
        availableThemes.first(where: { $0.id == id }) ?? Self.builtInDescriptors[0]
    }

    func displayName(for id: AppThemeID) -> String {
        descriptor(for: id).displayName
    }

    static let builtInDescriptors: [AppThemeDescriptor] = [
        AppThemeDescriptor(
            id: .default,
            displayName: "Default",
            manifest: nil,
            bundleResourcesURL: nil,
            source: .builtIn
        )
    ]
}
```

- [ ] **Step 4: Build to verify compilation**

Run: `xcodebuild -project ClaudeIsland.xcodeproj -scheme ClaudeIsland -configuration Debug build -quiet`
Expected: exit 0.

- [ ] **Step 5: Create XCTest scaffolding**

Create `ClaudeIslandTests/AppThemeRegistryBuiltInTests.swift` covering the same 4 cases.

- [ ] **Step 6: Commit**

```bash
rtk git add scripts/test-app-theme-registry-builtin.swift ClaudeIsland/Models/AppThemeRegistry.swift ClaudeIslandTests/AppThemeRegistryBuiltInTests.swift
rtk git commit -m "feat(app-theme): add AppThemeRegistry with built-in default"
```

---

## Task 7: AppThemeRegistry — plugin discovery via bundles

**Files:**
- Modify: `ClaudeIsland/Models/AppThemeRegistry.swift` (add `loadAll(pluginBundles:)` + `decodeThemeManifest(in:)` helper)
- Test: `scripts/test-app-theme-registry-discovery.swift`
- Scaffold: `ClaudeIslandTests/AppThemeRegistryDiscoveryTests.swift`

- [ ] **Step 1: Write the failing test script**

The script needs fake plugin bundles. Strategy: build them at runtime using `FileManager` — create a temp dir, write a `Contents/Resources/plugin.json` inside, instantiate `Bundle(url:)` pointing at it. Tests:

1. Empty `pluginBundles: []` → `availableThemes == [builtInDefault]`.
2. One theme bundle → `availableThemes == [builtInDefault, themeFromBundle]`, manifest decoded, source = `.plugin(...)`.
3. One non-theme bundle (`type: "buddy"`) → ignored, only built-in remains.
4. One theme bundle with missing `settings` → ignored.
5. Two theme bundles with same `id` → first kept, second deduped.
6. Bundle with malformed JSON → skipped, no crash.
7. Bundle with no `plugin.json` → skipped.
8. `Bundle.main` in the list → skipped (the host app, not a plugin).

Helper to build a fake bundle:

```swift
func makeFakeBundle(at name: String, json: String) throws -> Bundle {
    let dir = FileManager.default.temporaryDirectory
        .appendingPathComponent("app-theme-bundle-\(name)-\(UUID().uuidString).bundle")
    let resources = dir.appendingPathComponent("Contents/Resources")
    try FileManager.default.createDirectory(at: resources, withIntermediateDirectories: true)
    try Data(json.utf8).write(to: resources.appendingPathComponent("plugin.json"))
    return Bundle(url: dir)!
}
```

- [ ] **Step 2: Run the script**

Run: `swift scripts/test-app-theme-registry-discovery.swift`
Expected: `PASS: AppThemeRegistry discovery — 8/8 assertions`

- [ ] **Step 3: Modify production file — append `loadAll` + helper**

Append to `ClaudeIsland/Models/AppThemeRegistry.swift` (inside the existing class):

```swift
// MARK: - Plugin discovery

/// Public entry point. Pass `nil` to read live state from
/// `NativePluginManager.shared.loadedPlugins`; pass a list to inject for
/// tests. (Reconciliation with the store is added in Task 8.)
func loadAll(pluginBundles: [Bundle]? = nil) {
    var descriptors = Self.builtInDescriptors
    var seen = Set(descriptors.map(\.id))
    let bundles = pluginBundles ?? NativePluginManager.shared.loadedPlugins.map(\.bundle)

    for bundle in bundles where bundle != Bundle.main {
        guard let descriptor = decodeThemeDescriptor(from: bundle) else { continue }
        guard !seen.contains(descriptor.id) else { continue }
        descriptors.append(descriptor)
        seen.insert(descriptor.id)
    }

    availableThemes = descriptors
}

private func decodeThemeDescriptor(from bundle: Bundle) -> AppThemeDescriptor? {
    guard let url = bundle.url(forResource: "plugin", withExtension: "json"),
          let data = try? Data(contentsOf: url),
          let manifest = try? JSONDecoder().decode(AppThemePluginManifest.self, from: data),
          manifest.type == "theme",
          let settings = manifest.settings
    else { return nil }

    return AppThemeDescriptor(
        id: AppThemeID(rawValue: manifest.id),
        displayName: manifest.name ?? manifest.id,
        manifest: settings,
        bundleResourcesURL: bundle.resourceURL,
        source: .plugin(pluginID: manifest.id)
    )
}
```

- [ ] **Step 4: Build to verify compilation**

Run: `xcodebuild -project ClaudeIsland.xcodeproj -scheme ClaudeIsland -configuration Debug build -quiet`
Expected: exit 0.

- [ ] **Step 5: Create XCTest scaffolding**

Create `ClaudeIslandTests/AppThemeRegistryDiscoveryTests.swift` covering the same 8 cases.

- [ ] **Step 6: Commit**

```bash
rtk git add scripts/test-app-theme-registry-discovery.swift ClaudeIsland/Models/AppThemeRegistry.swift ClaudeIslandTests/AppThemeRegistryDiscoveryTests.swift
rtk git commit -m "feat(app-theme): plugin theme discovery in AppThemeRegistry"
```

---

## Task 8: AppThemeRegistry — store reconciliation + Combine subscription

**Files:**
- Modify: `ClaudeIsland/Models/AppThemeRegistry.swift` (add reconciliation logic + Combine subscription in `init`)
- Test: `scripts/test-app-theme-registry-reconcile.swift`
- Scaffold: `ClaudeIslandTests/AppThemeRegistryReconcileTests.swift`

- [ ] **Step 1: Write the failing test script**

Tests:

1. Cold start with persisted "tempo" but no bundles yet — `loadAll(pluginBundles: [])` does NOT reset (`hasSeenPlugins == false`).
2. Cold start with persisted "tempo" — `loadAll(pluginBundles: [tempoBundle])` activates "tempo" (palette resolved). `hasSeenPlugins` becomes true.
3. After plugin uninstall — `loadAll(pluginBundles: [])` with `hasSeenPlugins == true` calls `store.reset()`.
4. Re-install — `loadAll(pluginBundles: [tempoBundle])` re-activates.
5. Picking a built-in (`store.activate(descriptor: builtInDefault)`) then `loadAll([])` — store stays active (built-in always available).
6. Active theme already correct — calling `loadAll([tempoBundle])` again is idempotent (palette doesn't change).

- [ ] **Step 2: Run the script**

Run: `swift scripts/test-app-theme-registry-reconcile.swift`
Expected: `PASS: AppThemeRegistry reconcile — 6/6 assertions`

- [ ] **Step 3: Modify production file**

Update `ClaudeIsland/Models/AppThemeRegistry.swift`:

In the existing `init`, after seeding `availableThemes = Self.builtInDescriptors`, add the Combine subscription. Replace the body of `loadAll` to call `reconcile` after rebuilding. Add private flag and `reconcile` helper:

```swift
private var hasSeenPlugins = false

init(store: AppThemeStore = .shared) {
    self.store = store
    self.availableThemes = Self.builtInDescriptors

    NativePluginManager.shared.$loadedPlugins
        .dropFirst()  // skip the initial empty emission
        .sink { [weak self] _ in
            self?.loadAll()
        }
        .store(in: &cancellables)
}

func loadAll(pluginBundles: [Bundle]? = nil) {
    var descriptors = Self.builtInDescriptors
    var seen = Set(descriptors.map(\.id))
    let bundles = pluginBundles ?? NativePluginManager.shared.loadedPlugins.map(\.bundle)

    for bundle in bundles where bundle != Bundle.main {
        guard let descriptor = decodeThemeDescriptor(from: bundle) else { continue }
        guard !seen.contains(descriptor.id) else { continue }
        descriptors.append(descriptor)
        seen.insert(descriptor.id)
    }

    availableThemes = descriptors

    if !bundles.isEmpty {
        hasSeenPlugins = true
    }
    reconcile()
}

/// After every rebuild, sync the store with the new available list.
/// - If the persisted active ID is found, re-activate (refreshes the palette
///   in case the bundle just became reachable).
/// - If it's missing AND we've seen at least one plugin emission, reset.
///   (We don't reset on the cold-start empty list, because the plugin may
///   still be in flight.)
private func reconcile() {
    guard let active = store.activeThemeID else { return }
    if let descriptor = availableThemes.first(where: { $0.id == active }) {
        store.activate(descriptor: descriptor)
    } else if hasSeenPlugins {
        store.reset()
    }
}
```

- [ ] **Step 4: Build to verify compilation**

Run: `xcodebuild -project ClaudeIsland.xcodeproj -scheme ClaudeIsland -configuration Debug build -quiet`
Expected: exit 0.

- [ ] **Step 5: Create XCTest scaffolding**

Create `ClaudeIslandTests/AppThemeRegistryReconcileTests.swift` covering the same 6 cases. Inject a per-test `AppThemeStore(defaults: UserDefaults(suiteName: ...))` into the registry instead of using the singleton.

- [ ] **Step 6: Commit**

```bash
rtk git add scripts/test-app-theme-registry-reconcile.swift ClaudeIsland/Models/AppThemeRegistry.swift ClaudeIslandTests/AppThemeRegistryReconcileTests.swift
rtk git commit -m "feat(app-theme): registry reconciles store with available themes"
```

---

## Task 9: End-to-end tempo bundle fixture script

**Files:**
- Create: `scripts/test-app-theme-tempo-fixture.swift`

- [ ] **Step 1: Write the script**

This is the only script that loads the actual tempo bundle from disk (no inline copy of the source — it imports nothing because it's a self-contained verification harness). Path defaults to `~/Downloads/tmp/island/tempo-theme/tempo.bundle` and accepts `argv[1]` override.

```swift
#!/usr/bin/env swift
import Foundation

let defaultPath = ("~/Downloads/tmp/island/tempo-theme/tempo.bundle" as NSString).expandingTildeInPath
let bundlePath = CommandLine.arguments.count > 1 ? CommandLine.arguments[1] : defaultPath
let bundleURL = URL(fileURLWithPath: bundlePath)

guard FileManager.default.fileExists(atPath: bundlePath) else {
    print("FAIL: tempo bundle not found at \(bundlePath)")
    print("Pass an alternate path as argv[1].")
    exit(1)
}

let manifestURL = bundleURL.appendingPathComponent("Contents/Resources/plugin.json")
guard let data = try? Data(contentsOf: manifestURL) else {
    print("FAIL: cannot read plugin.json at \(manifestURL.path)")
    exit(1)
}

// === Inline manifest schema (kept in sync with
//     ClaudeIsland/Models/AppThemeManifest.swift) ===

struct ManifestRoot: Decodable {
    let type: String
    let id: String
    let settings: Settings?
}
struct Settings: Decodable {
    let colorScheme: String?
    let sidebar: Sidebar?
    let detail: Detail?
    let illustrations: Illustrations?
    let icons: [String: String]?
}
struct Sidebar: Decodable {
    let fill: String?; let text: String?; let selected: String?; let selectedText: String?; let border: String?
}
struct Detail: Decodable {
    let fill: String?; let text: String?; let cardFill: String?; let cardBorder: String?; let subtle: String?; let accent: String?
}
struct Illustrations: Decodable {
    let files: [String]; let cycleDuration: Double?; let transition: String?
}

// === Verify ===

func assert(_ cond: Bool, _ label: String) {
    if !cond { print("FAIL: \(label)"); exit(1) }
}

let m = try JSONDecoder().decode(ManifestRoot.self, from: data)
assert(m.type == "theme", "type == theme")
assert(m.id == "tempo", "id == tempo")
let s = m.settings!
assert(s.colorScheme == "light", "colorScheme == light")

assert(s.sidebar?.fill != nil, "sidebar.fill present")
assert(s.sidebar?.text != nil, "sidebar.text present")
assert(s.sidebar?.selected != nil, "sidebar.selected present")
assert(s.sidebar?.selectedText != nil, "sidebar.selectedText present")
assert(s.sidebar?.border != nil, "sidebar.border present")

assert(s.detail?.fill != nil, "detail.fill present")
assert(s.detail?.text != nil, "detail.text present")
assert(s.detail?.cardFill != nil, "detail.cardFill present")
assert(s.detail?.cardBorder != nil, "detail.cardBorder present")
assert(s.detail?.subtle != nil, "detail.subtle present")
assert(s.detail?.accent != nil, "detail.accent present")

let illus = s.illustrations!
assert(illus.files.count == 3, "3 illustration files declared")
let resourcesDir = bundleURL.appendingPathComponent("Contents/Resources")
for relative in illus.files {
    let url = resourcesDir.appendingPathComponent(relative)
    assert(FileManager.default.fileExists(atPath: url.path), "illustration exists: \(relative)")
}
assert(illus.cycleDuration == 8, "cycleDuration == 8")
assert(illus.transition == "crossfade", "transition == crossfade")

let icons = s.icons!
assert(icons["general"] == "gearshape", "icon general")
assert(icons["appearance"] == "paintbrush.pointed.fill", "icon appearance")
assert(icons["notifications"] == "bell.fill", "icon notifications")
assert(icons["plugins"] == "square.stack.3d.up.fill", "icon plugins")

print("PASS: tempo fixture — 22/22 assertions (\(bundlePath))")
```

- [ ] **Step 2: Run the script**

Run: `swift scripts/test-app-theme-tempo-fixture.swift`
Expected: `PASS: tempo fixture — 22/22 assertions (...)`

- [ ] **Step 3: Commit**

```bash
rtk git add scripts/test-app-theme-tempo-fixture.swift
rtk git commit -m "test(app-theme): end-to-end tempo bundle fixture verification"
```

---

## Task 10: AppThemeReader modifier + AppThemePickerCard view

**Files:**
- Create: `ClaudeIsland/UI/Helpers/AppThemeReader.swift`
- Create: `ClaudeIsland/UI/Views/AppThemePickerCard.swift`

(No standalone script — SwiftUI views are not amenable to script-based testing in this codebase. Visual verification in the smoke test in Task 14.)

- [ ] **Step 1: Create the modifier helper**

Create `ClaudeIsland/UI/Helpers/AppThemeReader.swift`:

```swift
//
//  AppThemeReader.swift
//  ClaudeIsland
//
//  Tiny convenience modifier — injects AppThemeStore.shared into the view
//  hierarchy as an @EnvironmentObject and keeps it observed.
//

import SwiftUI

extension View {
    /// Inject AppThemeStore.shared so descendants can read the active palette
    /// via @EnvironmentObject AppThemeStore. Apply at the settings-window
    /// root.
    func appThemed() -> some View {
        environmentObject(AppThemeStore.shared)
    }
}
```

- [ ] **Step 2: Create the picker card**

Create `ClaudeIsland/UI/Views/AppThemePickerCard.swift`:

```swift
//
//  AppThemePickerCard.swift
//  ClaudeIsland
//
//  Picker card for the App Theme system — sits above the notch
//  customization card on the Appearance tab in SystemSettingsView.
//  Iterates AppThemeRegistry.shared.availableThemes and lets the user
//  pick one. Selection is stored in AppThemeStore.shared.
//

import SwiftUI

struct AppThemePickerCard: View {
    @ObservedObject private var registry = AppThemeRegistry.shared
    @ObservedObject private var store = AppThemeStore.shared

    private let columns = [
        GridItem(.flexible(), spacing: 8),
        GridItem(.flexible(), spacing: 8),
    ]

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("App Theme")
                .font(.system(size: 12, weight: .semibold))
            Text("Restyles the Settings window. Independent of the notch theme.")
                .font(.system(size: 11))
                .foregroundColor(.secondary)

            LazyVGrid(columns: columns, spacing: 8) {
                ForEach(registry.availableThemes) { descriptor in
                    AppThemePreviewTile(
                        descriptor: descriptor,
                        isSelected: store.activeThemeID == descriptor.id
                    ) {
                        store.activate(descriptor: descriptor)
                    }
                }
            }
        }
    }
}

private struct AppThemePreviewTile: View {
    let descriptor: AppThemeDescriptor
    let isSelected: Bool
    let onTap: () -> Void

    var body: some View {
        Button(action: onTap) {
            VStack(spacing: 6) {
                ZStack {
                    RoundedRectangle(cornerRadius: 8)
                        .fill(previewBackground)
                    HStack(spacing: 4) {
                        RoundedRectangle(cornerRadius: 2).fill(previewSidebar).frame(width: 10, height: 24)
                        RoundedRectangle(cornerRadius: 2).fill(previewAccent).frame(width: 24, height: 24)
                    }
                }
                .frame(height: 36)
                .overlay(
                    RoundedRectangle(cornerRadius: 8)
                        .strokeBorder(isSelected ? Color.accentColor : Color.black.opacity(0.12), lineWidth: isSelected ? 2 : 0.5)
                )

                Text(descriptor.displayName)
                    .font(.system(size: 11, weight: isSelected ? .semibold : .regular))
                    .lineLimit(1)
            }
            .padding(6)
        }
        .buttonStyle(.plain)
    }

    /// Mini preview colors. For built-in default we render neutral system
    /// surfaces; for plugin themes we sample the manifest directly so the
    /// tile shows what the theme actually looks like.
    private var previewBackground: Color {
        guard let manifest = descriptor.manifest,
              let hex = manifest.detail?.fill,
              let c = Color(appThemeHexFallback: hex) else {
            return Color(NSColor.windowBackgroundColor)
        }
        return c
    }
    private var previewSidebar: Color {
        guard let manifest = descriptor.manifest,
              let hex = manifest.sidebar?.fill,
              let c = Color(appThemeHexFallback: hex) else {
            return Color(NSColor.controlBackgroundColor)
        }
        return c
    }
    private var previewAccent: Color {
        guard let manifest = descriptor.manifest,
              let hex = manifest.detail?.accent,
              let c = Color(appThemeHexFallback: hex) else {
            return Color.accentColor
        }
        return c
    }
}

private extension Color {
    init?(appThemeHexFallback hex: String) {
        let cleaned = hex.hasPrefix("#") ? String(hex.dropFirst()) : hex
        guard cleaned.count == 6, cleaned.allSatisfy({ $0.isHexDigit }) else { return nil }
        var v: UInt64 = 0
        Scanner(string: cleaned).scanHexInt64(&v)
        self.init(
            red:   Double((v >> 16) & 0xFF) / 255.0,
            green: Double((v >> 8) & 0xFF) / 255.0,
            blue:  Double(v & 0xFF) / 255.0
        )
    }
}
```

- [ ] **Step 3: Build to verify compilation**

Run: `xcodebuild -project ClaudeIsland.xcodeproj -scheme ClaudeIsland -configuration Debug build -quiet`
Expected: exit 0.

- [ ] **Step 4: Commit**

```bash
rtk git add ClaudeIsland/UI/Helpers/AppThemeReader.swift ClaudeIsland/UI/Views/AppThemePickerCard.swift
rtk git commit -m "feat(app-theme): add AppThemeReader modifier and picker card view"
```

---

## Task 11: SystemSettingsView — `Theme` enum reads from App palette first

**Files:**
- Modify: `ClaudeIsland/UI/Views/SystemSettingsView.swift` (the `Theme` static enum at line 232 in `main`)

(No standalone script — purely an integration edit. Smoke test in Task 14.)

- [ ] **Step 1: Verify the current Theme enum location**

Run: `rtk git grep -n "^enum Theme {" -- ClaudeIsland/UI/Views/SystemSettingsView.swift`
Expected: a single hit around line 232.

- [ ] **Step 2: Modify the Theme enum**

Open `ClaudeIsland/UI/Views/SystemSettingsView.swift`. Replace the body of the `enum Theme { … }` block (the static `var` declarations) so each role first reads from `AppThemeStore.shared.palette` and falls back to the existing `resolver.X` derivation. Insert a small private helper at the top of the enum:

```swift
enum Theme {
    private static var resolver: ThemeResolver { settingsTheme() }
    private static var appPalette: AppThemePalette { AppThemeStore.shared.palette }

    // Sidebar — App Theme overrides notch derivation when present.
    static var sidebarFill: Color {
        appPalette.sidebarFill ?? resolver.overlay.opacity(resolver.isRetroArcade ? 0.92 : 0.94)
    }
    static var sidebarText: Color {
        appPalette.sidebarText ?? resolver.primaryText
    }
    static var sidebarActiveFill: Color {
        appPalette.sidebarSelected ?? resolver.primaryText.opacity(resolver.isRetroArcade ? 0.12 : 0.08)
    }
    static var sidebarHoverFill: Color {
        // No App Theme role — pure notch derivation.
        resolver.primaryText.opacity(resolver.isRetroArcade ? 0.08 : 0.04)
    }
    static var sidebarBorder: Color {
        appPalette.sidebarBorder ?? resolver.border.opacity(resolver.isRetroArcade ? 0.3 : 0.16)
    }

    // Detail
    static var detailFill: Color { appPalette.detailFill ?? resolver.background }
    static var detailText: Color { appPalette.detailText ?? resolver.primaryText }
    static var border: Color { appPalette.cardBorder ?? resolver.border }

    static var cardFill: Color {
        appPalette.cardFill ?? resolver.overlay.opacity(resolver.isRetroArcade ? 0.18 : 0.32)
    }
    static var cardBorder: Color {
        appPalette.cardBorder ?? resolver.border.opacity(resolver.isRetroArcade ? 0.32 : 0.22)
    }
    static var rowDivider: Color { resolver.border.opacity(resolver.isRetroArcade ? 0.22 : 0.16) }
    static var subtle: Color { appPalette.subtle ?? resolver.mutedText }
    static var subtleStrong: Color { resolver.secondaryText }

    static var accent: Color { appPalette.accent ?? resolver.doneColor }

    // Roles with no App Theme override (pure notch derivation — kept verbatim from main):
    static var controlFill: Color { resolver.overlay.opacity(resolver.isRetroArcade ? 0.14 : 0.18) }
    static var controlBorder: Color { resolver.border.opacity(resolver.isRetroArcade ? 0.28 : 0.22) }
    static var iconTileFill: Color { resolver.overlay.opacity(resolver.isRetroArcade ? 0.16 : 0.18) }
    static var iconTileBorder: Color { resolver.border.opacity(resolver.isRetroArcade ? 0.28 : 0.22) }
    static var fieldFill: Color { resolver.overlay.opacity(resolver.isRetroArcade ? 0.22 : 0.44) }
    static var fieldBorder: Color { resolver.border.opacity(resolver.isRetroArcade ? 0.34 : 0.28) }
    static var placeholder: Color { resolver.mutedText.opacity(0.9) }
    static var shadow: Color { Color.black.opacity(resolver.isRetroArcade ? 0.22 : 0.5) }
    static var destructiveText: Color { resolver.errorColor }
    static var destructiveFill: Color { resolver.errorColor.opacity(0.1) }
    static var destructiveBorder: Color { resolver.errorColor.opacity(0.18) }
    static var success: Color { resolver.doneColor }
    static var warning: Color { resolver.needsYouColor }
    static var error: Color { resolver.errorColor }
    static var neutralDot: Color { resolver.mutedText.opacity(0.5) }
    static var backgroundInk: Color { resolver.inverseText }
    static var titlebarGlyph: Color { resolver.inverseText.opacity(0.6) }
    static var knobShadow: Color { Color.black.opacity(resolver.isRetroArcade ? 0.18 : 0.35) }
    static var toggleActiveBorder: Color { resolver.inverseText.opacity(0.25) }

    // Real macOS traffic-light colors.
    static let tlRed = Color(red: 1.00, green: 0.373, blue: 0.341)
    static let tlYellow = Color(red: 0.996, green: 0.737, blue: 0.180)
    static let tlGreen = Color(red: 0.157, green: 0.784, blue: 0.251)
    static let tlStroke = Color.black.opacity(0.25)
}
```

- [ ] **Step 3: Add `AppThemeStore` observation to the settings root**

Find the existing `SystemSettingsContentView` (around line 290 in `main`, where `NotchCustomizationStore` is observed via `@ObservedObject`). Add a sibling line:

```swift
@ObservedObject private var appThemeStore = AppThemeStore.shared
```

This forces a re-render of the entire settings tree on palette swap.

- [ ] **Step 4: Apply `colorScheme` override at settings root**

In the same view's `body`, find the outermost view and add `.preferredColorScheme(...)`:

```swift
.preferredColorScheme(appThemeStore.palette.colorScheme)
```

(SwiftUI accepts a `nil` here as "no override" — falls back to system mode. So this works whether or not an app theme is active.)

- [ ] **Step 5: Build to verify compilation**

Run: `xcodebuild -project ClaudeIsland.xcodeproj -scheme ClaudeIsland -configuration Debug build -quiet`
Expected: exit 0.

- [ ] **Step 6: Commit**

```bash
rtk git add ClaudeIsland/UI/Views/SystemSettingsView.swift
rtk git commit -m "feat(app-theme): wire AppThemeStore into SystemSettingsView Theme enum"
```

---

## Task 12: SystemSettingsView — insert AppThemePickerCard above notch customization

**Files:**
- Modify: `ClaudeIsland/UI/Views/SystemSettingsView.swift` (the `AppearanceTab` view body)

- [ ] **Step 1: Locate the AppearanceTab body**

Run: `rtk git grep -n "private struct AppearanceTab" -- ClaudeIsland/UI/Views/SystemSettingsView.swift`
Note the line. Inspect the body — it currently has a `SettingsCard` containing the notch customization, plus a screen picker card and others.

- [ ] **Step 2: Insert the App Theme card as the first child**

In `AppearanceTab.body`, prepend a new `SettingsCard` wrapper around `AppThemePickerCard()`:

```swift
private struct AppearanceTab: View {
    var body: some View {
        SettingsTabContent {
            SettingsCard {
                AppThemePickerCard()
            }

            // Existing notch customization card (unchanged):
            SettingsCard(title: L10n.notchCustomization) {
                NotchCustomizationSettingsView()
            }

            // ... rest of the existing body, unchanged ...
        }
    }
}
```

(Use whatever the actual existing card title/wrapping pattern is — read the file before editing. The shape above mirrors `NotificationsTab`.)

- [ ] **Step 3: Build to verify compilation**

Run: `xcodebuild -project ClaudeIsland.xcodeproj -scheme ClaudeIsland -configuration Debug build -quiet`
Expected: exit 0.

- [ ] **Step 4: Commit**

```bash
rtk git add ClaudeIsland/UI/Views/SystemSettingsView.swift
rtk git commit -m "feat(app-theme): insert App Theme picker card in AppearanceTab"
```

---

## Task 13: AppDelegate — kick off registry + apply env

**Files:**
- Modify: `ClaudeIsland/App/AppDelegate.swift`

- [ ] **Step 1: Inspect current AppDelegate**

Run: `rtk git show main:ClaudeIsland/App/AppDelegate.swift | head -80`

- [ ] **Step 2: Add registry initialization in `applicationDidFinishLaunching`**

Find the body of `applicationDidFinishLaunching` (or the equivalent launch hook). At a sensible point AFTER `NativePluginManager.shared` has been touched (so its Combine subject has emitted), add:

```swift
// Trigger the App Theme registry's init so its Combine subscription
// to NativePluginManager.$loadedPlugins fires on subsequent emissions.
// (Built-in default is available immediately; plugin themes appear
// once the manager finishes scanning bundles.)
_ = AppThemeRegistry.shared
```

- [ ] **Step 3: Apply `appThemed()` modifier at the settings window root**

Find where the settings window's hosting view / `NSHostingController` is constructed (search for `SystemSettingsView` instantiation). Add `.appThemed()` to the SwiftUI root:

```swift
let root = SystemSettingsView(...)
    .appThemed()
```

If there are multiple constructions (e.g., main settings + a secondary path), apply consistently.

- [ ] **Step 4: Build to verify compilation**

Run: `xcodebuild -project ClaudeIsland.xcodeproj -scheme ClaudeIsland -configuration Debug build -quiet`
Expected: exit 0.

- [ ] **Step 5: Commit**

```bash
rtk git add ClaudeIsland/App/AppDelegate.swift
rtk git commit -m "feat(app-theme): wire AppThemeRegistry into AppDelegate launch"
```

---

## Task 14: Smoke test — install tempo, verify end-to-end

**Files:**
- None (manual verification + commit a smoke-test note in the spec if behavior diverges)

- [ ] **Step 1: Build and run the app**

Run: `xcodebuild -project ClaudeIsland.xcodeproj -scheme ClaudeIsland -configuration Debug build -quiet`
Expected: exit 0.

Launch the built app from DerivedData (`open ~/Library/Developer/Xcode/DerivedData/ClaudeIsland-*/Build/Products/Debug/Mio\ Island.app`).

- [ ] **Step 2: Open Settings → Appearance — verify built-in default appears alone**

- App Theme card sits above the Notch Customization card.
- Picker shows one tile: "Default", marked selected.
- Selecting Default does nothing visible (palette = `.default` == no override).

- [ ] **Step 3: Install the tempo plugin**

```bash
mkdir -p ~/.config/codeisland/plugins/
cp -R ~/Downloads/tmp/island/tempo-theme/tempo.bundle ~/.config/codeisland/plugins/
```

Restart the app (or trigger a plugin re-scan if the app supports hot-reload).

- [ ] **Step 4: Verify tempo appears and activates**

- App Theme picker now shows two tiles: "Default" and "Tempo".
- Click "Tempo": Settings window restyles to the warm mono palette (sidebar lightens to `#F5F5F3`, detail fill goes to `#FFFFFF`, accent green appears, illustrations begin cycling in the sidebar).
- Notch theme picker (below) is unaffected — picking a different notch theme shows the notch repaints but Settings keeps the tempo override.
- Click "Default": Settings reverts to current main appearance (notch-derived).

- [ ] **Step 5: Verify persistence**

- Pick "Tempo", quit the app, relaunch.
- Settings opens with tempo still active.

- [ ] **Step 6: Verify uninstall reset**

- With tempo active: `rm -rf ~/.config/codeisland/plugins/tempo.bundle`, restart.
- Settings opens with default theme (registry detected the active ID is no longer in `availableThemes` → called `store.reset()`).

- [ ] **Step 7: Run all standalone test scripts as a final regression sweep**

```bash
for f in scripts/test-app-theme-*.swift; do
  echo "=== $f ==="
  swift "$f" || { echo "FAILED: $f"; exit 1; }
done
echo "All app-theme scripts passed."
```

Expected: every script prints `PASS: …`.

- [ ] **Step 8: If smoke test reveals issues, file follow-up tasks**

Any divergence from expected behavior in steps 2-6 is a real bug — open as a new task and resolve before declaring this plan done. Common fix-ups expected:

- The exact `SettingsCard` invocation in Task 12 may need adjustment to match the existing card-wrapping style (some cards take `title:`, some don't).
- The `colorScheme` override in Task 11 may need to be applied at a more specific subtree if it leaks into other windows.

- [ ] **Step 9: Commit a summary note (optional)**

If everything passed, no commit needed beyond Task 13's. If the smoke test surfaced fix-ups that landed in additional commits, that's expected — each fix is its own commit.

---

## Self-review checklist (run after writing all tasks above)

**Spec coverage** (cross-check against `docs/superpowers/specs/2026-04-27-app-theme-system-design.md`):

- [x] `AppThemeID` — Task 1
- [x] `AppThemeManifest` (Codable types) — Task 2
- [x] `AppThemePalette` (resolved type, .default) — Task 3
- [x] `AppThemePalette.from(manifest:bundleResourcesURL:)` — Task 4
- [x] `AppThemeStore` (singleton, persistence, activate/reset) — Task 5
- [x] `AppThemeDescriptor` — Task 5
- [x] `AppThemeRegistry` (built-in + plugin discovery + reconciliation) — Tasks 6, 7, 8
- [x] `scripts/test-app-theme-tempo-fixture.swift` — Task 9
- [x] `AppThemeReader` (.appThemed() modifier) — Task 10
- [x] `AppThemePickerCard` — Task 10
- [x] `SystemSettingsView.Theme` enum integration — Task 11
- [x] `AppearanceTab` card insertion above notch — Task 12
- [x] `AppDelegate` launch wire-up + colorScheme override — Tasks 11 & 13
- [x] Notch theme system untouched — verified by absence of notch-related changes in any task
- [x] `NativePluginManager.swift` untouched — registry uses Combine subscription only

All spec requirements have a corresponding task.

**Placeholder scan:** No "TBD"/"TODO"/"add appropriate error handling"/etc. Every code block is concrete. ✓

**Type/method consistency:**
- `AppThemeStore.activate(descriptor:)` signature consistent across Tasks 5, 8, 10, 13.
- `AppThemeRegistry.loadAll(pluginBundles:)` signature consistent across Tasks 6, 7, 8.
- `AppThemePalette.from(manifest:bundleResourcesURL:)` signature consistent across Tasks 4, 5.
- `AppThemeDescriptor.bundleResourcesURL` (optional URL) consistent with how `Bundle.resourceURL` returns optional.
- Color hex helper named `Color.init(appThemeHex:)` in `AppThemePalette.swift` (Task 4) and `Color.init(appThemeHexFallback:)` in `AppThemePickerCard.swift` (Task 10) — different names because they're in separate files (`private extension`); this is intentional to avoid scope conflicts.

**Open observations / risks:**
- The Combine `dropFirst()` in Task 8 assumes `@Published` emits the initial empty value to new subscribers. This is correct for `@Published` at the time of writing, but if `NativePluginManager` ever switches to a `CurrentValueSubject` with non-empty initial state, the subscription would skip a real emission. Mitigation: the `loadAll(pluginBundles: nil)` reads live state directly, so the registry would still get correct data on the next emission.
- The smoke test in Task 14 assumes `~/.config/codeisland/plugins/` is the live install path. Confirm by reading the path in `NativePluginManager` first — if it's different (e.g., `Application Support`), update Task 14 step 3 accordingly.
