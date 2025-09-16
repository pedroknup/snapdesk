//
//  AvailableKeysView.swift
//  snapdesk
//
//  Created by Pedro Knup on 16/09/2025.
//

import SwiftUI

struct AvailableKeysView: View {
    @ObservedObject var keysModel: AvailableKeysModel
    @State private var isExpanded: Bool = false

    var body: some View {
        VStack(spacing: 0) {
            // Header with toggle - entire row is clickable
            Button(action: {
                withAnimation(.easeInOut(duration: 0.2)) {
                    isExpanded.toggle()
                }
            }) {
                HStack {
                    HStack(spacing: 6) {
                        Image(systemName: "keyboard")
                            .foregroundColor(.secondary)
                            .font(.system(size: 12, weight: .medium))

                        Text("Available Keys")
                            .font(.system(size: 12, weight: .medium))
                            .foregroundColor(.secondary)

                        Text("(\(keysModel.availableCount) free)")
                            .font(.system(size: 11))
                            .foregroundColor(.secondary)
                    }

                    Spacer()

                    Image(systemName: isExpanded ? "chevron.up" : "chevron.down")
                        .font(.system(size: 10, weight: .medium))
                        .foregroundColor(.secondary)
                }
                .padding(.horizontal, 12)
                .padding(.vertical, 8)
                .contentShape(Rectangle())
            }
            .buttonStyle(.plain)
            .background(Color(.controlBackgroundColor))
            .cornerRadius(6)

            // Expandable content
            if isExpanded {
                VStack(spacing: 0) {
                    Rectangle()
                        .fill(Color(.separatorColor))
                        .frame(height: 0.5)

                    VStack(alignment: .leading, spacing: 6) {
                        // All available keys together
                        if keysModel.availableCount > 0 {
                            VStack(alignment: .leading, spacing: 6) {
                                Text("Available Keys")
                                    .font(.system(size: 10, weight: .medium))
                                    .foregroundColor(.secondary)

                                LazyVGrid(columns: Array(repeating: GridItem(.flexible(), spacing: 6), count: 10), alignment: .leading, spacing: 6) {
                                    ForEach(keysModel.availableKeys.filter { $0.isAvailable }) { keyAvailability in
                                        KeyBadgeView(key: keyAvailability.displayName, isAvailable: keyAvailability.isAvailable)
                                    }
                                }
                            }
                        }

                        if keysModel.availableCount == 0 {
                            VStack(spacing: 4) {
                                Image(systemName: "checkmark.circle.fill")
                                    .foregroundColor(.green)
                                    .font(.system(size: 16))

                                Text("All keys are assigned")
                                    .font(.system(size: 11))
                                    .foregroundColor(.secondary)
                            }
                            .padding(.vertical, 8)
                        }
                    }
                    .padding(.horizontal, 12)
                    .padding(.vertical, 8)
                }
                .background(Color(.controlBackgroundColor))
                .cornerRadius(6)
            }
        }
        .background(Color(.controlBackgroundColor))
        .cornerRadius(6)
        .overlay(
            RoundedRectangle(cornerRadius: 6)
                .stroke(Color(.separatorColor), lineWidth: 0.5)
        )
    }
}

struct KeysSectionView: View {
    let title: String
    let keys: [KeyAvailability]
    let columns: Int

    private var availableKeys: [KeyAvailability] {
        keys.filter { $0.isAvailable }
    }

    var body: some View {
        if !availableKeys.isEmpty {
            VStack(alignment: .leading, spacing: 6) {
                Text(title)
                    .font(.system(size: 10, weight: .medium))
                    .foregroundColor(.secondary)

                LazyVGrid(columns: Array(repeating: GridItem(.flexible(), spacing: 4), count: columns), alignment: .leading, spacing: 4) {
                    ForEach(availableKeys) { keyAvailability in
                        KeyBadgeView(key: keyAvailability.displayName, isAvailable: keyAvailability.isAvailable)
                    }
                }
            }
        }
    }
}

struct KeyBadgeView: View {
    let key: String
    let isAvailable: Bool

    var body: some View {
        Text(key)
            .font(.system(size: 13, weight: .medium, design: .monospaced))
            .foregroundColor(isAvailable ? .primary : .secondary)
            .frame(width: 28, height: 28)
            .background(
                RoundedRectangle(cornerRadius: 5)
                    .fill(isAvailable ? Color(.quaternaryLabelColor) : Color(.tertiaryLabelColor).opacity(0.3))
            )
            .overlay(
                RoundedRectangle(cornerRadius: 5)
                    .stroke(Color(.separatorColor).opacity(0.5), lineWidth: 0.5)
            )
    }
}


#Preview {
    let model = AvailableKeysModel()
    // Simulate some used keys for preview
    let config = Config(
        appShortcuts: [
            AppShortcutConfig(bundleIdentifier: "test", shortcut: ShortcutConfig(key: "a", modifiers: ["command"]))
        ],
        generalShortcuts: [
            GeneralShortcutConfig(name: "test", shortcut: ShortcutConfig(key: "1", modifiers: ["command"]))
        ]
    )
    model.updateAvailability(from: config)

    return AvailableKeysView(keysModel: model)
        .frame(width: 400)
        .padding()
}