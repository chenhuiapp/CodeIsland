//
//  AppThemeStoreTests.swift
//  ClaudeIslandTests
//
//  Note: project has no XCTest target. These tests are scaffolding only.
//

import XCTest
@testable import ClaudeIsland

@MainActor
final class AppThemeStoreTests: XCTestCase {
    private var defaults: UserDefaults!
    private var suiteName: String!

    override func setUp() {
        super.setUp()
        suiteName = "AppThemeStoreTest-\(UUID().uuidString)"
        defaults = UserDefaults(suiteName: suiteName)!
    }

    override func tearDown() {
        UserDefaults().removePersistentDomain(forName: suiteName)
        defaults = nil
        suiteName = nil
        super.tearDown()
    }

    private func builtInDefaultDescriptor() -> AppThemeDescriptor {
        AppThemeDescriptor(
            id: .default,
            displayName: "Default",
            manifest: nil,
            bundleResourcesURL: nil,
            source: .builtIn
        )
    }

    private func tempoDescriptor() -> AppThemeDescriptor {
        AppThemeDescriptor(
            id: AppThemeID(rawValue: "tempo"),
            displayName: "Tempo",
            manifest: AppThemeManifestSettings(
                colorScheme: "light",
                sidebar: .init(fill: "#F5F5F3", text: "#1A1A1A", selected: "#1A1A1A", selectedText: "#F5F5F3", border: "#E0E0E0"),
                detail: .init(fill: "#FFFFFF", text: "#1A1A1A", cardFill: "#F0F0EE", cardBorder: "#E0E0E0", subtle: "#8A8A8A", accent: "#34C759"),
                illustrations: nil,
                icons: nil
            ),
            bundleResourcesURL: nil,
            source: .plugin(pluginID: "tempo")
        )
    }

    func testInitialStateWithEmptyDefaults() {
        let store = AppThemeStore(defaults: defaults)
        XCTAssertEqual(store.palette, .default)
        XCTAssertNil(store.activeThemeID)
    }

    func testInitialStateWithPersistedID() {
        defaults.set("tempo", forKey: "AppTheme.activeThemeID")
        let store = AppThemeStore(defaults: defaults)
        XCTAssertEqual(store.activeThemeID, AppThemeID(rawValue: "tempo"))
        XCTAssertEqual(store.palette, .default,
                       "palette stays at .default until a descriptor activates")
    }

    func testActivateBuiltInResetsPaletteAndPersists() {
        let store = AppThemeStore(defaults: defaults)
        store.activate(descriptor: builtInDefaultDescriptor())
        XCTAssertEqual(store.activeThemeID, .default)
        XCTAssertEqual(store.palette, .default)
        XCTAssertEqual(defaults.string(forKey: "AppTheme.activeThemeID"), "default")
    }

    func testActivatePluginResolvesPaletteFromManifest() {
        let store = AppThemeStore(defaults: defaults)
        store.activate(descriptor: tempoDescriptor())
        XCTAssertEqual(store.activeThemeID, AppThemeID(rawValue: "tempo"))
        XCTAssertNotEqual(store.palette, .default,
                          "tempo's manifest should produce a non-default palette")
        XCTAssertNotNil(store.palette.sidebarFill)
        XCTAssertEqual(store.palette.colorScheme, .light)
        XCTAssertEqual(defaults.string(forKey: "AppTheme.activeThemeID"), "tempo")
    }

    func testResetClearsPaletteIDAndPersistence() {
        let store = AppThemeStore(defaults: defaults)
        store.activate(descriptor: tempoDescriptor())
        store.reset()
        XCTAssertNil(store.activeThemeID)
        XCTAssertEqual(store.palette, .default)
        XCTAssertNil(defaults.string(forKey: "AppTheme.activeThemeID"))
    }

    func testSecondActivateReplacesFirst() {
        let store = AppThemeStore(defaults: defaults)
        store.activate(descriptor: tempoDescriptor())
        store.activate(descriptor: builtInDefaultDescriptor())
        XCTAssertEqual(store.activeThemeID, .default)
        XCTAssertEqual(store.palette, .default)
    }
}
