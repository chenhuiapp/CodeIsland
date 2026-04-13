//
//  SystemSettingsView.swift
//  ClaudeIsland
//
//  Floating "System Settings" window — the single home for every
//  configuration surface that used to crowd the notch menu or open its
//  own one-off popup (Launch Presets included).
//
//  Layout: vertical sidebar on the left (tab list), detail view on the
//  right. Designed to scale to many more tabs as config grows — add
//  a new case to `SettingsTab`, a new content view, and a single line
//  in the dispatcher.
//
//  Theme: Workspace Mono styling with a warm white sidebar and
//  a clean white detail panel.
//

import AppKit
import ApplicationServices
import Combine
import ServiceManagement
import SwiftUI

// MARK: - Notch menu entry row

struct SystemSettingsRow: View {
    @State private var isHovered = false

    var body: some View {
        Button {
            SystemSettingsWindow.shared.show()
        } label: {
            HStack(spacing: 10) {
                Image(systemName: "gearshape.fill")
                    .font(.system(size: 12))
                    .opacity(isHovered ? 1 : 0.6)
                    .frame(width: 16)

                Text(L10n.openSettings)
                    .font(.system(size: 13, weight: .medium))
                    .opacity(isHovered ? 1 : 0.7)

                Spacer()

                Image(systemName: "chevron.right")
                    .font(.system(size: 10, weight: .semibold))
                    .opacity(0.3)
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 10)
            .contentShape(Rectangle())
            .background(
                RoundedRectangle(cornerRadius: 8)
                    .fill(isHovered ? Color.black.opacity(0.05) : Color.clear)
            )
        }
        .buttonStyle(.plain)
        .onHover { isHovered = $0 }
    }
}

// MARK: - Floating Window

@MainActor
final class SystemSettingsWindow {
    static let shared = SystemSettingsWindow()

    private var window: NSWindow?

    func show(initialTab: SettingsTab = .general) {
        if let existing = window {
            existing.makeKeyAndOrderFront(nil)
            NSApplication.shared.activate(ignoringOtherApps: true)
            return
        }

        let contentView = SystemSettingsContentView(initialTab: initialTab) { self.close() }
        let hostingView = NSHostingView(rootView: contentView)
        let w = NSWindow(
            contentRect: NSRect(x: 0, y: 0, width: 720, height: 560),
            styleMask: [.borderless],
            backing: .buffered,
            defer: false
        )
        w.backgroundColor = .clear
        w.isOpaque = false
        w.hasShadow = true
        w.isMovableByWindowBackground = true
        w.contentView = hostingView
        w.contentView?.wantsLayer = true
        w.contentView?.layer?.cornerRadius = 16
        w.contentView?.layer?.masksToBounds = true

        if let screen = NSScreen.main {
            let f = screen.frame
            w.setFrameOrigin(NSPoint(x: f.midX - 360, y: f.midY - 280))
        }

        w.level = NSWindow.Level(rawValue: Int(CGWindowLevelForKey(.maximumWindow)))
        NSApplication.shared.activate(ignoringOtherApps: true)
        w.makeKeyAndOrderFront(nil)
        w.isReleasedWhenClosed = false
        self.window = w
    }

    func close() {
        window?.close()
        window = nil
    }
}

// MARK: - Tab enum

enum SettingsTab: String, CaseIterable, Identifiable {
    case general
    case appearance
    case notifications
    case behavior
    case plugins
    case codelight       // Pair iPhone + Launch Presets merged
    case advanced
    case about

    var id: String { rawValue }

    var icon: String {
        switch self {
        case .general:       return "gearshape.fill"
        case .appearance:    return "paintbrush.fill"
        case .notifications: return "bell.badge.fill"
        case .behavior:      return "slider.horizontal.3"
        case .plugins:       return "puzzlepiece.extension.fill"
        case .codelight:     return "iphone.radiowaves.left.and.right"
        case .advanced:      return "wrench.and.screwdriver.fill"
        case .about:         return "info.circle.fill"
        }
    }

    var label: String {
        switch self {
        case .general:       return L10n.tabGeneral
        case .appearance:    return L10n.tabAppearance
        case .notifications: return L10n.tabNotifications
        case .behavior:      return L10n.tabBehavior
        case .plugins:       return "Plugins"
        case .codelight:     return L10n.tabCodeLight
        case .advanced:      return L10n.tabAdvanced
        case .about:         return L10n.tabAbout
        }
    }
}

// MARK: - Shared theming constants

