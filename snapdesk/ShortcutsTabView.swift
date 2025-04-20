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
    
    init() {
        _config = State(initialValue: ConfigurationManager.shared.loadConfig() ?? ConfigurationManager.shared.getDefaultConfig())
    }
    
    private var generalShortcuts: [ShortcutItem] {
        config.generalShortcuts.map { shortcut in
            ShortcutItem(
                name: shortcut.name,
                shortcut: shortcut.shortcut,
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
            Task {
                await loadApps()
                refreshConfig()
            }
        }
        .navigationTitle("Shortcuts")
    }

    private func loadApps() async {
        isLoading = true
        apps = await Task.detached(priority: .userInitiated) {
            fetchInstalledApps()
        }.value
        
        // Update apps with their shortcuts from config
        for (index, app) in apps.enumerated() {
            if let shortcut = config.appShortcuts.first(where: { $0.bundleIdentifier == app.bundleIdentifier })?.shortcut {
                apps[index].shortcut = shortcut
            }
        }
        
        isLoading = false
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
        if let index = config.generalShortcuts.firstIndex(where: { $0.name == name }) {
            config.generalShortcuts[index].shortcut = nil
            saveConfig()
            refreshConfig()
        }
    }
    
    private func clearAppShortcut(for bundleIdentifier: String) {
        if let index = config.appShortcuts.firstIndex(where: { $0.bundleIdentifier == bundleIdentifier }) {
            config.appShortcuts[index].shortcut = nil
            saveConfig()
            refreshConfig()
        }
    }
    
    private func saveConfig() {
        try? configManager.saveConfig(config)
    }
    
    private func findShortcutConflict(shortcut: ShortcutConfig, currentName: String) -> String? {
        // Check general shortcuts
        for generalShortcut in config.generalShortcuts {
            if generalShortcut.name != currentName &&
               generalShortcut.shortcut.key == shortcut.key &&
               generalShortcut.shortcut.modifiers == shortcut.modifiers {
                return generalShortcut.name
            }
        }
        
        // Check app shortcuts
        for appShortcut in config.appShortcuts {
            if appShortcut.bundleIdentifier != currentName &&
               appShortcut.shortcut.key == shortcut.key &&
               appShortcut.shortcut.modifiers == shortcut.modifiers {
                if let app = apps.first(where: { $0.bundleIdentifier == appShortcut.bundleIdentifier }) {
                    return app.name
                }
                return appShortcut.bundleIdentifier
            }
        }
        
        return nil
    }
}

#Preview {
    ShortcutsTabView()
} 