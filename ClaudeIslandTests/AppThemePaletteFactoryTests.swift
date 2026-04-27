//
//  AppThemePaletteFactoryTests.swift
//  ClaudeIslandTests
//
//  Note: project has no XCTest target. Runtime authority is
//  scripts/test-app-theme-palette-factory.swift.
//

import XCTest
@testable import ClaudeIsland

final class AppThemePaletteFactoryTests: XCTestCase {
    private var fixturesDir: URL!

    override func setUpWithError() throws {
        fixturesDir = FileManager.default.temporaryDirectory
            .appendingPathComponent("app-theme-test-\(UUID().uuidString)")
        try FileManager.default.createDirectory(at: fixturesDir, withIntermediateDirectories: true)
        let assets = fixturesDir.appendingPathComponent("assets")
        try FileManager.default.createDirectory(at: assets, withIntermediateDirectories: true)
        try Data().write(to: assets.appendingPathComponent("illus_1.gif"))
        try Data().write(to: assets.appendingPathComponent("illus_2.gif"))
    }

    override func tearDownWithError() throws {
        try? FileManager.default.removeItem(at: fixturesDir)
    }

    func testFullManifestResolvesAllRoles() {
        let s = AppThemeManifestSettings(
            colorScheme: "light",
            sidebar: .init(fill: "#F5F5F3", text: "#1A1A1A", selected: "#1A1A1A", selectedText: "#F5F5F3", border: "#E0E0E0"),
            detail: .init(fill: "#FFFFFF", text: "#1A1A1A", cardFill: "#F0F0EE", cardBorder: "#E0E0E0", subtle: "#8A8A8A", accent: "#34C759"),
            illustrations: .init(files: ["assets/illus_1.gif", "assets/illus_2.gif"], cycleDuration: 8, transition: "crossfade"),
            icons: ["general": "gearshape"]
        )
        let p = AppThemePalette.from(manifest: s, bundleResourcesURL: fixturesDir)
        XCTAssertEqual(p.colorScheme, .light)
        XCTAssertNotNil(p.sidebarFill)
        XCTAssertNotNil(p.detailFill)
        XCTAssertNotNil(p.accent)
        XCTAssertEqual(p.illustrations?.urls.count, 2)
        XCTAssertEqual(p.illustrations?.cycleDuration, 8)
        XCTAssertEqual(p.illustrations?.transition, .crossfade)
        XCTAssertEqual(p.icons?["general"], "gearshape")
    }

    func testInvalidHexResolvesToNilLeavingOtherRolesIntact() {
        let s = AppThemeManifestSettings(
            colorScheme: nil,
            sidebar: .init(fill: "not-hex", text: "#000000", selected: nil, selectedText: nil, border: nil),
            detail: nil, illustrations: nil, icons: nil
        )
        let p = AppThemePalette.from(manifest: s, bundleResourcesURL: nil)
        XCTAssertNil(p.sidebarFill)
        XCTAssertNotNil(p.sidebarText)
    }

    func testPartialManifestLeavesUntouchedRolesNil() {
        let s = AppThemeManifestSettings(
            colorScheme: nil,
            sidebar: .init(fill: "#FFFFFF", text: nil, selected: nil, selectedText: nil, border: nil),
            detail: nil, illustrations: nil, icons: nil
        )
        let p = AppThemePalette.from(manifest: s, bundleResourcesURL: nil)
        XCTAssertNotNil(p.sidebarFill)
        XCTAssertNil(p.sidebarText)
        XCTAssertNil(p.detailFill)
        XCTAssertNil(p.illustrations)
    }

    func testAllMissingIllustrationsResolveToNil() {
        let s = AppThemeManifestSettings(
            colorScheme: nil, sidebar: nil, detail: nil,
            illustrations: .init(files: ["assets/missing.gif"], cycleDuration: 8, transition: "crossfade"),
            icons: nil
        )
        let p = AppThemePalette.from(manifest: s, bundleResourcesURL: fixturesDir)
        XCTAssertNil(p.illustrations)
    }

    func testMixedIllustrationsKeepOnlyExisting() {
        let s = AppThemeManifestSettings(
            colorScheme: nil, sidebar: nil, detail: nil,
            illustrations: .init(files: ["assets/illus_1.gif", "assets/missing.gif"], cycleDuration: 8, transition: "crossfade"),
            icons: nil
        )
        let p = AppThemePalette.from(manifest: s, bundleResourcesURL: fixturesDir)
        XCTAssertEqual(p.illustrations?.urls.count, 1)
    }

    func testUnknownTransitionDefaultsToCrossfade() {
        let s = AppThemeManifestSettings(
            colorScheme: nil, sidebar: nil, detail: nil,
            illustrations: .init(files: ["assets/illus_1.gif"], cycleDuration: 5, transition: "wobble"),
            icons: nil
        )
        let p = AppThemePalette.from(manifest: s, bundleResourcesURL: fixturesDir)
        XCTAssertEqual(p.illustrations?.transition, .crossfade)
    }

    func testCutTransitionRecognized() {
        let s = AppThemeManifestSettings(
            colorScheme: nil, sidebar: nil, detail: nil,
            illustrations: .init(files: ["assets/illus_1.gif"], cycleDuration: 5, transition: "cut"),
            icons: nil
        )
        let p = AppThemePalette.from(manifest: s, bundleResourcesURL: fixturesDir)
        XCTAssertEqual(p.illustrations?.transition, .cut)
    }

    func testNilBundleResourcesURLSkipsIllustrations() {
        let s = AppThemeManifestSettings(
            colorScheme: nil, sidebar: nil, detail: nil,
            illustrations: .init(files: ["x.gif"], cycleDuration: 8, transition: "crossfade"),
            icons: nil
        )
        let p = AppThemePalette.from(manifest: s, bundleResourcesURL: nil)
        XCTAssertNil(p.illustrations)
    }

    func testMissingCycleDurationDefaultsToEight() {
        let s = AppThemeManifestSettings(
            colorScheme: nil, sidebar: nil, detail: nil,
            illustrations: .init(files: ["assets/illus_1.gif"], cycleDuration: nil, transition: nil),
            icons: nil
        )
        let p = AppThemePalette.from(manifest: s, bundleResourcesURL: fixturesDir)
        XCTAssertEqual(p.illustrations?.cycleDuration, 8)
    }
}
