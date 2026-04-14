//
//  SettingsThemePickerRow.swift
//  ClaudeIsland
//
//  Palette-driven theme picker for the settings window.
//  Preserves plugin-manager-driven themes, "Default" semantics, and delayed collapse.
//

import SwiftUI

struct SettingsThemePickerRow: View {
    @EnvironmentObject private var themeStore: SettingsThemeStore
    @ObservedObject private var pluginManager = NativePluginManager.shared

    @State private var isExpanded = false

    var body: some View {
        SettingsDisclosureRow(
            icon: "paintpalette",
            title: "Theme",
            currentValue: currentSelectionLabel,
            isExpanded: $isExpanded
        ) {
            ScrollView {
                VStack(spacing: 2) {
                    SettingsSelectableOptionRow(
                        label: "Default",
                        sublabel: nil,
                        isSelected: themeStore.activeThemeId == nil
                    ) {
                        themeStore.reset()
                        collapseAfterDelay()
                    }

                    ForEach(sortedThemeIds, id: \.self) { id in
                        SettingsSelectableOptionRow(
                            label: pluginName(for: id) ?? id,
                            sublabel: nil,
                            isSelected: themeStore.activeThemeId == id
                        ) {
                            guard let entry = pluginManager.settingsThemeConfigs[id] else { return }
                            themeStore.activate(
                                id: id,
                                config: entry.config,
                                bundleResourcesURL: entry.resourcesURL
                            )
                            collapseAfterDelay()
                        }
                    }
                }
            }
            .frame(maxHeight: 240)
        }
    }

    private var currentSelectionLabel: String {
        guard let id = themeStore.activeThemeId else { return "Default" }
        return pluginName(for: id) ?? id
    }

    private var sortedThemeIds: [String] {
        pluginManager.settingsThemeConfigs.keys.sorted()
    }

    private func pluginName(for id: String) -> String? {
        pluginManager.loadedPlugins.first(where: { $0.id == id })?.name
    }

    private func collapseAfterDelay() {
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) {
            withAnimation(.easeInOut(duration: 0.2)) {
                isExpanded = false
            }
        }
    }
}
