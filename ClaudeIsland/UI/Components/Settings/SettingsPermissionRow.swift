//
//  SettingsPermissionRow.swift
//  ClaudeIsland
//
//  Palette-driven permission/status row for the settings window.
//

import SwiftUI

struct SettingsPermissionRow<TrailingContent: View>: View {
    let icon: String
    let title: String
    let trailingContent: () -> TrailingContent

    @EnvironmentObject private var themeStore: SettingsThemeStore
    @State private var isHovered = false

    init(
        icon: String,
        title: String,
        @ViewBuilder trailingContent: @escaping () -> TrailingContent
    ) {
        self.icon = icon
        self.title = title
        self.trailingContent = trailingContent
    }

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

            trailingContent()
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 10)
        .background(
            RoundedRectangle(cornerRadius: 8)
                .fill(isHovered ? themeStore.palette.hover : Color.clear)
        )
        .onHover { isHovered = $0 }
    }

    private var titleColor: Color {
        themeStore.palette.detailText.opacity(isHovered ? 0.95 : 0.7)
    }
}

