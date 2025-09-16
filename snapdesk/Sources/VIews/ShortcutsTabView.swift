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

struct AppInfo: Identifiable, Codable {
    let id = UUID()
    let name: String
    let bundleIdentifier: String
    var shortcut: ShortcutConfig? = nil
    
    // Icon is not Codable, so we handle it separately
    var icon: NSImage? = nil
    
    enum CodingKeys: String, CodingKey {
        case id, name, bundleIdentifier, shortcut
    }
}

struct ShortcutItem: Identifiable {
    let id = UUID()
    let name: String
    var shortcut: ShortcutConfig? = nil
    let action: () -> Void
}

struct ShortcutsTabView: View {
    @State private var apps: [AppInfo] = []
    @State private var isLoading = false // Changed to false initially
    @State private var isRefreshing = false
    @State private var config: Config
    @State private var searchText: String = ""
    @State private var refreshTrigger: Bool = false
    @StateObject private var availableKeysModel = AvailableKeysModel()
    private let configManager = ConfigurationManager.shared
    private let cacheManager = AppCacheManager.shared
    
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
            .padding(.bottom, 8)
            
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
                            ModernShortcutRow(
                                title: shortcut.name,
                                subtitle: nil,
                                icon: nil,
                                showIcon: false,
                                shortcut: Binding(
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
                                            updateAvailableKeys()
                                        }
                                    }
                                )
                            )
                        }
                    }
                }

                Section("Applications") {
                    // Help text explaining shortcut behavior
                    VStack(alignment: .leading, spacing: 4) {
                        Text("Application Shortcuts:")
                            .font(.caption)
                            .fontWeight(.semibold)
                            .foregroundColor(.primary)
                        Text("• Base shortcut: Focus app / cycle forward through windows")
                            .font(.caption)
                            .foregroundColor(.secondary)
                        Text("• + Shift: Add current window to layout")
                            .font(.caption)
                            .foregroundColor(.secondary)
                        Text("")
                            .font(.caption)
                        Text("Use 'Cycle Current App Backward' in General shortcuts to cycle backward through the currently active app's windows.")
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                    .padding(.horizontal, 4)
                    .padding(.vertical, 8)

                    if isLoading && apps.isEmpty {
                        ProgressView("Loading applications...")
                            .frame(maxWidth: .infinity)
                    } else if filteredApps.isEmpty && !searchText.isEmpty {
                        Text("No applications match your search")
                            .foregroundColor(.gray)
                            .italic()
                            .padding(.vertical, 8)
                    } else {
                        ForEach(filteredApps) { app in
                            ModernShortcutRow(
                                title: app.name,
                                subtitle: app.bundleIdentifier,
                                icon: app.icon,
                                shortcut: Binding(
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
                                        updateAvailableKeys()
                                    }
                                )
                            )
                        }
                    }
                }
            }

            // Available keys view at the bottom
            AvailableKeysView(keysModel: availableKeysModel)
                .padding(.horizontal)
                .padding(.bottom, 8)
        }
        .onAppear {
            loadAppsWithCache()
            updateAvailableKeys()
        }
        .onChange(of: refreshTrigger) {
            // This will trigger a UI refresh when refreshTrigger changes
        }
        .navigationTitle("Shortcuts")
    }

    private func loadAppsWithCache() {
        // First, load from cache immediately if available
        if let cachedApps = cacheManager.getCachedApps() {
            self.apps = cachedApps
            updateAppsWithShortcuts()
        } else {
            // No cache, show loading indicator
            isLoading = true
        }
        
        // Then fetch fresh data in background
        Task {
            await refreshAppsInBackground()
        }
    }
    
    private func refreshAppsInBackground() async {
        isRefreshing = true
        
        let freshApps = fetchInstalledApps()
        
        // Update UI on main thread
        await MainActor.run {
            // Only update if data has changed or we didn't have cached data
            if apps.isEmpty || hasAppsChanged(old: apps, new: freshApps) {
                self.apps = freshApps
                updateAppsWithShortcuts()
                
                // Save to cache
                cacheManager.setCachedApps(freshApps)
            }
            
            isLoading = false
            isRefreshing = false
        }
    }
    
    private func hasAppsChanged(old: [AppInfo], new: [AppInfo]) -> Bool {
        if old.count != new.count { return true }
        
        let oldSet = Set(old.map { $0.bundleIdentifier })
        let newSet = Set(new.map { $0.bundleIdentifier })
        
        return oldSet != newSet
    }
    
    private func updateAppsWithShortcuts() {
        // Update apps with their shortcuts from config
        for (index, app) in apps.enumerated() {
            if let shortcut = config.appShortcuts.first(where: { $0.bundleIdentifier == app.bundleIdentifier })?.shortcut {
                apps[index].shortcut = shortcut
            }
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
                    
                    var appInfo = AppInfo(
                        name: name,
                        bundleIdentifier: bundleIdentifier
                    )
                    appInfo.icon = icon
                    results.append(appInfo)
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
        // Notify the main app to reload hotkey configuration
        if let appDelegate = NSApplication.shared.delegate as? SnapdeskApp {
            appDelegate.reloadHotkeyConfiguration()
        }
    }

    private func updateAvailableKeys() {
        availableKeysModel.updateAvailability(from: config)
    }
}

