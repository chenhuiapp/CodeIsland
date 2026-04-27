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

// Validating hex initializer scoped to this file so we don't collide with
// NotchTheme's existing `Color(hex:)` (which silently accepts garbage).
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
