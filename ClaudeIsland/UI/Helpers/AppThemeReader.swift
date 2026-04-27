//
//  AppThemeReader.swift
//  ClaudeIsland
//
//  Tiny convenience modifier — injects AppThemeStore.shared into the view
//  hierarchy as an @EnvironmentObject so descendants can observe palette
//  changes. Apply at the settings-window root.
//

import SwiftUI

extension View {
    /// Inject AppThemeStore.shared so descendants can read the active
    /// palette via @EnvironmentObject AppThemeStore.
    func appThemed() -> some View {
        environmentObject(AppThemeStore.shared)
    }
}