struct ModernShortcutRow: View {
    let title: String
    let subtitle: String?
    let icon: NSImage?
    let showIcon: Bool
    @Binding var shortcut: ShortcutConfig?

    init(title: String, subtitle: String?, icon: NSImage?, showIcon: Bool = true, shortcut: Binding<ShortcutConfig?>) {
        self.title = title
        self.subtitle = subtitle
        self.icon = icon
        self.showIcon = showIcon
        self._shortcut = shortcut
    }

    private var hasShortcut: Bool {
        guard let shortcut = shortcut else { return false }
        return !shortcut.key.isEmpty || !shortcut.modifiers.isEmpty
    }

    var body: some View {
        HStack(spacing: 12) {
            // Icon section
            if showIcon {
                if let icon = icon {
                    Image(nsImage: icon)
                        .resizable()
                        .aspectRatio(contentMode: .fit)
                        .frame(width: 40, height: 40)
                        .clipShape(RoundedRectangle(cornerRadius: 8))
                        .overlay(
                            RoundedRectangle(cornerRadius: 8)
                                .stroke(Color.secondary.opacity(0.2), lineWidth: 0.5)
                        )
                } else {
                    RoundedRectangle(cornerRadius: 8)
                        .fill(Color.secondary.opacity(0.1))
                        .frame(width: 40, height: 40)
                        .overlay(
                            Image(systemName: "gear")
                                .foregroundColor(.secondary)
                                .font(.system(size: 16))
                        )
                }
            }

            // Title and subtitle section
            VStack(alignment: .leading, spacing: 2) {
                Text(title)
                    .font(.system(size: 14, weight: .medium))
                    .foregroundColor(.primary)
                    .lineLimit(1)

                if let subtitle = subtitle {
                    Text(subtitle)
                        .font(.system(size: 12))
                        .foregroundColor(.secondary)
                        .lineLimit(1)
                }
            }

            Spacer()

            // Shortcut display and configuration section
            HStack(spacing: 8) {
                if hasShortcut {
                    ModernShortcutDisplay(shortcut: shortcut)
                } else {
                    Text("No shortcut")
                        .font(.system(size: 12, weight: .medium))
                        .foregroundColor(.secondary.opacity(0.6))
                        .padding(.horizontal, 8)
                        .padding(.vertical, 4)
                        .background(Color.secondary.opacity(0.05))
                        .cornerRadius(6)
                }

                ModernShortcutRecorder(shortcut: $shortcut)
            }
        }
        .padding(.vertical, 8)
        .padding(.horizontal, 4)
        .background(
            RoundedRectangle(cornerRadius: 8)
                .fill(Color.clear)
                .contentShape(Rectangle())
        )
        .onHover { hovering in
            // Optional: Add hover effect
        }
    }
}

struct ModernShortcutDisplay: View {
    let shortcut: ShortcutConfig?

    private var shortcutComponents: [String] {
        guard let shortcut = shortcut else { return [] }

        var components: [String] = []

        // Add modifier symbols
        for modifier in shortcut.modifiers {
            switch modifier.lowercased() {
            case "command":
                components.append("⌘")
            case "option":
                components.append("⌥")
            case "shift":
                components.append("⇧")
            case "control":
                components.append("⌃")
            default:
                break
            }
        }

        // Add key
        if !shortcut.key.isEmpty {
            components.append(shortcut.key.uppercased())
        }

        return components
    }

    var body: some View {
        HStack(spacing: 2) {
            ForEach(Array(shortcutComponents.enumerated()), id: \.offset) { index, component in
                Text(component)
                    .font(.system(size: 16, weight: .semibold, design: .monospaced))
                    .foregroundColor(.primary)
                    .padding(.horizontal, 6)
                    .padding(.vertical, 3)
                    .background(
                        RoundedRectangle(cornerRadius: 4)
                            .fill(Color.accentColor.opacity(0.1))
                            .overlay(
                                RoundedRectangle(cornerRadius: 4)
                                    .stroke(Color.accentColor.opacity(0.3), lineWidth: 1)
                            )
                    )

                if index < shortcutComponents.count - 1 && component != shortcutComponents.last {
                    Text("+")
                        .font(.system(size: 14, weight: .medium))
                        .foregroundColor(.secondary)
                        .padding(.horizontal, 2)
                }
            }
        }
    }
}

struct ModernShortcutRecorder: View {
    @Binding var shortcut: ShortcutConfig?
    @State private var showingRecorder = false

