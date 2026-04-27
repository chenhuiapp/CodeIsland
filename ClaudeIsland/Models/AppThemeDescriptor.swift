//
//  AppThemeDescriptor.swift
//  ClaudeIsland
//
//  An entry in AppThemeRegistry.availableThemes — represents one
//  selectable theme. The built-in default has manifest = nil; plugin
//  themes carry their decoded manifest and bundle resources URL so the
//  store can resolve the palette on activation.
//

import Foundation

struct AppThemeDescriptor: Equatable, Identifiable {
    let id: AppThemeID
    let displayName: String
    let manifest: AppThemeManifestSettings?
    let bundleResourcesURL: URL?
    let source: Source

    enum Source: Equatable {
        case builtIn
        case plugin(pluginID: String)
    }
}
