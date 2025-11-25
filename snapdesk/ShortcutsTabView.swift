//
//  ShotcutsView.swift
//  snapdesk
//
//  Created by Pedro Knup on 20/04/2025.
//

import SwiftUI
import AppKit
import HotKey

// Import ConfigurationManager directly
import Swift

struct AppInfo: Identifiable {
    let id = UUID()
    let name: String
    let bundleIdentifier: String
    let icon: NSImage
    var shortcut: ShortcutConfig? = nil
}

// Add Codable conformance to AppInfo for serialization
struct AppInfoCodable: Codable {
    let name: String
    let bundleIdentifier: String
    let iconData: Data?
    
    init(from appInfo: AppInfo) {
        self.name = appInfo.name
        self.bundleIdentifier = appInfo.bundleIdentifier
        self.iconData = appInfo.icon.tiffRepresentation
    }
}

// Add a structure to hold the cached data with timestamp
struct CachedAppsData: Codable {
    let timestamp: Date
    let apps: [AppInfoCodable]
}

struct ShortcutItem: Identifiable {
    let id = UUID()
    let name: String
    var shortcut: ShortcutConfig? = nil
    let action: () -> Void
}

struct ShortcutsTabView: View {
    @State private var apps: [AppInfo] = []
    @State private var isLoading = true
    @State private var config: Config
    private let configManager = ConfigurationManager.shared
    private let tempAppsFilePath = "/tmp/snapdesk_apps.json"
    // Cache expiration time (24 hours)
    private let cacheExpirationInterval: TimeInterval = 24 * 60 * 60
    
    // Define the fixed list of general shortcuts
    private let defaultGeneralShortcuts: [String] = [
        "Remove current window from layout",
        "Toggle layout for current WindowSet",
        "Focus Screen 1",
        "Focus Screen 2",
        "Focus Screen 3",
        "Focus Screen 4",
        "Focus Screen 5",
        "Focus Screen 6",
        "Throw to Screen 1",
        "Throw to Screen 2",
        "Throw to Screen 3",
        "Throw to Screen 4",
        "Throw to Screen 5",
        "Throw to Screen 6",
        "Throw app to current layout modifier",
        "Increase main panel size",
        "Decrease main panel size"
    ]
    
    init() {
        _config = State(initialValue: ConfigurationManager.shared.loadConfig() ?? ConfigurationManager.shared.getDefaultConfig())
    }
    
    private var generalShortcuts: [ShortcutItem] {
        // Create a dictionary of configured shortcuts by name
        let configuredShortcuts = Dictionary(uniqueKeysWithValues: 
            config.generalShortcuts.map { ($0.name, $0.shortcut) }
        )
        
        // Create the fixed list of shortcuts, using configured values if available
        return defaultGeneralShortcuts.map { name in
            let shortcut = configuredShortcuts[name]
            // Check if the shortcut is empty (cleared)
            let isCleared = shortcut?.key.isEmpty == true && shortcut?.modifiers.isEmpty == true
            
            return ShortcutItem(
                name: name,
                shortcut: isCleared ? nil : shortcut,
                action: {}
            )
        }
    }

