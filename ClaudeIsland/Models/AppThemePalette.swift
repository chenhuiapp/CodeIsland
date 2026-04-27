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
