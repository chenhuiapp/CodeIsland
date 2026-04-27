#!/usr/bin/env swift
import Foundation

// End-to-end fixture verification: loads the actual tempo plugin bundle
// from disk and asserts the manifest schema matches what the App Theme
// system expects. Catches schema regressions even without Xcode.

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