    var body: some View {
        Button(action: {
            showingRecorder = true
        }) {
            Text("Set")
                .font(.system(size: 12, weight: .medium))
            .foregroundColor(.accentColor)
            .padding(.horizontal, 8)
            .padding(.vertical, 4)
            .background(
                RoundedRectangle(cornerRadius: 6)
                    .fill(Color.accentColor.opacity(0.1))
                    .overlay(
                        RoundedRectangle(cornerRadius: 6)
                            .stroke(Color.accentColor.opacity(0.3), lineWidth: 1)
                    )
            )
        }
        .buttonStyle(.plain)
        .popover(isPresented: $showingRecorder) {
            ModernShortcutRecorderPopover(shortcut: $shortcut, isPresented: $showingRecorder)
                .frame(width: 280, height: 120)
        }
    }
}

struct ModernShortcutRecorderPopover: View {
    @Binding var shortcut: ShortcutConfig?
    @Binding var isPresented: Bool
    @State private var isRecording = false
    @State private var currentModifiers: NSEvent.ModifierFlags = []
    @State private var currentKey: String?

    var body: some View {
        VStack(spacing: 16) {
            Text("Press a key combination")
                .font(.headline)
                .foregroundColor(.primary)

            HStack {
                if isRecording {
                    Text(formatCurrentKeys())
                        .font(.system(size: 16, weight: .semibold, design: .monospaced))
                        .foregroundColor(.accentColor)
                        .padding(.horizontal, 16)
                        .padding(.vertical, 8)
                        .background(
                            RoundedRectangle(cornerRadius: 8)
                                .fill(Color.accentColor.opacity(0.1))
                                .overlay(
                                    RoundedRectangle(cornerRadius: 8)
                                        .stroke(Color.accentColor.opacity(0.3), lineWidth: 1)
                                )
                        )
                } else {
                    Text("Click to start recording")
                        .font(.system(size: 14))
                        .foregroundColor(.secondary)
                        .padding(.horizontal, 16)
                        .padding(.vertical, 8)
                        .background(
                            RoundedRectangle(cornerRadius: 8)
                                .fill(Color.secondary.opacity(0.1))
                        )
                }
            }

            HStack(spacing: 12) {
                Button("Cancel") {
                    stopRecording()
                    isPresented = false
                }
                .buttonStyle(.borderless)

                Button("Clear") {
                    shortcut = ShortcutConfig(key: "", modifiers: [])
                    stopRecording()
                    isPresented = false
                }
                .buttonStyle(.borderless)
                .foregroundColor(.red)

                Button(isRecording ? "Stop" : "Start") {
                    if isRecording {
                        stopRecording()
                    } else {
                        startRecording()
                    }
                }
                .buttonStyle(.borderedProminent)
            }
        }
        .padding()
        .onAppear {
            setupEventMonitoring()
            startRecording()
        }
        .onDisappear {
            stopRecording()
        }
    }

    private func setupEventMonitoring() {
        NSEvent.addLocalMonitorForEvents(matching: .flagsChanged) { event in
            if isRecording {
                handleModifierChange(event)
                return nil
            }
            return event
        }

        NSEvent.addLocalMonitorForEvents(matching: .keyDown) { event in
            if isRecording {
                handleKeyDown(event)
                return nil
            }
            return event
        }
    }

    private func startRecording() {
        isRecording = true
        currentModifiers = []
        currentKey = nil
        HotkeyManager.pauseAllHotkeys()
    }

    private func stopRecording() {
        isRecording = false
        currentModifiers = []
        currentKey = nil
        HotkeyManager.resumeAllHotkeys()
    }

    private func handleModifierChange(_ event: NSEvent) {
        let modifiers = event.modifierFlags.intersection(.deviceIndependentFlagsMask)
        currentModifiers = modifiers

        if modifiers.isEmpty {
            currentKey = nil
        }
    }

    private func handleKeyDown(_ event: NSEvent) {
        let modifiers = event.modifierFlags.intersection(.deviceIndependentFlagsMask)
        currentModifiers = modifiers

        if let key = event.charactersIgnoringModifiers?.lowercased(), !key.isEmpty {
            currentKey = key

            var modifierStrings: [String] = []
            if modifiers.contains(.command) {
                modifierStrings.append("command")
            }
            if modifiers.contains(.option) {
                modifierStrings.append("option")
            }
            if modifiers.contains(.shift) {
                modifierStrings.append("shift")
            }
            if modifiers.contains(.control) {
                modifierStrings.append("control")
            }

            let newShortcut = ShortcutConfig(key: key, modifiers: modifierStrings)
            shortcut = newShortcut
            stopRecording()

            DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
                isPresented = false
            }
        }
    }

    private func formatCurrentKeys() -> String {
        var result = ""

        if currentModifiers.contains(.command) {
            result += "⌘ "
        }
        if currentModifiers.contains(.option) {
            result += "⌥ "
        }
        if currentModifiers.contains(.shift) {
            result += "⇧ "
        }
        if currentModifiers.contains(.control) {
            result += "⌃ "
        }

        if !result.isEmpty && currentKey != nil {
            result += " + "
        }

        if let key = currentKey {
            result += key.uppercased()
        } else if !result.isEmpty {
            result += "..."
        } else {
            result = "Press keys..."
        }

        return result
    }
}

#Preview {
    ShortcutsTabView()
}
