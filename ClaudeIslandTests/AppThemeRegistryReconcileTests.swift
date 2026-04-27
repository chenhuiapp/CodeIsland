//
//  AppThemeRegistryReconcileTests.swift
//  ClaudeIslandTests
//
//  Note: project has no XCTest target. Scaffolding only.
//

import XCTest
@testable import ClaudeIsland

@MainActor
final class AppThemeRegistryReconcileTests: XCTestCase {
    private var fixturesRoot: URL!

    override func setUpWithError() throws {
        fixturesRoot = FileManager.default.temporaryDirectory
            .appendingPathComponent("app-theme-reconcile-\(UUID().uuidString)")
        try FileManager.default.createDirectory(at: fixturesRoot, withIntermediateDirectories: true)
    }

    override func tearDownWithError() throws {
        try? FileManager.default.removeItem(at: fixturesRoot)
    }

    private func makeBundle(name: String, json: String) throws -> Bundle {
        let dir = fixturesRoot.appendingPathComponent("\(name).bundle")
        let resources = dir.appendingPathComponent("Contents/Resources")
        try FileManager.default.createDirectory(at: resources, withIntermediateDirectories: true)
        try Data(json.utf8).write(to: resources.appendingPathComponent("plugin.json"))
        return Bundle(url: dir)!
    }

    private func makeStore() -> AppThemeStore {
        let suite = "AppThemeReconcileTest-\(UUID().uuidString)"
        let defaults = UserDefaults(suiteName: suite)!
        return AppThemeStore(defaults: defaults)
    }

    private let tempoJSON = ##"""
    {"type":"theme","id":"tempo","name":"Tempo","settings":{
      "colorScheme":"light",
      "sidebar":{"fill":"#F5F5F3","text":"#1A1A1A","selected":"#1A1A1A","selectedText":"#F5F5F3","border":"#E0E0E0"},
      "detail":{"fill":"#FFFFFF","text":"#1A1A1A","cardFill":"#F0F0EE","cardBorder":"#E0E0E0","subtle":"#8A8A8A","accent":"#34C759"}
    }}
    """##

    func testColdStartWithEmptyBundlesDoesNotReset() {
        // Cold-start: persisted "tempo" but plugin manager hasn't emitted yet.
        // loadAll(pluginBundles: []) must NOT reset the store, since the
        // plugin may still be in flight.
        let store = makeStore()
        let suiteDefaults = UserDefaults(suiteName: "AppThemeReconcileTest-cold-\(UUID())")!
        suiteDefaults.set("tempo", forKey: "AppTheme.activeThemeID")
        let coldStore = AppThemeStore(defaults: suiteDefaults)
        XCTAssertEqual(coldStore.activeThemeID, AppThemeID(rawValue: "tempo"))

        let registry = AppThemeRegistry(store: coldStore)
        registry.loadAll(pluginBundles: [])
        XCTAssertEqual(coldStore.activeThemeID, AppThemeID(rawValue: "tempo"),
                       "cold start with no bundles must not reset the active ID")
        _ = store // silence unused-warning
    }

    func testColdStartWithTempoBundleActivates() throws {
        let suite = "AppThemeReconcileTest-warm-\(UUID())"
        let suiteDefaults = UserDefaults(suiteName: suite)!
        suiteDefaults.set("tempo", forKey: "AppTheme.activeThemeID")
        let store = AppThemeStore(defaults: suiteDefaults)

        let registry = AppThemeRegistry(store: store)
        let bundle = try makeBundle(name: "tempo", json: tempoJSON)
        registry.loadAll(pluginBundles: [bundle])

        XCTAssertEqual(store.activeThemeID, AppThemeID(rawValue: "tempo"))
        XCTAssertNotEqual(store.palette, .default,
                          "tempo's manifest should produce a non-default palette")
    }

    func testUninstallAfterSeenResets() throws {
        // Activate tempo, then loadAll with an empty list AFTER having seen plugins.
        let suite = "AppThemeReconcileTest-uninstall-\(UUID())"
        let suiteDefaults = UserDefaults(suiteName: suite)!
        let store = AppThemeStore(defaults: suiteDefaults)

        let registry = AppThemeRegistry(store: store)
        let bundle = try makeBundle(name: "tempo", json: tempoJSON)
        registry.loadAll(pluginBundles: [bundle])  // sets hasSeenPlugins = true
        XCTAssertEqual(store.activeThemeID, AppThemeID(rawValue: "tempo"))

        registry.loadAll(pluginBundles: [])  // simulate uninstall
        XCTAssertNil(store.activeThemeID, "missing ID after seen plugins must reset")
        XCTAssertEqual(store.palette, .default)
    }

    func testReinstallReactivates() throws {
        let suite = "AppThemeReconcileTest-reinstall-\(UUID())"
        let suiteDefaults = UserDefaults(suiteName: suite)!
        suiteDefaults.set("tempo", forKey: "AppTheme.activeThemeID")
        let store = AppThemeStore(defaults: suiteDefaults)

        let registry = AppThemeRegistry(store: store)
        let bundle = try makeBundle(name: "tempo", json: tempoJSON)
        registry.loadAll(pluginBundles: [bundle])
        XCTAssertEqual(store.activeThemeID, AppThemeID(rawValue: "tempo"))
    }

    func testBuiltInDefaultStaysActiveOnEmptyReload() {
        let suite = "AppThemeReconcileTest-default-\(UUID())"
        let suiteDefaults = UserDefaults(suiteName: suite)!
        let store = AppThemeStore(defaults: suiteDefaults)

        let registry = AppThemeRegistry(store: store)
        registry.loadAll(pluginBundles: [])
        store.activate(descriptor: registry.descriptor(for: .default))

        registry.loadAll(pluginBundles: [])
        XCTAssertEqual(store.activeThemeID, .default,
                       "built-in default is always available, never reset")
    }

    func testIdempotentReload() throws {
        let suite = "AppThemeReconcileTest-idempotent-\(UUID())"
        let suiteDefaults = UserDefaults(suiteName: suite)!
        suiteDefaults.set("tempo", forKey: "AppTheme.activeThemeID")
        let store = AppThemeStore(defaults: suiteDefaults)

        let registry = AppThemeRegistry(store: store)
        let bundle = try makeBundle(name: "tempo", json: tempoJSON)
        registry.loadAll(pluginBundles: [bundle])
        let firstPalette = store.palette
        registry.loadAll(pluginBundles: [bundle])
        XCTAssertEqual(store.palette, firstPalette,
                       "re-loading with same bundle yields identical palette")
    }
}