/// Two-surface theme: warm white sidebar, clean white detail surface.
private enum Theme {
    // Workspace Mono — warm white sidebar, clean white detail.
    static let sidebarFill = Color(red: 0xF5/255, green: 0xF5/255, blue: 0xF3/255)
    static let sidebarText = Color(red: 0x1A/255, green: 0x1A/255, blue: 0x1A/255)
    static let sidebarSelected = Color(red: 0x1A/255, green: 0x1A/255, blue: 0x1A/255)
    static let sidebarSelectedText = Color(red: 0xF5/255, green: 0xF5/255, blue: 0xF3/255)
    static let sidebarBorder = Color(red: 0xE0/255, green: 0xE0/255, blue: 0xE0/255)

    // Clean white detail area
    static let detailFill = Color.white
    static let detailText = Color(red: 0x1A/255, green: 0x1A/255, blue: 0x1A/255)
    static let cardFill = Color(red: 0xF0/255, green: 0xF0/255, blue: 0xEE/255)
    static let cardBorder = Color(red: 0xE0/255, green: 0xE0/255, blue: 0xE0/255)
    static let subtle = Color(red: 0x8A/255, green: 0x8A/255, blue: 0x8A/255)
    static let accent = Color(red: 0x34/255, green: 0xC7/255, blue: 0x59/255)   // green active indicator
}

private struct AnimatedGIFView: NSViewRepresentable {
    let data: Data

    func makeNSView(context: Context) -> NSView {
        let container = NSView()
        container.wantsLayer = true
        container.layer?.masksToBounds = true

        let imageView = NSImageView()
        imageView.animates = true
        imageView.imageScaling = .scaleProportionallyDown
        imageView.imageAlignment = .alignCenter
        imageView.translatesAutoresizingMaskIntoConstraints = false
        imageView.setContentCompressionResistancePriority(.defaultLow, for: .horizontal)
        imageView.setContentCompressionResistancePriority(.defaultLow, for: .vertical)

        container.addSubview(imageView)
        NSLayoutConstraint.activate([
            imageView.topAnchor.constraint(equalTo: container.topAnchor),
            imageView.bottomAnchor.constraint(equalTo: container.bottomAnchor),
            imageView.leadingAnchor.constraint(equalTo: container.leadingAnchor),
            imageView.trailingAnchor.constraint(equalTo: container.trailingAnchor),
        ])
        return container
    }

    func updateNSView(_ nsView: NSView, context: Context) {
        guard let imageView = nsView.subviews.first as? NSImageView else { return }
        imageView.image = NSImage(data: data)
    }
}

private struct GIFCyclerView: View {
    @State private var currentIndex = 0

    private let gifData = Self.loadGIFData()
    private let timer = Timer.publish(every: 8, on: .main, in: .common).autoconnect()

    var body: some View {
        ZStack {
            if let currentGIF {
                AnimatedGIFView(data: currentGIF)
                    .id(currentIndex)
                    .transition(.opacity)
            }
        }
        .animation(.easeInOut(duration: 0.6), value: currentIndex)
        .onReceive(timer) { _ in
            guard gifData.count > 1 else { return }
            currentIndex = (currentIndex + 1) % gifData.count
        }
    }

    private var currentGIF: Data? {
        guard !gifData.isEmpty else { return nil }
        return gifData[currentIndex]
    }

    private static func loadGIFData() -> [Data] {
        ["illus_2", "illus_3", "illus_4"].compactMap { name in
            guard let url = Bundle.main.url(forResource: name, withExtension: "gif") else {
                return nil
            }

            return try? Data(contentsOf: url)
        }
    }
}

// MARK: - Content root

private struct SystemSettingsContentView: View {
    let initialTab: SettingsTab
    let onClose: () -> Void
    @State private var tab: SettingsTab

    init(initialTab: SettingsTab = .general, onClose: @escaping () -> Void) {
        self.initialTab = initialTab
        self.onClose = onClose
        self._tab = State(initialValue: initialTab)
    }

    var body: some View {
        // IMPORTANT: clipShape BEFORE overlay so the rounded corners actually
        // cut both opaque surface fills, then the overlay border is stroked
        // on the clipped edge on top.
        // Putting shadow OUTSIDE the clip so it isn't cut off.
        HStack(spacing: 0) {
            sidebar
            detail
        }
        .frame(width: 720, height: 560)
        .clipShape(RoundedRectangle(cornerRadius: 16))
        .overlay(
            RoundedRectangle(cornerRadius: 16)
                .strokeBorder(Theme.cardBorder, lineWidth: 0.5)
        )
        .shadow(color: .black.opacity(0.5), radius: 30, y: 12)
    }

