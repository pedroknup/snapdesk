//
//  ConfigurationManager.swift
//  snapdesk
//
//  Created by Pedro Knup on 20/04/2025.
//

import Foundation
import Cocoa
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
    public var shortcut: ShortcutConfig?
    
    public init(name: String, shortcut: ShortcutConfig?) {
        self.name = name
        self.shortcut = shortcut
    }
}

public struct WindowPreviewConfig: Codable {
    public var enabled: Bool
    public var maxWidth: CGFloat
    public var maxHeight: CGFloat
    public var cacheTimeoutSeconds: TimeInterval
    
    public init(enabled: Bool = true, maxWidth: CGFloat = 200, maxHeight: CGFloat = 150, cacheTimeoutSeconds: TimeInterval = 5.0) {
        self.enabled = enabled
        self.maxWidth = maxWidth
        self.maxHeight = maxHeight
        self.cacheTimeoutSeconds = cacheTimeoutSeconds
    }
}

public struct ThemeConfig: Codable {
    public var accentColorRed: CGFloat
    public var accentColorGreen: CGFloat
    public var accentColorBlue: CGFloat
    public var accentColorAlpha: CGFloat
    public var activeWindowBorderWidth: CGFloat
    public var inactiveWindowOpacity: CGFloat
    
    public init(
        accentColorRed: CGFloat = 0.007,
        accentColorGreen: CGFloat = 0.478,
        accentColorBlue: CGFloat = 1.0,
        accentColorAlpha: CGFloat = 1.0,
        activeWindowBorderWidth: CGFloat = 2.0,
        inactiveWindowOpacity: CGFloat = 0.85
    ) {
        self.accentColorRed = accentColorRed
        self.accentColorGreen = accentColorGreen
        self.accentColorBlue = accentColorBlue
        self.accentColorAlpha = accentColorAlpha
        self.activeWindowBorderWidth = activeWindowBorderWidth
        self.inactiveWindowOpacity = inactiveWindowOpacity
    }
    
    public var accentColor: NSColor {
        return NSColor(red: accentColorRed, green: accentColorGreen, blue: accentColorBlue, alpha: accentColorAlpha)
    }
}

public struct Config: Codable {
    public var appShortcuts: [AppShortcutConfig]
    public var generalShortcuts: [GeneralShortcutConfig]
    public var windowPreview: WindowPreviewConfig
    public var theme: ThemeConfig
    
    public init(appShortcuts: [AppShortcutConfig], generalShortcuts: [GeneralShortcutConfig], windowPreview: WindowPreviewConfig = WindowPreviewConfig(), theme: ThemeConfig = ThemeConfig()) {
        self.appShortcuts = appShortcuts
        self.generalShortcuts = generalShortcuts
        self.windowPreview = windowPreview
        self.theme = theme
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
              let yamlString = String(data: data, encoding: .utf8) else {
            return nil
        }
//        print("Loading config from YAML.")
        guard var config = try? YAMLDecoder().decode(Config.self, from: data) else {
            return nil
        }
        
        // Define the only supported general shortcuts (in logical order)
        let defaultGeneralShortcuts = [
            // Layout management
            "Toggle layout for current WindowSet",
            "Show layout visualization",
            "Expand Windows",
            "Remove current window from layout",
            "Throw app to current layout modifier",
            
            // Panel size management
            "Increase main panel size",
            "Decrease main panel size",
            
            // Window positioning
            "Position Window Left",
            "Position Window Right", 
            "Position Window Top",
            "Position Window Bottom",
            "Position Window Top Left",
            "Position Window Top Right",
            "Position Window Bottom Left",
            "Position Window Bottom Right",
            "Position Window Center",
            
            // Window reordering
            "Move Window Up in Layout",
            "Move Window Down in Layout",
            
            // Screen focus
            "Focus Screen 1",
            "Focus Screen 2",
            "Focus Screen 3",
            "Focus Screen 4",
            "Focus Screen 5",
            "Focus Screen 6",
            
            // Throw to screen
            "Throw to Screen 1",
            "Throw to Screen 2",
            "Throw to Screen 3",
            "Throw to Screen 4",
            "Throw to Screen 5",
            "Throw to Screen 6"
        ]
        
        // Convert to Set for efficient lookup
        let supportedNames = Set(defaultGeneralShortcuts)
        
        // Filter out any unsupported shortcuts from the config file
        config.generalShortcuts = config.generalShortcuts.filter { supportedNames.contains($0.name) }
        
        // Create a set of existing shortcut names after filtering
        let existingNames = Set(config.generalShortcuts.map { $0.name })
        
        // Add any missing shortcuts with nil values
        for name in defaultGeneralShortcuts {
            if !existingNames.contains(name) {
                config.generalShortcuts.append(GeneralShortcutConfig(name: name, shortcut: nil))
            }
        }
        
        return config
    }
    
