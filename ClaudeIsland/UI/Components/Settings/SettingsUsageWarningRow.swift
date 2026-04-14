//
//  SettingsUsageWarningRow.swift
//  ClaudeIsland
//
//  Settings-only usage warning threshold row (not notch UI).
//

import SwiftUI

struct SettingsUsageWarningRow: View {
    @Binding var threshold: Int

    private let options: [(value: Int, label: String)] = [
        (70, "70%"),
        (80, "80%"),
        (90, "90%"),
        (0, L10n.off),
    ]

    var body: some View {
        SettingsSegmentedChoiceRow(
            icon: "gauge.with.needle",
            title: L10n.alertThreshold,
            options: options,
            selection: $threshold
        )
    }
}

