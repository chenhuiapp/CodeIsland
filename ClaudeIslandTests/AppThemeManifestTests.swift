//
//  AppThemeManifestTests.swift
//  ClaudeIslandTests
//
//  Note: project has no XCTest target. Runtime authority is
//  scripts/test-app-theme-manifest.swift.
//

import XCTest
@testable import ClaudeIsland

final class AppThemeManifestTests: XCTestCase {
    private let decoder = JSONDecoder()

    func testDecodesTempoFullManifest() throws {
        let json = """
        {"type":"theme","id":"tempo","name":"Tempo","settings":{
          "colorScheme":"light",
          "sidebar":{"fill":"#F5F5F3","text":"#1A1A1A","selected":"#1A1A1A","selectedText":"#F5F5F3","border":"#E0E0E0"},
          "detail":{"fill":"#FFFFFF","text":"#1A1A1A","cardFill":"#F0F0EE","cardBorder":"#E0E0E0","subtle":"#8A8A8A","accent":"#34C759"},
          "illustrations":{"files":["a.gif","b.gif"],"cycleDuration":8,"transition":"crossfade"},
          "icons":{"general":"gearshape","appearance":"paintbrush.pointed.fill"}
        }}
        """
        let m = try decoder.decode(AppThemePluginManifest.self, from: Data(json.utf8))
        XCTAssertEqual(m.type, "theme")
        XCTAssertEqual(m.settings?.colorScheme, "light")
        XCTAssertEqual(m.settings?.sidebar?.fill, "#F5F5F3")
        XCTAssertEqual(m.settings?.illustrations?.files.count, 2)
        XCTAssertEqual(m.settings?.icons?["general"], "gearshape")
    }

    func testDecodesNonThemePluginType() throws {
        let json = #"{"type":"buddy","id":"x","settings":null}"#
        let m = try decoder.decode(AppThemePluginManifest.self, from: Data(json.utf8))
        XCTAssertEqual(m.type, "buddy")
        XCTAssertNil(m.settings)
    }

    func testDecodesThemeWithoutSettings() throws {
        let json = #"{"type":"theme","id":"bare"}"#
        let m = try decoder.decode(AppThemePluginManifest.self, from: Data(json.utf8))
        XCTAssertNil(m.settings)
    }

    func testPartialSettingsLeavesOtherSectionsNil() throws {
        // Note: ##"..."## (double-pound) raw delimiter is required because
        // the JSON contains "#000000" — `#"..."#` would terminate at the
        // embedded `"#` sequence inside the hex string.
        let json = ##"{"type":"theme","id":"p","settings":{"sidebar":{"fill":"#000000"}}}"##
        let m = try decoder.decode(AppThemePluginManifest.self, from: Data(json.utf8))
        XCTAssertEqual(m.settings?.sidebar?.fill, "#000000")
        XCTAssertNil(m.settings?.sidebar?.text)
        XCTAssertNil(m.settings?.detail)
        XCTAssertNil(m.settings?.icons)
    }

    func testMalformedHexPreservedAtDecode() throws {
        let json = #"{"type":"theme","id":"m","settings":{"detail":{"accent":"not-a-hex"}}}"#
        let m = try decoder.decode(AppThemePluginManifest.self, from: Data(json.utf8))
        XCTAssertEqual(m.settings?.detail?.accent, "not-a-hex")
    }
}
