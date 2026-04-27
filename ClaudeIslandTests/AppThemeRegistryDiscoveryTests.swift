//
//  AppThemeRegistryDiscoveryTests.swift
//  ClaudeIslandTests
//
//  Note: project has no XCTest target. Scaffolding only.
//

import XCTest
@testable import ClaudeIsland

@MainActor
final class AppThemeRegistryDiscoveryTests: XCTestCase {
    private var fixturesRoot: URL!

    override func setUpWithError() throws {
        fixturesRoot = FileManager.default.temporaryDirectory
            .appendingPathComponent("app-theme-discovery-\(UUID().uuidString)")
        try FileManager.default.createDirectory(at: fixturesRoot, withIntermediateDirectories: true)
    }

    override func tearDownWithError() throws {
        try? FileManager.default.removeItem(at: fixturesRoot)
    }

    /// Build a fake plugin bundle with the given JSON at
    /// Contents/Resources/plugin.json.
    private func makeBundle(name: String, json: String) throws -> Bundle {
        let dir = fixturesRoot.appendingPathComponent("\(name).bundle")
        let resources = dir.appendingPathComponent("Contents/Resources")
        try FileManager.default.createDirectory(at: resources, withIntermediateDirectories: true)
        try Data(json.utf8).write(to: resources.appendingPathComponent("plugin.json"))
        guard let bundle = Bundle(url: dir) else {
            throw NSError(domain: "test", code: -1)
        }
        return bundle
    }

    func testEmptyBundlesYieldsBuiltInOnly() {
        let registry = AppThemeRegistry()
        registry.loadAll(pluginBundles: [])
        XCTAssertEqual(registry.availableThemes.map(\.id), [.default])
    }

    func testSingleThemeBundleIsAppended() throws {
        let json = ##"{"type":"theme","id":"tempo","name":"Tempo","settings":{"colorScheme":"light"}}"##
        let bundle = try makeBundle(name: "tempo", json: json)
        let registry = AppThemeRegistry()
        registry.loadAll(pluginBundles: [bundle])
        XCTAssertEqual(registry.availableThemes.count, 2)
        XCTAssertEqual(registry.availableThemes.map(\.id), [.default, AppThemeID(rawValue: "tempo")])
        if case .plugin(let pluginID) = registry.availableThemes[1].source {
            XCTAssertEqual(pluginID, "tempo")
        } else {
            XCTFail("expected .plugin source")
        }
    }

    func testNonThemePluginIsIgnored() throws {
        let json = #"{"type":"buddy","id":"x"}"#
        let bundle = try makeBundle(name: "buddy", json: json)
        let registry = AppThemeRegistry()
        registry.loadAll(pluginBundles: [bundle])
        XCTAssertEqual(registry.availableThemes.map(\.id), [.default])
    }

    func testThemeBundleWithMissingSettingsIsIgnored() throws {
        let json = #"{"type":"theme","id":"bare"}"#
        let bundle = try makeBundle(name: "bare", json: json)
        let registry = AppThemeRegistry()
        registry.loadAll(pluginBundles: [bundle])
        XCTAssertEqual(registry.availableThemes.map(\.id), [.default])
    }

    func testDuplicateIDsAreDeduped() throws {
        let json1 = ##"{"type":"theme","id":"tempo","name":"Tempo One","settings":{"colorScheme":"light"}}"##
        let json2 = ##"{"type":"theme","id":"tempo","name":"Tempo Two","settings":{"colorScheme":"dark"}}"##
        let b1 = try makeBundle(name: "tempo1", json: json1)
        let b2 = try makeBundle(name: "tempo2", json: json2)
        let registry = AppThemeRegistry()
        registry.loadAll(pluginBundles: [b1, b2])
        XCTAssertEqual(registry.availableThemes.count, 2)
        XCTAssertEqual(registry.availableThemes[1].displayName, "Tempo One",
                       "first-seen wins")
    }

    func testMalformedJSONIsSkipped() throws {
        let dir = fixturesRoot.appendingPathComponent("malformed.bundle")
        let resources = dir.appendingPathComponent("Contents/Resources")
        try FileManager.default.createDirectory(at: resources, withIntermediateDirectories: true)
        try Data("not json".utf8).write(to: resources.appendingPathComponent("plugin.json"))
        let bundle = Bundle(url: dir)!
        let registry = AppThemeRegistry()
        registry.loadAll(pluginBundles: [bundle])
        XCTAssertEqual(registry.availableThemes.map(\.id), [.default])
    }

    func testBundleWithNoPluginJSONIsSkipped() throws {
        let dir = fixturesRoot.appendingPathComponent("empty.bundle")
        let resources = dir.appendingPathComponent("Contents/Resources")
        try FileManager.default.createDirectory(at: resources, withIntermediateDirectories: true)
        let bundle = Bundle(url: dir)!
        let registry = AppThemeRegistry()
        registry.loadAll(pluginBundles: [bundle])
        XCTAssertEqual(registry.availableThemes.map(\.id), [.default])
    }

    func testBundleMainIsSkipped() {
        let registry = AppThemeRegistry()
        // Bundle.main always exists; loadAll must not try to decode it.
        registry.loadAll(pluginBundles: [Bundle.main])
        XCTAssertEqual(registry.availableThemes.map(\.id), [.default])
    }
}
