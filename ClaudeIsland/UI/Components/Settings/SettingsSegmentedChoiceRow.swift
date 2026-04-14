//
//  SettingsSegmentedChoiceRow.swift
//  ClaudeIsland
//
//  Palette-driven segmented choice row for the settings window.
//

import SwiftUI

struct SettingsSegmentedChoiceRow<Option: Hashable>: View {
    let icon: String
    let title: String
    let options: [(value: Option, label: String)]
    @Binding var selection: Option

    @EnvironmentObject private var themeStore: SettingsThemeStore
    @State private var isRowHovered = false
    @State private var hoveredOption: Option?

    var body: some View {
        HStack(spacing: 10) {
            Image(systemName: icon)
                .font(.system(size: 12))
                .foregroundColor(titleColor)
                .frame(width: 16)

            Text(title)
                .font(.system(size: 13, weight: .medium))
                .foregroundColor(titleColor)

            Spacer(minLength: 0)

            HStack(spacing: 3) {
                ForEach(options, id: \.value) { option in
                    Button {
                        selection = option.value
                    } label: {
                        Text(option.label)
                            .font(.system(size: 10, weight: isSelected(option.value) ? .bold : .regular))
                            .foregroundColor(labelColor(for: option.value))
                            .padding(.horizontal, 6)
                            .padding(.vertical, 3)
                            .background(segmentBackground(for: option.value))
                    }
                    .buttonStyle(.plain)
                    .onHover { hovering in
                        if hovering {
                            hoveredOption = option.value
                        } else if hoveredOption == option.value {
                            hoveredOption = nil
                        }
                    }
                }
            }
            .padding(2)
            .background(
                RoundedRectangle(cornerRadius: 6)
                    .fill(themeStore.palette.toggleOffBg)
            )
            .overlay(
                RoundedRectangle(cornerRadius: 6)
                    .strokeBorder(themeStore.palette.secondaryButtonBorder, lineWidth: 0.5)
            )
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 10)
        .background(
            RoundedRectangle(cornerRadius: 8)
                .fill(isRowHovered ? themeStore.palette.hover : Color.clear)
        )
        .onHover { isRowHovered = $0 }
    }

    private func isSelected(_ option: Option) -> Bool {
        selection == option
    }

    private func labelColor(for option: Option) -> Color {
        if isSelected(option) {
            return themeStore.palette.detailText.opacity(0.95)
        }
        if hoveredOption == option {
            return themeStore.palette.detailText.opacity(0.8)
        }
        return themeStore.palette.subtle
    }

    @ViewBuilder
    private func segmentBackground(for option: Option) -> some View {
        let isSelected = isSelected(option)
        let isHovered = hoveredOption == option
        RoundedRectangle(cornerRadius: 4)
            .fill(isSelected ? themeStore.palette.secondaryButtonFill : (isHovered ? themeStore.palette.secondaryButtonFill.opacity(0.6) : Color.clear))
    }

    private var titleColor: Color {
        themeStore.palette.detailText.opacity(isRowHovered ? 0.95 : 0.7)
    }
}
