//
//  AvailableKeysModel.swift
//  snapdesk
//
//  Created by Pedro Knup on 16/09/2025.
//

import Foundation
import SwiftUI

public struct KeyAvailability: Identifiable {
    public let id = UUID()
    public let key: String
    public let isAvailable: Bool
    public let displayName: String

    public init(key: String, isAvailable: Bool, displayName: String? = nil) {
        self.key = key
        self.isAvailable = isAvailable
        self.displayName = displayName ?? key.uppercased()
    }
}

public class AvailableKeysModel: ObservableObject {
    @Published public var availableKeys: [KeyAvailability] = []
    @Published public var usedKeys: Set<String> = []

    private let allKeys: [String] = [
        // Numbers
        "0", "1", "2", "3", "4", "5", "6", "7", "8", "9",
        // Letters
        "a", "b", "c", "d", "e", "f", "g", "h", "i", "j", "k", "l", "m",
        "n", "o", "p", "q", "r", "s", "t", "u", "v", "w", "x", "y", "z"
    ]

    public init() {
        // Initialize with all keys as available
        self.availableKeys = allKeys.map { key in
            KeyAvailability(
                key: key,
                isAvailable: true,
                displayName: key.uppercased()
            )
        }
    }

    public func updateAvailability(from config: Config) {
        // Collect all used keys from app shortcuts
        var used = Set<String>()

        // Add keys from app shortcuts
        for appShortcut in config.appShortcuts {
            if let shortcut = appShortcut.shortcut {
                used.insert(shortcut.key.lowercased())
            }
        }

        // Add keys from general shortcuts
        for generalShortcut in config.generalShortcuts {
            if let shortcut = generalShortcut.shortcut {
                used.insert(shortcut.key.lowercased())
            }
        }

        self.usedKeys = used

        // Update availability for each key
        self.availableKeys = allKeys.map { key in
            KeyAvailability(
                key: key,
                isAvailable: !used.contains(key),
                displayName: key.uppercased()
            )
        }
    }

    public var availableNumbers: [KeyAvailability] {
        availableKeys.filter { $0.key.first?.isNumber == true }
    }

    public var availableLetters: [KeyAvailability] {
        availableKeys.filter { $0.key.first?.isLetter == true }
    }

    public var availableCount: Int {
        availableKeys.filter { $0.isAvailable }.count
    }

    public var usedCount: Int {
        availableKeys.filter { !$0.isAvailable }.count
    }
}