    var body: some View {
        List {
            Section("General") {
                ForEach(generalShortcuts) { shortcut in
                    HStack {
                        Text(shortcut.name)
                        Spacer()
                        if let definedShortcut = shortcut.shortcut {
                            HStack(spacing: 8) {
                                Text(formatShortcut(definedShortcut))
                                    .foregroundColor(.gray)
                                if let conflict = findShortcutConflict(shortcut: definedShortcut, currentName: shortcut.name) {
                                    Image(systemName: "exclamationmark.triangle.fill")
                                        .foregroundColor(.yellow)
                                        .help("This shortcut is already used by: \(conflict)")
                                }
                                Button(action: {
                                    clearShortcut(for: shortcut.name)
                                }) {
                                    Image(systemName: "trash")
                                        .foregroundColor(.gray)
                                }
                                .buttonStyle(.borderless)
                                .help("Clear shortcut")
                            }
                        } else {
                            Button("Configure") {
                                // TODO: Implement shortcut configuration
                            }
                            .buttonStyle(.borderless)
                        }
                    }
                    .padding(.vertical, 4)
                }
            }
            
            Section("Applications") {
                if isLoading {
                    ProgressView("Loading applications...")
                        .frame(maxWidth: .infinity)
                } else {
                    ForEach(apps) { app in
                        HStack {
                            Image(nsImage: app.icon)
                                .resizable()
                                .frame(width: 32, height: 32)
                                .cornerRadius(6)

                            VStack(alignment: .leading) {
                                Text(app.name).font(.headline)
                                Text(app.bundleIdentifier).font(.caption).foregroundColor(.gray)
                            }
                            
                            Spacer()
                            
                            if let definedShortcut = app.shortcut {
                                HStack(spacing: 8) {
                                    Text(formatShortcut(definedShortcut))
                                        .foregroundColor(.gray)
                                    if let conflict = findShortcutConflict(shortcut: definedShortcut, currentName: app.bundleIdentifier) {
                                        Image(systemName: "exclamationmark.triangle.fill")
                                            .foregroundColor(.yellow)
                                            .help("This shortcut is already used by: \(conflict)")
                                    }
                                    Button(action: {
                                        clearAppShortcut(for: app.bundleIdentifier)
                                    }) {
                                        Image(systemName: "trash")
                                            .foregroundColor(.gray)
                                    }
                                    .buttonStyle(.borderless)
                                    .help("Clear shortcut")
                                }
                            } else {
                                Button("Configure") {
                                    // TODO: Implement shortcut configuration
                                }
                                .buttonStyle(.borderless)
                            }
                        }
                        .padding(.vertical, 4)
                    }
                }
            }
        }
        .onAppear {
            loadApps()
            refreshConfig()
        }
        .navigationTitle("Shortcuts")
    }

    private func loadApps() {
        // Run cache loading on background thread to avoid blocking UI
        DispatchQueue.global(qos: .userInitiated).async {
            let cachedApps = loadAppsFromCache()
            let cacheTimestamp = getCacheTimestamp()

            DispatchQueue.main.async {
                if let cachedApps = cachedApps {
                    apps = cachedApps
                    isLoading = false
                    updateAppsWithShortcuts()

                    // Check if cache is expired, refresh in background without loading indicator
                    if let cacheTimestamp = cacheTimestamp,
                       Date().timeIntervalSince(cacheTimestamp) > cacheExpirationInterval {
                        refreshAppsInBackground()
                    }
                } else {
                    // No cache exists, show loading and fetch
                    isLoading = true
                    refreshAppsInBackground()
                }
            }
        }
    }

    private func refreshAppsInBackground() {
        DispatchQueue.global(qos: .userInitiated).async {
            let freshApps = fetchInstalledApps()

            DispatchQueue.main.async {
                apps = freshApps
                updateAppsWithShortcuts()
                saveAppsToCache(apps)
                isLoading = false
            }
        }
    }

    private func updateAppsWithShortcuts() {
        for (index, app) in apps.enumerated() {
            if let shortcut = config.appShortcuts.first(where: { $0.bundleIdentifier == app.bundleIdentifier })?.shortcut {
                apps[index].shortcut = shortcut
            }
        }
    }
    
    private func saveAppsToCache(_ apps: [AppInfo]) {
        do {
            let appInfoCodables = apps.map { AppInfoCodable(from: $0) }
            let cachedData = CachedAppsData(timestamp: Date(), apps: appInfoCodables)
            let encoder = JSONEncoder()
            let data = try encoder.encode(cachedData)
            try data.write(to: URL(fileURLWithPath: tempAppsFilePath))
        } catch {
            print("Failed to save apps to cache: \(error)")
        }
    }
    
    private func loadAppsFromCache() -> [AppInfo]? {
        do {
            let data = try Data(contentsOf: URL(fileURLWithPath: tempAppsFilePath))
            let decoder = JSONDecoder()
            let cachedData = try decoder.decode(CachedAppsData.self, from: data)
            
            return cachedData.apps.map { codable in
                let icon = codable.iconData.flatMap { NSImage(data: $0) } ?? NSImage()
                return AppInfo(
                    name: codable.name,
                    bundleIdentifier: codable.bundleIdentifier,
                    icon: icon
                )
            }
        } catch {
            print("Failed to load apps from cache: \(error)")
            return nil
        }
    }
    
    private func getCacheTimestamp() -> Date? {
        do {
            let data = try Data(contentsOf: URL(fileURLWithPath: tempAppsFilePath))
            let decoder = JSONDecoder()
            let cachedData = try decoder.decode(CachedAppsData.self, from: data)
            return cachedData.timestamp
        } catch {
            return nil
        }
    }

