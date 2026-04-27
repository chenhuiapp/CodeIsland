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
    private var hasSeenPlugins = false

    init(store: AppThemeStore = .shared) {
        self.store = store
        self.availableThemes = Self.builtInDescriptors

        // React to plugin lifecycle changes after init. dropFirst() skips
        // the @Published replay of the current value (whatever it is at
        // subscribe time) — we only care about subsequent emissions, since
        // tests inject bundles directly and production code wires this up
        // after NativePluginManager has had a chance to populate.
        NativePluginManager.shared.$loadedPlugins
            .dropFirst()
            .sink { [weak self] _ in
                Task { @MainActor in
                    self?.loadAll()
                }
            }
            .store(in: &cancellables)
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
    /// for tests. After rebuilding `availableThemes`, reconciles the
    /// store's `activeThemeID` against what's now available.
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

    /// Sync the store with the freshly rebuilt `availableThemes`:
    /// - If the persisted active ID is found, re-activate (refreshes the
    ///   palette in case the bundle just became reachable).
    /// - If it's missing AND we've seen at least one non-empty plugin
    ///   list, reset. (We don't reset on the cold-start empty list — the
    ///   plugin may still be in flight.)
    private func reconcile() {
        guard let active = store.activeThemeID else { return }
        if let descriptor = availableThemes.first(where: { $0.id == active }) {
            store.activate(descriptor: descriptor)
        } else if hasSeenPlugins {
            store.reset()
        }
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
