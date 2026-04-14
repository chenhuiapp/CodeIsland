//
//  SettingsLanguagePickerRow.swift
//  ClaudeIsland
//
//  Settings-only language picker using palette-driven row primitives.
//

import SwiftUI

struct SettingsLanguagePickerRow: View {
    @State private var isExpanded = false
    @AppStorage("appLanguage") private var appLanguage: String = "auto"

    private let options: [(id: String, label: String)] = [
        ("auto", "Auto / 自动"),
        ("en", "English"),
        ("zh", "中文"),
    ]

    var body: some View {
        SettingsDisclosureRow(
            icon: "globe",
            title: L10n.language,
            currentValue: L10n.currentLanguageLabel,
            isExpanded: $isExpanded
        ) {
            VStack(spacing: 2) {
                ForEach(options, id: \.id) { option in
                    SettingsSelectableOptionRow(
                        label: option.label,
                        sublabel: nil,
                        isSelected: appLanguage == option.id
                    ) {
                        select(option.id)
                    }
                }
            }
        }
    }

    private func select(_ id: String) {
        appLanguage = id
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.25) {
            withAnimation(.easeInOut(duration: 0.2)) {
                isExpanded = false
            }
        }
    }
}
