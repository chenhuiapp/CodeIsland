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

// Test 1: Decode tempo's full plugin.json (mirrors the on-disk shape)
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

print("PASS: AppThemeManifest — 16/16 assertions")
