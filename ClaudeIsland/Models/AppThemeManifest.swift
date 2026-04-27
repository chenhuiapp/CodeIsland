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
