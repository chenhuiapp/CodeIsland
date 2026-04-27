//
//  AppThemePaletteDefaultTests.swift
//  ClaudeIslandTests
//
//  Note: project has no XCTest target. Runtime authority is
//  scripts/test-app-theme-palette-default.swift.
//

import XCTest
@testable import ClaudeIsland

final class AppThemePaletteDefaultTests: XCTestCase {
    func testDefaultHasAllRolesNil() {
        let p = AppThemePalette.default
        XCTAssertNil(p.colorScheme)
        XCTAssertNil(p.sidebarFill)
        XCTAssertNil(p.sidebarText)
        XCTAssertNil(p.sidebarSelected)
        XCTAssertNil(p.sidebarSelectedText)
        XCTAssertNil(p.sidebarBorder)
        XCTAssertNil(p.detailFill)
        XCTAssertNil(p.detailText)
        XCTAssertNil(p.cardFill)
        XCTAssertNil(p.cardBorder)
        XCTAssertNil(p.subtle)
        XCTAssertNil(p.accent)
        XCTAssertNil(p.illustrations)
        XCTAssertNil(p.icons)
    }

    func testDefaultEquatable() {
        XCTAssertEqual(AppThemePalette.default, AppThemePalette.default)
    }

    func testIllustrationsEquatable() {
        let a = AppThemeIllustrations(urls: [URL(fileURLWithPath: "/x")], cycleDuration: 8, transition: .crossfade)
        let b = AppThemeIllustrations(urls: [URL(fileURLWithPath: "/x")], cycleDuration: 8, transition: .crossfade)
        XCTAssertEqual(a, b)
    }
}
