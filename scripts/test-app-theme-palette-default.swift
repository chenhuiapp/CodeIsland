#!/usr/bin/env swift
import Foundation
import SwiftUI

// === Copy of AppThemePalette types (kept in sync with
//     ClaudeIsland/Models/AppThemePalette.swift) ===

struct AppThemeIllustrations: Equatable {
    let urls: [URL]
    let cycleDuration: TimeInterval
    let transition: AppThemeIllustrationTransition
}

enum AppThemeIllustrationTransition: String, Equatable {
    case crossfade
    case cut
}

struct AppThemePalette: Equatable {
    let colorScheme: ColorScheme?
    let sidebarFill: Color?
    let sidebarText: Color?
    let sidebarSelected: Color?
    let sidebarSelectedText: Color?
    let sidebarBorder: Color?
    let detailFill: Color?
    let detailText: Color?
    let cardFill: Color?
    let cardBorder: Color?
    let subtle: Color?
    let accent: Color?
    let illustrations: AppThemeIllustrations?
    let icons: [String: String]?

    static let `default` = AppThemePalette(
        colorScheme: nil,
        sidebarFill: nil, sidebarText: nil, sidebarSelected: nil,
        sidebarSelectedText: nil, sidebarBorder: nil,
        detailFill: nil, detailText: nil, cardFill: nil,
        cardBorder: nil, subtle: nil, accent: nil,
        illustrations: nil, icons: nil
    )
}

// === Tests ===

func assert(_ cond: Bool, _ label: String) {
    if !cond { print("FAIL: \(label)"); exit(1) }
}

let p = AppThemePalette.default

assert(p.colorScheme == nil, "default colorScheme nil")
assert(p.sidebarFill == nil, "default sidebarFill nil")
assert(p.sidebarText == nil, "default sidebarText nil")
assert(p.sidebarSelected == nil, "default sidebarSelected nil")
assert(p.sidebarSelectedText == nil, "default sidebarSelectedText nil")
assert(p.sidebarBorder == nil, "default sidebarBorder nil")
assert(p.detailFill == nil, "default detailFill nil")
assert(p.detailText == nil, "default detailText nil")
assert(p.cardFill == nil, "default cardFill nil")
assert(p.cardBorder == nil, "default cardBorder nil")
assert(p.subtle == nil, "default subtle nil")
assert(p.accent == nil, "default accent nil")
assert(p.illustrations == nil, "default illustrations nil")
assert(p.icons == nil, "default icons nil")
assert(p == AppThemePalette.default, "default == default")

// Equatable round-trip on illustrations
let i1 = AppThemeIllustrations(urls: [URL(fileURLWithPath: "/x")], cycleDuration: 8, transition: .crossfade)
let i2 = AppThemeIllustrations(urls: [URL(fileURLWithPath: "/x")], cycleDuration: 8, transition: .crossfade)
assert(i1 == i2, "illustrations equatable")

print("PASS: AppThemePalette default — 16/16 assertions")
