//
//  ConfigurationManager.swift
//  snapdesk
//
//  Created by Pedro Knup on 20/04/2025.
//

import Foundation
import Yams

public struct ShortcutConfig: Codable {
    public var key: String
    public var modifiers: [String]
    
    public init(key: String, modifiers: [String]) {
        self.key = key
        self.modifiers = modifiers
    }
}

public struct AppShortcutConfig: Codable {
    public var bundleIdentifier: String
    public var shortcut: ShortcutConfig?
    
    public init(bundleIdentifier: String, shortcut: ShortcutConfig?) {
        self.bundleIdentifier = bundleIdentifier
        self.shortcut = shortcut
    }
}

public struct GeneralShortcutConfig: Codable {
    public var name: String
    public var shortcut: ShortcutConfig
    
    public init(name: String, shortcut: ShortcutConfig) {
        self.name = name
        self.shortcut = shortcut
    }
}

public struct Config: Codable {
    public var appShortcuts: [AppShortcutConfig]
    public var generalShortcuts: [GeneralShortcutConfig]
    
    public init(appShortcuts: [AppShortcutConfig], generalShortcuts: [GeneralShortcutConfig]) {
        self.appShortcuts = appShortcuts
        self.generalShortcuts = generalShortcuts
    }
}

public class ConfigurationManager {
    public static let shared = ConfigurationManager()
    private let configPath: URL
    
    private init() {
        let homeDirectory = FileManager.default.homeDirectoryForCurrentUser
        let configDirectory = homeDirectory.appendingPathComponent(".config")
        let snapdeskDirectory = configDirectory.appendingPathComponent("snapdesk")
        configPath = snapdeskDirectory.appendingPathComponent("config.yaml")
        
        // Create config directory if it doesn't exist
        try? FileManager.default.createDirectory(at: snapdeskDirectory, withIntermediateDirectories: true)
    }
    
    public func loadConfig() -> Config? {
        guard let data = try? Data(contentsOf: configPath),
              let config = try? YAMLDecoder().decode(Config.self, from: data) else {
            return nil
        }
        return config
    }
    
    public func saveConfig(_ config: Config) throws {
        let string = try YAMLEncoder().encode(config)
        let data = Data(string.utf8)
        try data.write(to: configPath, options: [.atomic])
    }

    
    public func getDefaultConfig() -> Config {
        return Config(
            appShortcuts: [
                AppShortcutConfig(
                    bundleIdentifier: "company.thebrowser.Browser",
                    shortcut: ShortcutConfig(key: "1", modifiers: ["command", "option"])
                ),
                AppShortcutConfig(
                    bundleIdentifier: "com.googlecode.iterm2",
                    shortcut: ShortcutConfig(key: "6", modifiers: ["command", "option"])
                ),
                AppShortcutConfig(
                    bundleIdentifier: "com.googlecode.iterm2",
                    shortcut: ShortcutConfig(key: "5", modifiers: ["command", "option"])
                ),
                AppShortcutConfig(
                    bundleIdentifier: "notion.id",
                    shortcut: ShortcutConfig(key: "3", modifiers: ["command", "option"])
                ),
                AppShortcutConfig(
                    bundleIdentifier: "com.apple.dt.Xcode",
                    shortcut: ShortcutConfig(key: "f", modifiers: ["command", "option"])
                ),
                AppShortcutConfig(
                    bundleIdentifier: "com.spotify.client",
                    shortcut: ShortcutConfig(key: "9", modifiers: ["command", "option"])
                )
            ],
            generalShortcuts: [
                GeneralShortcutConfig(
                    name: "Toggle Full Screen layout for the current screen",
                    shortcut: ShortcutConfig(key: "0", modifiers: ["command", "option"])
                ),
                GeneralShortcutConfig(
                    name: "Remove current window from layout",
                    shortcut: ShortcutConfig(key: "2", modifiers: ["command", "option"])
                ),
                // Focus Screen shortcuts
                GeneralShortcutConfig(
                    name: "Focus Screen 1",
                    shortcut: ShortcutConfig(key: "1", modifiers: ["command", "control"])
                ),
                GeneralShortcutConfig(
                    name: "Focus Screen 2",
                    shortcut: ShortcutConfig(key: "2", modifiers: ["command", "control"])
                ),
                GeneralShortcutConfig(
                    name: "Focus Screen 3",
                    shortcut: ShortcutConfig(key: "3", modifiers: ["command", "control"])
                ),
                GeneralShortcutConfig(
                    name: "Focus Screen 4",
                    shortcut: ShortcutConfig(key: "4", modifiers: ["command", "control"])
                ),
                GeneralShortcutConfig(
                    name: "Focus Screen 5",
                    shortcut: ShortcutConfig(key: "5", modifiers: ["command", "control"])
                ),
                GeneralShortcutConfig(
                    name: "Focus Screen 6",
                    shortcut: ShortcutConfig(key: "6", modifiers: ["command", "control"])
                ),
                // Throw to Screen shortcuts
                GeneralShortcutConfig(
                    name: "Throw to Screen 1",
                    shortcut: ShortcutConfig(key: "1", modifiers: ["command", "shift"])
                ),
                GeneralShortcutConfig(
                    name: "Throw to Screen 2",
                    shortcut: ShortcutConfig(key: "2", modifiers: ["command", "shift"])
                ),
                GeneralShortcutConfig(
                    name: "Throw to Screen 3",
                    shortcut: ShortcutConfig(key: "3", modifiers: ["command", "shift"])
                ),
                GeneralShortcutConfig(
                    name: "Throw to Screen 4",
                    shortcut: ShortcutConfig(key: "4", modifiers: ["command", "shift"])
                ),
                GeneralShortcutConfig(
                    name: "Throw to Screen 5",
                    shortcut: ShortcutConfig(key: "5", modifiers: ["command", "shift"])
                ),
                GeneralShortcutConfig(
                    name: "Throw to Screen 6",
                    shortcut: ShortcutConfig(key: "6", modifiers: ["command", "shift"])
                ),
                // Layout management shortcuts
                GeneralShortcutConfig(
                    name: "Throw app to current layout modifier",
                    shortcut: ShortcutConfig(key: "t", modifiers: ["command", "option"])
                ),
                GeneralShortcutConfig(
                    name: "Increase main panel count",
                    shortcut: ShortcutConfig(key: "=", modifiers: ["command", "option"])
                ),
                GeneralShortcutConfig(
                    name: "Decrease main panel count",
                    shortcut: ShortcutConfig(key: "-", modifiers: ["command", "option"])
                ),
                GeneralShortcutConfig(
                    name: "Cycle current layout windows clockwise",
                    shortcut: ShortcutConfig(key: "]", modifiers: ["command", "option"])
                ),
                GeneralShortcutConfig(
                    name: "Cycle current layout windows counterclockwise",
                    shortcut: ShortcutConfig(key: "[", modifiers: ["command", "option"])
                )
            ]
        )
    }
}
