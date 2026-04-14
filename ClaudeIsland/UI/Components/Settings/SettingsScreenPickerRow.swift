//
//  SettingsScreenPickerRow.swift
//  ClaudeIsland
//
//  Palette-driven screen selection picker for the settings window.
//  Preserves automatic vs explicit selection, built-in/main sublabels,
//  screen-parameter notifications, and delayed collapse.
//

import AppKit
import SwiftUI

struct SettingsScreenPickerRow: View {
    @ObservedObject var screenSelector: ScreenSelector

    private var isExpanded: Binding<Bool> {
        Binding(
            get: { screenSelector.isPickerExpanded },
            set: { screenSelector.isPickerExpanded = $0 }
        )
    }

    var body: some View {
        SettingsDisclosureRow(
            icon: "display",
            title: L10n.screen,
            currentValue: currentSelectionLabel,
            isExpanded: isExpanded
        ) {
            ScrollView {
                VStack(spacing: 2) {
                    SettingsSelectableOptionRow(
                        label: L10n.automatic,
                        sublabel: L10n.builtInOrMain,
                        isSelected: screenSelector.selectionMode == .automatic
                    ) {
                        screenSelector.selectAutomatic()
                        triggerWindowRecreation()
                        collapseAfterDelay()
                    }

                    ForEach(screenSelector.availableScreens, id: \.self) { screen in
                        SettingsSelectableOptionRow(
                            label: screen.localizedName,
                            sublabel: screenSublabel(for: screen),
                            isSelected: screenSelector.selectionMode == .specificScreen && screenSelector.isSelected(screen)
                        ) {
                            screenSelector.selectScreen(screen)
                            triggerWindowRecreation()
                            collapseAfterDelay()
                        }
                    }
                }
            }
            .frame(maxHeight: screenSelector.expandedPickerHeight)
        }
    }

    private var currentSelectionLabel: String {
        switch screenSelector.selectionMode {
        case .automatic:
            return L10n.auto_
        case .specificScreen:
            return screenSelector.selectedScreen?.localizedName ?? L10n.auto_
        }
    }

    private func screenSublabel(for screen: NSScreen) -> String? {
        var parts: [String] = []
        if screen.isBuiltinDisplay {
            parts.append(L10n.builtIn)
        }
        if screen == NSScreen.main {
            parts.append(L10n.main_)
        }
        return parts.isEmpty ? nil : parts.joined(separator: ", ")
    }

    private func triggerWindowRecreation() {
        NotificationCenter.default.post(
            name: NSApplication.didChangeScreenParametersNotification,
            object: nil
        )
    }

    private func collapseAfterDelay() {
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) {
            withAnimation(.easeInOut(duration: 0.2)) {
                isExpanded.wrappedValue = false
            }
        }
    }
}
