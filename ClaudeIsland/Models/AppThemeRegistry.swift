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

    // MARK: - Plugin discovery

    /// Public entry point. Pass `nil` to read live state from
    /// `NativePluginManager.shared.loadedPlugins`; pass a list to inject
    /// for tests. Reconciliation with the store is added in Task 8.
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
}
