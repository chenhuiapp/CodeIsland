//
//  AppThemeIDTests.swift
//  ClaudeIslandTests
//
//  Note: project has no XCTest target. Runtime authority is
//  scripts/test-app-theme-id.swift.
//

import XCTest
@testable import ClaudeIsland

final class AppThemeIDTests: XCTestCase {
    func testRawValueEquality() {
        XCTAssertEqual(AppThemeID(rawValue: "tempo"), AppThemeID(rawValue: "tempo"))
    }

    func testIdentifiableMirrorsRawValue() {
        XCTAssertEqual(AppThemeID(rawValue: "tempo").id, "tempo")
    }

    func testDefaultConstant() {
        XCTAssertEqual(AppThemeID.default, AppThemeID(rawValue: "default"))
    }

    func testCodableRoundTrip() throws {
        let id = AppThemeID(rawValue: "tempo")
        let encoded = try JSONEncoder().encode(id)
        let decoded = try JSONDecoder().decode(AppThemeID.self, from: encoded)
        XCTAssertEqual(decoded, id)
    }

    func testHashableSetDedup() {
        let set: Set<AppThemeID> = [
            AppThemeID(rawValue: "tempo"),
            AppThemeID(rawValue: "tempo"),
            AppThemeID(rawValue: "default"),
        ]
        XCTAssertEqual(set.count, 2)
    }
}
