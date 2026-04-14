//
//  SettingsDisclosureRow.swift
//  ClaudeIsland
//
//  Palette-driven disclosure row used by the settings window (not notch UI).
//

import SwiftUI

struct SettingsDisclosureRow<Content: View>: View {
    let icon: String
    let title: String
    let currentValue: String
    @Binding var isExpanded: Bool
    let content: () -> Content

    @EnvironmentObject private var themeStore: SettingsThemeStore
    @State private var isHovered = false

    init(
        icon: String,
        title: String,
        currentValue: String,
        isExpanded: Binding<Bool>,
        @ViewBuilder content: @escaping () -> Content
    ) {
        self.icon = icon
        self.title = title
        self.currentValue = currentValue
        self._isExpanded = isExpanded
        self.content = content
    }

    var body: some View {
        VStack(spacing: 0) {
            Button {
                withAnimation(.easeInOut(duration: 0.2)) {
                    isExpanded.toggle()
                }
            } label: {
                HStack(spacing: 10) {
                    Image(systemName: icon)
                        .font(.system(size: 12))
                        .foregroundColor(titleColor)
                        .frame(width: 16)

                    Text(title)
                        .font(.system(size: 13, weight: .medium))
                        .foregroundColor(titleColor)

                    Spacer(minLength: 0)

                    Text(currentValue)
                        .font(.system(size: 11))
                        .foregroundColor(themeStore.palette.subtle)
                        .lineLimit(1)

                    Image(systemName: isExpanded ? "chevron.up" : "chevron.down")
                        .font(.system(size: 10))
                        .foregroundColor(themeStore.palette.subtle)
                }
                .padding(.horizontal, 12)
                .padding(.vertical, 10)
                .background(
                    RoundedRectangle(cornerRadius: 8)
                        .fill(isHovered ? themeStore.palette.hover : Color.clear)
                )
            }
            .buttonStyle(.plain)
            .onHover { isHovered = $0 }

            if isExpanded {
                content()
                    .padding(.leading, 28)
                    .padding(.top, 4)
                    .transition(.opacity.combined(with: .move(edge: .top)))
            }
        }
    }

    private var titleColor: Color {
        themeStore.palette.detailText.opacity(isHovered ? 0.95 : 0.7)
    }
}

