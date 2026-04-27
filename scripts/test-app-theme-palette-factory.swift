#!/usr/bin/env swift
import Foundation
import SwiftUI

// === Copies of AppThemeManifest, AppThemePalette, AppThemeIllustrations
//     (kept in sync with ClaudeIsland/Models/{AppThemeManifest,AppThemePalette}.swift) ===

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
}

// === Validating hex helper ===

private extension Color {
    init?(appThemeHex hex: String) {
        let cleaned = hex.hasPrefix("#") ? String(hex.dropFirst()) : hex
        guard cleaned.count == 6, cleaned.allSatisfy({ $0.isHexDigit }) else { return nil }
        var v: UInt64 = 0
        Scanner(string: cleaned).scanHexInt64(&v)
        let r = Double((v >> 16) & 0xFF) / 255.0
        let g = Double((v >> 8)  & 0xFF) / 255.0
        let b = Double( v        & 0xFF) / 255.0
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

// Test 4: Missing illustration files filtered (all missing → nil)
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

// Test 8: "cut" transition explicitly recognized
let cutTrans = AppThemeManifestSettings(
    colorScheme: nil, sidebar: nil, detail: nil,
    illustrations: AppThemeIllustrationsManifest(files: ["assets/illus_1.gif"], cycleDuration: 5, transition: "cut"),
    icons: nil
)
let ct = AppThemePalette.from(manifest: cutTrans, bundleResourcesURL: tmp)
assert(ct.illustrations?.transition == .cut, "cut transition recognized")

// Test 9: cycleDuration omitted → defaults to 8
let noDuration = AppThemeManifestSettings(
    colorScheme: nil, sidebar: nil, detail: nil,
    illustrations: AppThemeIllustrationsManifest(files: ["assets/illus_1.gif"], cycleDuration: nil, transition: nil),
    icons: nil
)
let nd = AppThemePalette.from(manifest: noDuration, bundleResourcesURL: tmp)
assert(nd.illustrations?.cycleDuration == 8, "missing cycleDuration → 8 default")

print("PASS: AppThemePalette factory — 19/19 assertions")
