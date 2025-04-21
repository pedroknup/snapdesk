//
//  ShotcutsView.swift
//  snapdesk
//
//  Created by Pedro Knup on 20/04/2025.
//

import SwiftUI
import AppKit
import HotKey
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
    @State private var searchText: String = ""
    @State private var refreshTrigger: Bool = false
    private let configManager = ConfigurationManager.shared
    
    init() {
        _config = State(initialValue: ConfigurationManager.shared.loadConfig() ?? ConfigurationManager.shared.getDefaultConfig())
    }
    
    private var generalShortcuts: [ShortcutItem] {
        let shortcuts = config.generalShortcuts.map { shortcut in
            ShortcutItem(
                name: shortcut.name,
                shortcut: shortcut.shortcut,
                action: {}
            )
        }
        
        // Filter general shortcuts based on search text
        if searchText.isEmpty {
            return shortcuts
        } else {
            return shortcuts.filter { shortcut in
                shortcut.name.lowercased().contains(searchText.lowercased())
            }
        }
    }
    
    private var filteredApps: [AppInfo] {
        if searchText.isEmpty {
            return apps
        } else {
            return apps.filter { app in
                app.name.lowercased().contains(searchText.lowercased()) ||
                app.bundleIdentifier.lowercased().contains(searchText.lowercased())
            }
        }
    }

    var body: some View {
        VStack {
            // Add padding around the search bar
            TextField("Search shortcuts and applications...", text: .constant(""))
                .textFieldStyle(RoundedBorderTextFieldStyle())
                .padding(.horizontal)
                .padding(.top)
            
            List {
                Section("General") {
                    if generalShortcuts.isEmpty && !searchText.isEmpty {
                        Text("No general shortcuts match your search")
                            .foregroundColor(.gray)
                            .italic()
                            .padding(.vertical, 8)
                    } else {
                        ForEach(generalShortcuts) { shortcut in
                            HStack {
                                Text(shortcut.name)
                                Spacer()
                                ShortcutRecorder(shortcut: Binding(
                                    get: { shortcut.shortcut },
                                    set: { newShortcut in
                                        if let index = config.generalShortcuts.firstIndex(where: { $0.name == shortcut.name }) {
                                            if let newShortcut = newShortcut {
                                                config.generalShortcuts[index].shortcut = newShortcut
                                            } else {
                                                config.generalShortcuts.remove(at: index)
                                            }
                                            saveConfig()
                                            refreshTrigger.toggle()
                                        }
                                    }
                                ))
                            }
                            .padding(.vertical, 4)
                        }
                    }
                }
                
                
                Section("Applications") {
                    if isLoading {
                        // We'll fix this part below
                        VStack {
                            ProgressView("Loading applications...")
                        }
                        .frame(maxWidth: .infinity)
                        .padding(.vertical)
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
        }
    
        .onAppear {
            Task {
                await loadApps()
            }
        }
        .onChange(of: refreshTrigger) { _ in
            // This will trigger a UI refresh when refreshTrigger changes
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
    
    private func removeShortcut(for name: String) {
        config.generalShortcuts.removeAll { $0.name == name }
        saveConfig()
    }
    
    private func removeAppShortcut(for bundleIdentifier: String) {
        if let index = config.appShortcuts.firstIndex(where: { $0.bundleIdentifier == bundleIdentifier }) {
            config.appShortcuts[index].shortcut = nil
            saveConfig()
        }
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
    
}

#Preview {
    ShortcutsTabView()
}
