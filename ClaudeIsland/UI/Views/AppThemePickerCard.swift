//
//  AppThemePickerCard.swift
//  ClaudeIsland
//
//  Picker card for the App Theme system — sits above the notch
//  customization card on the Appearance tab in SystemSettingsView.
//  Iterates AppThemeRegistry.shared.availableThemes and lets the user
//  pick one. Selection is stored in AppThemeStore.shared.
//

import SwiftUI

struct AppThemePickerCard: View {
    @ObservedObject private var registry = AppThemeRegistry.shared
    @ObservedObject private var store = AppThemeStore.shared

    private let columns = [
        GridItem(.flexible(), spacing: 10),
        GridItem(.flexible(), spacing: 10),
    ]

    var body: some View {
        // No inline header — the parent `SettingsCard(title: "App Theme")`
        // owns the section label so the App Theme picker reads as a sibling
        // to the SCREEN and NOTCH sections rather than introducing a
        // second header style.
        LazyVGrid(columns: columns, spacing: 10) {
            ForEach(registry.availableThemes) { descriptor in
                AppThemePreviewTile(
                    descriptor: descriptor,
                    isSelected: store.activeThemeID == descriptor.id
                ) {
                    store.activate(descriptor: descriptor)
                }
            }
        }
    }
}

/// One cell in the App Theme grid. Mirrors `ThemePreviewCard` (notch theme
/// tile) so both pickers in the Appearance tab read as siblings — a card
/// with a small preview at top, theme name below, hover/selection chrome.
private struct AppThemePreviewTile: View {
    let descriptor: AppThemeDescriptor
    let isSelected: Bool
    let onTap: () -> Void
    @State private var isHovered = false

    var body: some View {
        Button(action: onTap) {
            VStack(alignment: .leading, spacing: 10) {
                // Mini Settings preview: sidebar strip on the left, detail
                // surface on the right with an accent dot + faux text bar.
                // Communicates the theme's contrast and accent in one glance.
                ZStack {
                    RoundedRectangle(cornerRadius: 8)
                        .fill(previewDetailFill)
                        .overlay(
                            RoundedRectangle(cornerRadius: 8)
                                .strokeBorder(previewBorder, lineWidth: 0.5)
                        )
                    HStack(spacing: 0) {
                        ZStack(alignment: .top) {
                            RoundedRectangle(cornerRadius: 4)
                                .fill(previewSidebarFill)
                            VStack(alignment: .leading, spacing: 3) {
                                Capsule()
                                    .fill(previewSidebarSelected)
                                    .frame(width: 14, height: 4)
                                Capsule()
                                    .fill(previewSidebarText.opacity(0.45))
                                    .frame(width: 12, height: 3)
                                Capsule()
                                    .fill(previewSidebarText.opacity(0.45))
                                    .frame(width: 10, height: 3)
                            }
                            .padding(.top, 6)
                        }
                        .frame(width: 24)
                        .padding([.vertical, .leading], 4)

                        Spacer()

                        HStack(spacing: 4) {
                            Circle()
                                .fill(previewAccent)
                                .frame(width: 6, height: 6)
                            RoundedRectangle(cornerRadius: 1)
                                .fill(previewDetailText.opacity(0.55))
                                .frame(width: 36, height: 3)
                        }
                        .padding(.trailing, 10)
                    }
                }
                .frame(height: 44)

                Text(descriptor.displayName)
                    .font(.system(size: 11, weight: isSelected ? .semibold : .medium))
                    .foregroundColor(isSelected ? Theme.detailText : Theme.subtle)
                    .lineLimit(1)
            }
            .padding(10)
            .frame(maxWidth: .infinity, alignment: .leading)
            // Tile bg is a subtle overlay on top of the parent SettingsCard
            // (matches NotchCustomizationSettingsView's ThemePreviewCard:
            // `currentTheme.overlay.opacity(0.08)`). Theme.controlFill on
            // this branch resolves to `resolver.overlay.opacity(0.18)` so
            // it nests naturally without painting another full card.
            .background(
                RoundedRectangle(cornerRadius: 10)
                    .fill(isSelected
                          ? previewAccent.opacity(0.12)
                          : (isHovered ? Theme.iconTileFill : Theme.controlFill))
            )
            .overlay(
                RoundedRectangle(cornerRadius: 10)
                    .strokeBorder(
                        isSelected ? previewAccent : Theme.cardBorder,
                        lineWidth: isSelected ? 1.5 : 0.5
                    )
            )
            .contentShape(RoundedRectangle(cornerRadius: 10))
        }
        .buttonStyle(.plain)
        .onHover { isHovered = $0 }
        .accessibilityLabel("\(descriptor.displayName) app theme")
        .accessibilityAddTraits(isSelected ? .isSelected : [])
    }

    // MARK: - Preview color resolution

    /// For built-in default we fall back to neutral system surfaces; for
    /// plugin themes we sample the manifest directly so the tile previews
    /// what the theme will look like once activated.
    private var previewDetailFill: Color {
        hex(descriptor.manifest?.detail?.fill) ?? Color(NSColor.windowBackgroundColor)
    }
    private var previewSidebarFill: Color {
        hex(descriptor.manifest?.sidebar?.fill) ?? Color(NSColor.controlBackgroundColor)
    }
    private var previewSidebarText: Color {
        hex(descriptor.manifest?.sidebar?.text) ?? .primary
    }
    private var previewSidebarSelected: Color {
        hex(descriptor.manifest?.sidebar?.selected)
            ?? hex(descriptor.manifest?.detail?.accent)
            ?? Color.accentColor
    }
    private var previewDetailText: Color {
        hex(descriptor.manifest?.detail?.text) ?? .primary
    }
    private var previewAccent: Color {
        hex(descriptor.manifest?.detail?.accent) ?? Color.accentColor
    }
    private var previewBorder: Color {
        hex(descriptor.manifest?.detail?.cardBorder) ?? Color.black.opacity(0.14)
    }

    private func hex(_ value: String?) -> Color? {
        guard let value else { return nil }
        return Color(appThemeHexFallback: value)
    }
}

private extension Color {
    init?(appThemeHexFallback hex: String) {
        let cleaned = hex.hasPrefix("#") ? String(hex.dropFirst()) : hex
        guard cleaned.count == 6, cleaned.allSatisfy({ $0.isHexDigit }) else { return nil }
        var v: UInt64 = 0
        Scanner(string: cleaned).scanHexInt64(&v)
        self.init(
            red:   Double((v >> 16) & 0xFF) / 255.0,
            green: Double((v >> 8)  & 0xFF) / 255.0,
            blue:  Double( v        & 0xFF) / 255.0
        )
    }
}
