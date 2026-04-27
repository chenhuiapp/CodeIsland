//
//  AppThemeRegistryBuiltInTests.swift
//  ClaudeIslandTests
//
//  Note: project has no XCTest target. Scaffolding only.
//

import XCTest
@testable import ClaudeIsland

@MainActor
final class AppThemeRegistryBuiltInTests: XCTestCase {
    func testBuiltInDefaultIsTheOnlyAvailableTheme() {
        let registry = AppThemeRegistry()
        XCTAssertEqual(registry.availableThemes.count, 1)
        XCTAssertEqual(registry.availableThemes.first?.id, .default)
        XCTAssertEqual(registry.availableThemes.first?.source, .builtIn)
    }

    func testThemeIDsMatchAvailable() {
        let registry = AppThemeRegistry()
        XCTAssertEqual(registry.themeIDs, [.default])
    }

    func testDescriptorReturnsExactMatch() {
        let registry = AppThemeRegistry()
        let d = registry.descriptor(for: .default)
        XCTAssertEqual(d.id, .default)
        XCTAssertEqual(d.displayName, "Default")
    }

    func testDescriptorFallsBackForUnknownID() {
        let registry = AppThemeRegistry()
        let d = registry.descriptor(for: AppThemeID(rawValue: "tempo"))
        XCTAssertEqual(d.id, .default,
                       "missing ID falls back to built-in default")
    }

    func testDisplayNameForBuiltIn() {
        let registry = AppThemeRegistry()
        XCTAssertEqual(registry.displayName(for: .default), "Default")
    }
}
