//
//  AppThemeID.swift
//  ClaudeIsland
//
//  Identity type for the App Theme system. Mirrors NotchThemeID's shape
//  but is a distinct type — App Theme and Notch Theme are independent.
//

import Foundation

struct AppThemeID: RawRepresentable, Codable, Hashable, Identifiable {
    let rawValue: String
    var id: String { rawValue }

    init(rawValue: String) {
        self.rawValue = rawValue
    }

    /// Built-in default theme — equivalent to no override applied.
    static let `default` = AppThemeID(rawValue: "default")
}