    // MARK: Sidebar

    private var sidebar: some View {
        VStack(alignment: .leading, spacing: 0) {
            // Title
            HStack(spacing: 6) {
                Image(systemName: "gearshape.fill")
                    .font(.system(size: 13))
                    .foregroundColor(Theme.sidebarText.opacity(0.75))
                Text(L10n.systemSettings)
                    .font(.system(size: 13, weight: .semibold))
                    .foregroundColor(Theme.sidebarText.opacity(0.9))
            }
            .padding(.horizontal, 14)
            .padding(.top, 18)
            .padding(.bottom, 14)

            // Tab list
            ForEach(SettingsTab.allCases) { t in
                tabRow(t)
            }

            Spacer()

            GIFCyclerView()
                .frame(height: 140)
                .clipped()
                .padding(.horizontal, 12)
                .padding(.bottom, 16)
                .opacity(0.8)

            // Close button at bottom
            Button {
                onClose()
            } label: {
                HStack(spacing: 6) {
                    Image(systemName: "xmark.circle.fill")
                        .font(.system(size: 12))
                    Text(L10n.back)
                        .font(.system(size: 12, weight: .medium))
                }
                .foregroundColor(Theme.sidebarText.opacity(0.55))
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(.horizontal, 14)
                .padding(.vertical, 10)
            }
            .buttonStyle(.plain)
        }
        .frame(width: 180)
        .background(Theme.sidebarFill)
    }

    @ViewBuilder
    private func tabRow(_ t: SettingsTab) -> some View {
        let isSelected = tab == t
        Button {
            withAnimation(.easeOut(duration: 0.15)) { tab = t }
        } label: {
            HStack(spacing: 10) {
                Image(systemName: t.icon)
                    .font(.system(size: 12))
                    .frame(width: 18)
                Text(t.label)
                    .font(.system(size: 12, weight: isSelected ? .semibold : .medium))
                Spacer(minLength: 0)
            }
            .foregroundColor(isSelected ? Theme.sidebarSelectedText : Theme.sidebarText.opacity(0.78))
            .padding(.horizontal, 12)
            .padding(.vertical, 7)
            .background(
                RoundedRectangle(cornerRadius: 8)
                    .fill(isSelected ? Theme.sidebarSelected : Color.clear)
            )
            .padding(.horizontal, 8)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
    }

    // MARK: Detail

    @ViewBuilder
    private var detail: some View {
        ScrollView(.vertical, showsIndicators: false) {
            VStack(alignment: .leading, spacing: 16) {
                Text(tab.label)
                    .font(.system(size: 20, weight: .bold))
                    .foregroundColor(Theme.detailText.opacity(0.95))
                    .padding(.top, 18)

                switch tab {
                case .general:       GeneralTab()
                case .appearance:    AppearanceTab()
                case .notifications: NotificationsTab()
                case .behavior:      BehaviorTab()
                case .plugins:       NativePluginStoreView()
                case .codelight:     CodeLightTab()
                case .advanced:      AdvancedTab()
                case .about:         AboutTab()
                }
            }
            .padding(.horizontal, 22)
            .padding(.bottom, 22)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(Theme.detailFill)
        .environment(\.colorScheme, .light)
    }
}

// MARK: - Reusable tab-level primitives

/// A bordered card container used by each tab to group related controls.
/// Dark theme: translucent white fill over the detail panel, thin border.
private struct SettingsCard<Content: View>: View {
    let title: String?
    @ViewBuilder let content: Content

    init(title: String? = nil, @ViewBuilder content: () -> Content) {
        self.title = title
        self.content = content()
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            if let title {
                Text(title)
                    .font(.system(size: 10, weight: .semibold))
                    .textCase(.uppercase)
                    .tracking(0.6)
                    .foregroundColor(Theme.subtle)
            }
            VStack(alignment: .leading, spacing: 8) {
                content
            }
            .padding(12)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(
                RoundedRectangle(cornerRadius: 10)
                    .fill(Theme.cardFill)
                    .overlay(
                        RoundedRectangle(cornerRadius: 10)
                            .strokeBorder(Theme.cardBorder, lineWidth: 0.5)
                    )
            )
        }
    }
}

/// Toggle cell styled for the Workspace Mono detail surface.
private struct TabToggle: View {
    let icon: String
    let label: String
    let isOn: Bool
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            HStack(spacing: 10) {
                Image(systemName: icon)
                    .font(.system(size: 12))
                    .foregroundColor(Theme.detailText.opacity(isOn ? 0.9 : 0.5))
                    .frame(width: 16)
                Text(label)
                    .font(.system(size: 12, weight: isOn ? .semibold : .medium))
                    .foregroundColor(Theme.detailText.opacity(isOn ? 0.95 : 0.7))
                Spacer(minLength: 0)
                Circle()
                    .fill(isOn ? Theme.accent : Theme.subtle.opacity(0.3))
                    .frame(width: 7, height: 7)
            }
            .padding(.horizontal, 10)
            .padding(.vertical, 8)
            .background(
                RoundedRectangle(cornerRadius: 7)
                    .fill(isOn ? Theme.sidebarSelected.opacity(0.06) : Theme.cardFill)
            )
            .overlay(
                RoundedRectangle(cornerRadius: 7)
                    .strokeBorder(isOn ? Theme.sidebarSelected.opacity(0.15) : Theme.cardBorder, lineWidth: 0.5)
            )
        }
        .buttonStyle(.plain)
    }
}

