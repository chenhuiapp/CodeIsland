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
        GridItem(.flexible(), spacing: 8),
        GridItem(.flexible(), spacing: 8),
    ]

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("App Theme")
                .font(.system(size: 12, weight: .semibold))
            Text("Restyles the Settings window. Independent of the notch theme.")
                .font(.system(size: 11))
                .foregroundColor(.secondary)

            LazyVGrid(columns: columns, spacing: 8) {
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
}

private struct AppThemePreviewTile: View {
    let descriptor: AppThemeDescriptor
    let isSelected: Bool
    let onTap: () -> Void

    var body: some View {
        Button(action: onTap) {
            VStack(spacing: 6) {
                ZStack {
                    RoundedRectangle(cornerRadius: 8)
                        .fill(previewBackground)
                    HStack(spacing: 4) {
                        RoundedRectangle(cornerRadius: 2)
                            .fill(previewSidebar)
                            .frame(width: 10, height: 24)
                        RoundedRectangle(cornerRadius: 2)
                            .fill(previewAccent)
                            .frame(width: 24, height: 24)
                    }
                }
                .frame(height: 36)
                .overlay(
                    RoundedRectangle(cornerRadius: 8)
                        .strokeBorder(
                            isSelected ? Color.accentColor : Color.black.opacity(0.12),
                            lineWidth: isSelected ? 2 : 0.5
                        )
                )

                Text(descriptor.displayName)
                    .font(.system(size: 11, weight: isSelected ? .semibold : .regular))
                    .lineLimit(1)
            }
            .padding(6)
        }
        .buttonStyle(.plain)
    }

    /// Mini preview colors. For built-in default we render neutral system
    /// surfaces; for plugin themes we sample the manifest directly so the
    /// tile shows what the theme will look like once activated.
    private var previewBackground: Color {
        if let hex = descriptor.manifest?.detail?.fill,
           let c = Color(appThemeHexFallback: hex) {
            return c
        }
        return Color(NSColor.windowBackgroundColor)
    }

    private var previewSidebar: Color {
        if let hex = descriptor.manifest?.sidebar?.fill,
           let c = Color(appThemeHexFallback: hex) {
            return c
        }
        return Color(NSColor.controlBackgroundColor)
    }

    private var previewAccent: Color {
        if let hex = descriptor.manifest?.detail?.accent,
           let c = Color(appThemeHexFallback: hex) {
            return c
        }
        return Color.accentColor
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