    public func saveConfig(_ config: Config) throws {
        // Create a new config that includes all general shortcuts, even those with nil values
        var configToSave = config
        
        // Define the only supported general shortcuts (in logical order)
        let defaultGeneralShortcuts = [
            // Layout management
            "Toggle layout for current WindowSet",
            "Show layout visualization",
            "Expand Windows",
            "Remove current window from layout",
            "Throw app to current layout modifier",
            
            // Panel size management
            "Increase main panel size",
            "Decrease main panel size",
            
            // Window positioning
            "Position Window Left",
            "Position Window Right", 
            "Position Window Top",
            "Position Window Bottom",
            "Position Window Top Left",
            "Position Window Top Right",
            "Position Window Bottom Left",
            "Position Window Bottom Right",
            "Position Window Center",
            
            // Window reordering
            "Move Window Up in Layout",
            "Move Window Down in Layout",
            
            // Screen focus
            "Focus Screen 1",
            "Focus Screen 2",
            "Focus Screen 3",
            "Focus Screen 4",
            "Focus Screen 5",
            "Focus Screen 6",
            
            // Throw to screen
            "Throw to Screen 1",
            "Throw to Screen 2",
            "Throw to Screen 3",
            "Throw to Screen 4",
            "Throw to Screen 5",
            "Throw to Screen 6"
        ]
        
        // Convert to Set for efficient lookup
        let supportedNames = Set(defaultGeneralShortcuts)
        
        // Filter out any unsupported shortcuts before saving
        configToSave.generalShortcuts = configToSave.generalShortcuts.filter { supportedNames.contains($0.name) }
        
        // Create a set of existing shortcut names after filtering
        let existingNames = Set(configToSave.generalShortcuts.map { $0.name })
        
        // Add any missing shortcuts with nil values
        for name in defaultGeneralShortcuts {
            if !existingNames.contains(name) {
                configToSave.generalShortcuts.append(GeneralShortcutConfig(name: name, shortcut: nil))
            }
        }
        
        let string = try YAMLEncoder().encode(configToSave)
        print("Saving config to YAML:\n\(string)")
        let data = Data(string.utf8)
        try data.write(to: configPath, options: [.atomic])
    }

    
    public func getDefaultConfig() -> Config {
        return Config(
            appShortcuts: [
                AppShortcutConfig(
                    bundleIdentifier: "company.thebrowser.Browser",
                    shortcut: nil
                ),
                AppShortcutConfig(
                    bundleIdentifier: "com.googlecode.iterm2",
                    shortcut: ShortcutConfig(key: "6", modifiers: ["command", "option"])
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
                    name: "Remove current window from layout",
                    shortcut: ShortcutConfig(key: "2", modifiers: ["command", "option"])
                ),
                GeneralShortcutConfig(
                    name: "Toggle layout for current WindowSet",
                    shortcut: ShortcutConfig(key: "l", modifiers: ["command", "option"])
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
                    name: "Increase main panel size",
                    shortcut: ShortcutConfig(key: "=", modifiers: ["command", "option"])
                ),
                GeneralShortcutConfig(
                    name: "Decrease main panel size",
                    shortcut: ShortcutConfig(key: "-", modifiers: ["command", "option"])
                ),
                GeneralShortcutConfig(
                    name: "Expand Windows",
                    shortcut: nil  // No default shortcut, user can configure it
                ),
                // Window reordering shortcuts
                GeneralShortcutConfig(
                    name: "Move Window Up in Layout",
                    shortcut: ShortcutConfig(key: "up", modifiers: ["command", "option"])
                ),
                GeneralShortcutConfig(
                    name: "Move Window Down in Layout",
                    shortcut: ShortcutConfig(key: "down", modifiers: ["command", "option"])
                )
            ]
        )
    }
}