// MARK: - General tab

private struct GeneralTab: View {
    @State private var hooksInstalled = HookInstaller.isInstalled()
    @State private var launchAtLogin = SMAppService.mainApp.status == .enabled
    @ObservedObject private var codexGate = CodexFeatureGate.shared

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            SettingsCard {
                LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible())], spacing: 8) {
                    TabToggle(icon: "power", label: L10n.launchAtLogin, isOn: launchAtLogin) {
                        do {
                            if launchAtLogin {
                                try SMAppService.mainApp.unregister()
                                launchAtLogin = false
                            } else {
                                try SMAppService.mainApp.register()
                                launchAtLogin = true
                            }
                        } catch {}
                    }
                    TabToggle(icon: "arrow.triangle.2.circlepath", label: L10n.hooks, isOn: hooksInstalled) {
                        if hooksInstalled {
                            HookInstaller.uninstall()
                            hooksInstalled = false
                        } else {
                            HookInstaller.installIfNeeded()
                            hooksInstalled = true
                        }
                    }
                    TabToggle(icon: "terminal.fill", label: L10n.codexSupport, isOn: codexGate.isEnabled) {
                        codexGate.isEnabled.toggle()
                    }
                }
            }

            SettingsCard(title: L10n.tr("Anthropic API Proxy", "Anthropic API 代理")) {
                AnthropicProxyRow()
            }

            SettingsCard(title: L10n.language) {
                LanguageRow()
            }

            SettingsCard(title: L10n.accessibility) {
                AccessibilityRow(isEnabled: AXIsProcessTrusted())
            }
        }
    }
}

/// Text field for configuring an HTTP(S) proxy used only for Anthropic's
/// usage API (RateLimitMonitor). Leave empty to connect directly.
private struct AnthropicProxyRow: View {
    @AppStorage("anthropicProxyURL") private var proxyURL: String = ""

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            TextField("http://127.0.0.1:7890", text: $proxyURL)
                .textFieldStyle(.plain)
                .font(.system(size: 12, design: .monospaced))
                .foregroundColor(.white.opacity(0.95))
                .padding(.horizontal, 10)
                .padding(.vertical, 8)
                .background(
                    RoundedRectangle(cornerRadius: 7)
                        .fill(Color.white.opacity(0.05))
                )
                .overlay(
                    RoundedRectangle(cornerRadius: 7)
                        .strokeBorder(Color.white.opacity(0.12), lineWidth: 0.5)
                )

            Text(L10n.tr(
                "Applied only to api.anthropic.com (usage / rate limit). Your own sync server stays direct. Leave empty to connect directly.",
                "仅用于 api.anthropic.com（用量 / 额度查询）。CodeLight 同步服务器始终直连。留空即直连。"
            ))
            .font(.system(size: 10))
            .foregroundColor(.white.opacity(0.5))
            .fixedSize(horizontal: false, vertical: true)
        }
    }
}

// MARK: - Appearance tab

private struct AppearanceTab: View {
    @ObservedObject private var screenSelector = ScreenSelector.shared
    @AppStorage("showGroupedSessions") private var showGrouped: Bool = false
    @AppStorage("usePixelCat") private var usePixelCat: Bool = false

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            SettingsCard(title: L10n.screen) {
                ScreenPickerRow(screenSelector: screenSelector)
            }

