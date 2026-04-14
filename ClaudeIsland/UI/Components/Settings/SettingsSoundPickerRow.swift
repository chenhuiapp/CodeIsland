//
//  SettingsSoundPickerRow.swift
//  ClaudeIsland
//
//  Palette-driven notification sound picker for the settings window.
//  Preserves sound preview playback when selecting an option.
//

import AppKit
import SwiftUI

struct SettingsSoundPickerRow: View {
    @ObservedObject var soundSelector: SoundSelector
    @State private var selectedSound: NotificationSound = AppSettings.notificationSound

    private var isExpanded: Binding<Bool> {
        Binding(
            get: { soundSelector.isPickerExpanded },
            set: { soundSelector.isPickerExpanded = $0 }
        )
    }

    var body: some View {
        SettingsDisclosureRow(
            icon: "speaker.wave.2",
            title: L10n.notificationSound,
            currentValue: selectedSound.rawValue,
            isExpanded: isExpanded
        ) {
            ScrollView {
                VStack(spacing: 2) {
                    ForEach(NotificationSound.allCases, id: \.self) { sound in
                        SettingsSelectableOptionRow(
                            label: sound.rawValue,
                            sublabel: nil,
                            isSelected: selectedSound == sound
                        ) {
                            select(sound)
                        }
                    }
                }
            }
            .frame(maxHeight: soundSelector.expandedPickerHeight)
        }
        .onAppear {
            selectedSound = AppSettings.notificationSound
        }
    }

    private func select(_ sound: NotificationSound) {
        if let soundName = sound.soundName {
            NSSound(named: soundName)?.play()
        }
        selectedSound = sound
        AppSettings.notificationSound = sound
    }
}

