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
        // Palette stays at `.default` until a descriptor activates — the
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