            SettingsCard {
                LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible())], spacing: 8) {
                    TabToggle(icon: "cat", label: L10n.pixelCatMode, isOn: usePixelCat) { usePixelCat.toggle() }
                    TabToggle(icon: "folder", label: L10n.groupByProject, isOn: showGrouped) { showGrouped.toggle() }
                }
            }

            // Notch customization — theme, font size, visibility,
            // hardware mode, and the live edit entry button.
            SettingsCard(title: L10n.notchSectionHeader) {
                NotchCustomizationSettingsView()
            }
        }
    }
}

// MARK: - Notifications tab

private struct NotificationsTab: View {
    @ObservedObject private var soundSelector = SoundSelector.shared
    @AppStorage("usageWarningThreshold") private var usageWarningThreshold: Int = 90

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            SettingsCard(title: L10n.notificationSound) {
                SoundPickerRow(soundSelector: soundSelector)
            }
            SettingsCard(title: L10n.usageWarningThreshold) {
                ThresholdPickerRow(threshold: $usageWarningThreshold)
            }
        }
    }
}

// MARK: - Behavior tab

private struct BehaviorTab: View {
    @AppStorage("smartSuppression") private var smartSuppression: Bool = true
    @AppStorage("autoCollapseOnMouseLeave") private var autoCollapseOnMouseLeave: Bool = true
    @AppStorage("compactCollapsed") private var compactCollapsed: Bool = false

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            SettingsCard {
                LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible())], spacing: 8) {
                    TabToggle(icon: "eye.slash", label: L10n.smartSuppression, isOn: smartSuppression) { smartSuppression.toggle() }
                    TabToggle(icon: "rectangle.compress.vertical", label: L10n.autoCollapseOnMouseLeave, isOn: autoCollapseOnMouseLeave) { autoCollapseOnMouseLeave.toggle() }
                    TabToggle(icon: "rectangle.arrowtriangle.2.inward", label: L10n.compactCollapsed, isOn: compactCollapsed) { compactCollapsed.toggle() }
                }
            }
        }
    }
}

// MARK: - CodeLight tab (Pair iPhone + Launch Presets merged)

private struct CodeLightTab: View {
    @ObservedObject private var syncManager = SyncManager.shared

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            SettingsCard(title: L10n.pairedIPhones) {
                HStack(spacing: 10) {
                    Image(systemName: syncManager.isEnabled
                          ? "iphone.radiowaves.left.and.right"
                          : "iphone.slash")
                        .font(.system(size: 14))
                        .foregroundColor(syncManager.isEnabled
                                         ? Theme.sidebarSelected
                                         : Theme.subtle)
                        .frame(width: 18)

                    VStack(alignment: .leading, spacing: 2) {
                        if let url = syncManager.serverUrl,
                           !url.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                            Text(URL(string: url)?.host ?? url)
                                .font(.system(size: 12, weight: .medium))
                                .foregroundColor(Theme.detailText.opacity(0.9))
                            Text(syncManager.isEnabled
                                 ? (L10n.isChinese ? "在线" : "Online")
                                 : (L10n.isChinese ? "未连接" : "Not connected"))
                                .font(.system(size: 10))
                                .foregroundColor(Theme.subtle)
                        } else {
                            Text(L10n.isChinese ? "尚未配置服务器" : "No server configured")
                                .font(.system(size: 12, weight: .medium))
                                .foregroundColor(Theme.detailText.opacity(0.7))
                        }
                    }

                    Spacer()

                    Button {
                        QRPairingWindow.shared.show()
                    } label: {
                        HStack(spacing: 5) {
                            Image(systemName: "qrcode")
                                .font(.system(size: 11))
                            Text(L10n.pairNewPhone)
                                .font(.system(size: 11, weight: .semibold))
                        }
                        .foregroundColor(.black)
                        .padding(.horizontal, 10)
                        .padding(.vertical, 6)
                        .background(
                            RoundedRectangle(cornerRadius: 7)
                                .fill(Theme.sidebarFill)
                        )
                    }
                    .buttonStyle(.plain)
                }
            }

            SettingsCard(title: L10n.launchPresetsSection) {
                PresetsListContent(textStyle: .darkOnLight(true))
                    .frame(minHeight: 280)
            }
        }
    }
}

// MARK: - Advanced tab

