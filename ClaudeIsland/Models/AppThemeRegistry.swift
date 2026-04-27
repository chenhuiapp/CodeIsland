//
//  AppThemeRegistry.swift
//  ClaudeIsland
//
//  Discovers App Theme descriptors: a hard-coded built-in default plus
//  any plugin-provided themes (loaded via NativePluginManager Combine
//  subscription — wired up in a later task). Mirrors main's
//  ThemeRegistry shape.
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
