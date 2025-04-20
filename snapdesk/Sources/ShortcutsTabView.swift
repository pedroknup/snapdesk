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
        VStack(spacing: 0) {
            // Search bar at the top
            HStack {
                Image(systemName: "magnifyingglass")
                    .foregroundColor(.gray)
                
                TextField("Search shortcuts and applications...", text: $searchText)
                    .textFieldStyle(.plain)
                
                if !searchText.isEmpty {
                    Button(action: {
                        searchText = ""
                    }) {
                        Image(systemName: "xmark.circle.fill")
                            .foregroundColor(.gray)
                    }
                    .buttonStyle(.plain)
                }
            }
            .padding(8)
            .background(Color(.textBackgroundColor))
            .cornerRadius(8)
            .padding(.horizontal)
            .padding(.top, 8)
            
            // Main content
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
                        ProgressView("Loading applications...")
                            .frame(maxWidth: .infinity)
                    } else if filteredApps.isEmpty && !searchText.isEmpty {
                        Text("No applications match your search")
                            .foregroundColor(.gray)
                            .italic()
                            .padding(.vertical, 8)
                    } else {
                        ForEach(filteredApps) { app in
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
                                
                                ShortcutRecorder(shortcut: Binding(
                                    get: { app.shortcut },
                                    set: { newShortcut in
                                        if let newShortcut = newShortcut {
                                            // Add or update shortcut
                                            if let index = config.appShortcuts.firstIndex(where: { $0.bundleIdentifier == app.bundleIdentifier }) {
                                                config.appShortcuts[index].shortcut = newShortcut
                                            } else {
                                                config.appShortcuts.append(AppShortcutConfig(
                                                    bundleIdentifier: app.bundleIdentifier,
                                                    shortcut: newShortcut
                                                ))
                                            }
                                        } else {
                                            // Remove shortcut
                                            config.appShortcuts.removeAll { $0.bundleIdentifier == app.bundleIdentifier }
                                        }
                                        saveConfig()
                                        
                                        // Update the app's shortcut in the apps array
                                        if let appIndex = apps.firstIndex(where: { $0.bundleIdentifier == app.bundleIdentifier }) {
                                            apps[appIndex].shortcut = newShortcut
                                        }
                                        
                                        // Trigger UI refresh
                                        refreshTrigger.toggle()
                                    }
                                ))
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
        config.appShortcuts.removeAll { $0.bundleIdentifier == bundleIdentifier }
        saveConfig()
    }
    
    private func saveConfig() {
        try? configManager.saveConfig(config)
    }
}

#Preview {
    ShortcutsTabView()
}