private struct AdvancedTab: View {
    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            SettingsCard(title: L10n.clearEndedSessions) {
                Button {
                    Task { await SessionStore.shared.process(.clearEndedSessions) }
                } label: {
                    HStack(spacing: 8) {
                        Image(systemName: "trash")
                            .font(.system(size: 11))
                        Text(L10n.clearEnded)
                            .font(.system(size: 12, weight: .medium))
                        Spacer()
                    }
                    .foregroundColor(Theme.detailText.opacity(0.85))
                    .padding(.horizontal, 12)
                    .padding(.vertical, 9)
                    .background(
                        RoundedRectangle(cornerRadius: 8)
                            .fill(Theme.cardFill)
                            .overlay(
                                RoundedRectangle(cornerRadius: 8)
                                    .strokeBorder(Theme.cardBorder, lineWidth: 0.5)
                            )
                    )
                }
                .buttonStyle(.plain)
            }
        }
    }
}

// MARK: - About tab

private struct AboutTab: View {
    private var version: String {
        let v = Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? "1.0"
        let b = Bundle.main.infoDictionary?["CFBundleVersion"] as? String ?? "1"
        return "\(v) (\(b))"
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            SettingsCard {
                HStack {
                    Text(L10n.version)
                        .font(.system(size: 12, weight: .semibold))
                        .foregroundColor(Theme.detailText.opacity(0.9))
                    Spacer()
                    Text(version)
                        .font(.system(size: 12, design: .monospaced))
                        .foregroundColor(Theme.detailText.opacity(0.6))
                }
            }

            SettingsCard {
                HStack(spacing: 8) {
                    Button {
                        NSWorkspace.shared.open(URL(string: "https://github.com/xmqywx/CodeIsland")!)
                    } label: {
                        aboutLinkButton(icon: "star.fill", label: L10n.starOnGitHub)
                    }
                    .buttonStyle(.plain)

                    Button {
                        NSWorkspace.shared.open(URL(string: "https://github.com/xmqywx/CodeIsland/issues")!)
                    } label: {
                        aboutLinkButton(icon: "bubble.left", label: L10n.feedback)
                    }
                    .buttonStyle(.plain)
                }
            }

            // Plugin marketplace promo card
            SettingsCard {
                HStack(spacing: 10) {
                    Image(systemName: "sparkles")
                        .font(.system(size: 16))
                        .foregroundColor(Theme.sidebarSelected)
                    VStack(alignment: .leading, spacing: 2) {
                        Text(L10n.pluginMarketplaceTitle)
                            .font(.system(size: 12, weight: .semibold))
                            .foregroundColor(Theme.detailText.opacity(0.9))
                        Text(L10n.pluginMarketplaceDesc)
                            .font(.system(size: 10))
                            .foregroundColor(Theme.detailText.opacity(0.55))
                            .lineLimit(2)
                    }
                    Spacer()
                    Button {
                        NSWorkspace.shared.open(URL(string: "https://miomio.chat/plugins")!)
                    } label: {
                        HStack(spacing: 4) {
                            Text(L10n.pluginMarketplaceOpen)
                                .font(.system(size: 11, weight: .semibold))
                            Image(systemName: "arrow.up.right")
                                .font(.system(size: 9, weight: .bold))
                        }
                        .foregroundColor(.white)
                        .padding(.horizontal, 10)
                        .padding(.vertical, 6)
                        .background(
                            RoundedRectangle(cornerRadius: 6)
                                .fill(Theme.sidebarSelected)
                        )
                    }
                    .buttonStyle(.plain)
                }
            }

            SettingsCard {
                HStack {
                    Image(systemName: "message.fill")
                        .font(.system(size: 12))
                        .foregroundColor(Theme.detailText.opacity(0.6))
                    Text(L10n.wechatLabel)
                        .font(.system(size: 12))
                        .foregroundColor(Theme.detailText.opacity(0.8))
                    Spacer()
                    Text("A115939")
                        .font(.system(size: 12, design: .monospaced))
                        .foregroundColor(Theme.detailText.opacity(0.55))
                        .textSelection(.enabled)
                }
            }

            Text(L10n.maintainedTagline)
                .font(.system(size: 11))
                .foregroundColor(Theme.detailText.opacity(0.5))
                .frame(maxWidth: .infinity, alignment: .center)
                .padding(.top, 4)
        }
    }

    private func aboutLinkButton(icon: String, label: String) -> some View {
        HStack(spacing: 6) {
            Image(systemName: icon)
                .font(.system(size: 12))
            Text(label)
                .font(.system(size: 12, weight: .semibold))
        }
        .foregroundColor(.black)
        .frame(maxWidth: .infinity)
        .padding(.vertical, 8)
        .background(
            RoundedRectangle(cornerRadius: 8)
                .fill(Theme.sidebarFill)
        )
    }
}
