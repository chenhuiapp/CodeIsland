#!/usr/bin/env swift
import Foundation

// === Copy of AppThemeID (kept in sync with
//     ClaudeIsland/Models/AppThemeID.swift) ===

struct AppThemeID: RawRepresentable, Codable, Hashable, Identifiable {
    let rawValue: String
    var id: String { rawValue }
    init(rawValue: String) { self.rawValue = rawValue }
    static let `default` = AppThemeID(rawValue: "default")
}

// === Tests ===

func assertEqual<T: Equatable>(_ a: T, _ b: T, _ label: String) {
    if a != b {
        print("FAIL: \(label)\n  got:      \(a)\n  expected: \(b)")
        exit(1)
    }
}

let id1 = AppThemeID(rawValue: "tempo")
let id2 = AppThemeID(rawValue: "tempo")
let id3 = AppThemeID(rawValue: "default")

assertEqual(id1, id2, "rawValue equality")
assertEqual(id1.hashValue, id2.hashValue, "hashValue equality")
assertEqual(id1.id, "tempo", "Identifiable.id mirrors rawValue")
assertEqual(AppThemeID.default, id3, "static .default constant")

// Codable round-trip
let encoded = try JSONEncoder().encode(id1)
let decoded = try JSONDecoder().decode(AppThemeID.self, from: encoded)
assertEqual(decoded, id1, "Codable round-trip")

// Hash uniqueness
let set: Set<AppThemeID> = [id1, id2, id3]
assertEqual(set.count, 2, "Set deduplicates equal IDs")

print("PASS: AppThemeID — 6/6 assertions")