    private func fetchInstalledApps() -> [AppInfo] {
        let appPaths = FileManager.default.urls(for: .applicationDirectory, in: .localDomainMask)
        var results: [AppInfo] = []

        if let appsURL = appPaths.first {
            let enumerator = FileManager.default.enumerator(at: appsURL, includingPropertiesForKeys: nil)
            while let fileURL = enumerator?.nextObject() as? URL {
                if fileURL.pathExtension == "app" {
                    let name = fileURL.deletingPathExtension().lastPathComponent
                    let icon = NSWorkspace.shared.icon(forFile: fileURL.path)
                    
                    let bundle = Bundle(url: fileURL)
                    let bundleIdentifier = bundle?.bundleIdentifier ?? "Unknown Bundle ID"
                    
                    results.append(AppInfo(
                        name: name,
                        bundleIdentifier: bundleIdentifier,
                        icon: icon
                    ))
                }
            }
        }

        return results.sorted { $0.name.lowercased() < $1.name.lowercased() }
    }
    
    private func formatShortcut(_ shortcut: ShortcutConfig) -> String {
        // Check if the shortcut is empty (cleared)
        if shortcut.key.isEmpty && shortcut.modifiers.isEmpty {
            return "No shortcut"
        }
        
        let modifiers = shortcut.modifiers.map { $0.capitalized }.joined(separator: " + ")
        return "\(modifiers) + \(shortcut.key.uppercased())"
    }
    
    private func refreshConfig() {
        if let loadedConfig = configManager.loadConfig() {
            config = loadedConfig
            // Update apps with their shortcuts from the refreshed config
            for (index, app) in apps.enumerated() {
                if let shortcut = config.appShortcuts.first(where: { $0.bundleIdentifier == app.bundleIdentifier })?.shortcut {
                    apps[index].shortcut = shortcut
                } else {
                    apps[index].shortcut = nil
                }
            }
        } else {
            config = configManager.getDefaultConfig()
        }
    }
    
    private func clearShortcut(for name: String) {
        // Find if the shortcut already exists in the config
        if let index = config.generalShortcuts.firstIndex(where: { $0.name == name }) {
            // Update the existing entry with an empty shortcut
            config.generalShortcuts[index] = GeneralShortcutConfig(
                name: name, 
                shortcut: ShortcutConfig(key: "", modifiers: [])
            )
        } else {
            // Add a new entry with an empty shortcut
            config.generalShortcuts.append(GeneralShortcutConfig(
                name: name, 
                shortcut: ShortcutConfig(key: "", modifiers: [])
            ))
        }
        
        saveConfig()
        refreshConfig()
    }
    
    private func clearAppShortcut(for bundleIdentifier: String) {
        // Find if the shortcut already exists in the config
        if let index = config.appShortcuts.firstIndex(where: { $0.bundleIdentifier == bundleIdentifier }) {
            // Update the existing entry with an empty shortcut
            config.appShortcuts[index] = AppShortcutConfig(
                bundleIdentifier: bundleIdentifier, 
                shortcut: ShortcutConfig(key: "", modifiers: [])
            )
        } else {
            // Add a new entry with an empty shortcut
            config.appShortcuts.append(AppShortcutConfig(
                bundleIdentifier: bundleIdentifier, 
                shortcut: ShortcutConfig(key: "", modifiers: [])
            ))
        }
        
        saveConfig()
        refreshConfig()
    }
    
    private func saveConfig() {
        try? configManager.saveConfig(config)
    }
    
    private func findShortcutConflict(shortcut: ShortcutConfig, currentName: String) -> String? {
        // Check general shortcuts
        for generalShortcut in config.generalShortcuts {
            if generalShortcut.name != currentName &&
               generalShortcut.shortcut?.key == shortcut.key &&
               generalShortcut.shortcut?.modifiers == shortcut.modifiers {
                return generalShortcut.name
            }
        }
        
        // Check app shortcuts
        for appShortcut in config.appShortcuts {
            if appShortcut.bundleIdentifier != currentName &&
               appShortcut.shortcut?.key == shortcut.key &&
               appShortcut.shortcut?.modifiers == shortcut.modifiers {
                if let app = apps.first(where: { $0.bundleIdentifier == appShortcut.bundleIdentifier }) {
                    return app.name
                }
                return appShortcut.bundleIdentifier
            }
        }
        
        return nil
    }
    
    private func isClearedShortcut(_ shortcut: ShortcutConfig) -> Bool {
        return shortcut.key.isEmpty && shortcut.modifiers.isEmpty
    }
}

#Preview {
    ShortcutsTabView()
} 