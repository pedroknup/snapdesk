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

// MARK: - Key-based shortcut grid

/// Keyboard rows shown in the assignment grid. The space bar is handled as its own row.
private let shortcutKeyRows: [[String]] = [
    ["1", "2", "3", "4", "5", "6", "7", "8", "9", "0"],
    ["q", "w", "e", "r", "t", "y", "u", "i", "o", "p"],
    ["a", "s", "d", "f", "g", "h", "j", "k", "l", ";"],
    ["z", "x", "c", "v", "b", "n", "m", ",", ".", "/"]
]
private let shortcutSpaceKey = "space"
private let allShortcutKeys: [String] = shortcutKeyRows.flatMap { $0 } + [shortcutSpaceKey]

/// Resolved display data for a key that has an application assigned to it.
struct KeyAssignmentDisplay {
    let bundleIdentifier: String
    let name: String
    let icon: NSImage?
    let shortcut: ShortcutConfig
}

func shortcutKeyDisplayName(_ key: String) -> String {
    key == shortcutSpaceKey ? "SPACE" : key.uppercased()
}

struct ShortcutsTabView: View {
    private enum ShortcutSection: String, CaseIterable {
        case applications = "Applications"
        case general = "General"
    }

    @State private var apps: [AppInfo] = []
    @State private var isLoading = false
    @State private var isRefreshing = false
    @State private var config: Config
    @State private var searchText: String = ""
    @State private var assignmentSearchText: String = ""
    @State private var selectedSection: ShortcutSection = .applications
    @State private var selectedKey: String? = nil
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

    var body: some View {
        VStack(spacing: 0) {
            Picker("", selection: $selectedSection) {
                ForEach(ShortcutSection.allCases, id: \.self) { section in
                    Text(section.rawValue).tag(section)
                }
            }
            .pickerStyle(.segmented)
            .labelsHidden()
            .frame(width: 240)
            .padding(.top, 10)
            .padding(.bottom, 6)

            Group {
                switch selectedSection {
                case .applications:
                    applicationsSection
                case .general:
                    generalSection
                }
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
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

    // MARK: - Applications (key grid)

    private var applicationsSection: some View {
        HStack(spacing: 0) {
            VStack(alignment: .leading, spacing: 0) {
                applicationsHeader

                Divider()

                ScrollView {
                    VStack(spacing: 8) {
                        ForEach(Array(shortcutKeyRows.enumerated()), id: \.offset) { _, row in
                            HStack(spacing: 8) {
                                ForEach(row, id: \.self) { key in
                                    keyTile(for: key)
                                }
                            }
                        }
                        keyTile(for: shortcutSpaceKey)
                    }
                    .padding(16)
                }
            }
            .frame(maxWidth: .infinity)

            Divider()

            KeyDetailSidebar(
                keyName: selectedKey,
                assignment: selectedKey.flatMap { assignmentDisplay(for: $0) },
                generalShortcutName: selectedKey.flatMap { generalKeyAssignments[$0] },
                apps: apps,
                assignedKeyByBundleId: assignedKeyByBundleId,
                recentBundleIds: recentBundleIds,
                onAssign: { bundleIdentifier in
                    guard let key = selectedKey else { return }
                    assign(bundleIdentifier, to: key)
                },
                onRemove: {
                    guard let key = selectedKey else { return }
                    removeAssignment(for: key)
                },
                onEditGeneral: {
                    if let key = selectedKey, let name = generalKeyAssignments[key] {
                        searchText = name
                    }
                    selectedSection = .general
                }
            )
            .frame(width: 250)
        }
    }

    private var applicationsHeader: some View {
        HStack(alignment: .top, spacing: 16) {
            VStack(alignment: .leading, spacing: 4) {
                Text("Shortcut Configuration")
                    .font(.system(size: 18, weight: .bold))
                Text("Assign applications to keyboard shortcuts. Press ⌥ Option + assigned key to launch the selected app. Add ⇧ Shift to throw the app into the current layout.")
                    .font(.system(size: 12))
                    .foregroundColor(.secondary)
                    .fixedSize(horizontal: false, vertical: true)
            }

            Spacer()

            VStack(alignment: .trailing, spacing: 6) {
                HStack(spacing: 4) {
                    Image(systemName: "magnifyingglass")
                        .foregroundColor(.secondary)
                        .font(.system(size: 11))
                    TextField("Search assignments", text: $assignmentSearchText)
                        .textFieldStyle(.plain)
                        .font(.system(size: 12))
                    if !assignmentSearchText.isEmpty {
                        Button(action: { assignmentSearchText = "" }) {
                            Image(systemName: "xmark.circle.fill")
                                .foregroundColor(.secondary)
                                .font(.system(size: 11))
                        }
                        .buttonStyle(.plain)
                    }
                }
                .padding(.horizontal, 8)
                .padding(.vertical, 5)
                .background(
                    RoundedRectangle(cornerRadius: 6)
                        .fill(Color(.textBackgroundColor))
                )
                .overlay(
                    RoundedRectangle(cornerRadius: 6)
                        .stroke(Color(.separatorColor).opacity(0.5), lineWidth: 0.5)
                )
                .frame(width: 200)

                Text("\(assignedCount) of \(allShortcutKeys.count) assigned")
                    .font(.system(size: 11))
                    .foregroundColor(.secondary)
            }
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 12)
    }

    private func keyTile(for key: String) -> some View {
        KeyTileView(
            keyName: key,
            assignment: assignmentDisplay(for: key),
            generalShortcutName: generalKeyAssignments[key],
            isSelected: selectedKey == key,
            isDimmed: isTileDimmed(key),
            action: { selectedKey = key }
        )
    }

    // MARK: - Key assignment helpers

    private func normalizeKey(_ key: String) -> String {
        let lowered = key.lowercased()
        return lowered == " " ? shortcutSpaceKey : lowered
    }

    /// Maps each grid key to the app shortcut currently occupying it (first match wins).
    private var keyAssignments: [String: AppShortcutConfig] {
        var map: [String: AppShortcutConfig] = [:]
        for appShortcut in config.appShortcuts {
            guard let shortcut = appShortcut.shortcut, !shortcut.key.isEmpty else { continue }
            let key = normalizeKey(shortcut.key)
            guard allShortcutKeys.contains(key), map[key] == nil else { continue }
            map[key] = appShortcut
        }
        return map
    }

    private var assignedKeyByBundleId: [String: String] {
        var map: [String: String] = [:]
        for (key, appShortcut) in keyAssignments where map[appShortcut.bundleIdentifier] == nil {
            map[appShortcut.bundleIdentifier] = key
        }
        return map
    }

    /// Keys occupied by a general shortcut bound to plain ⌥ + key — the same
    /// modifier scheme app shortcuts use, so these keys are not free.
    private var generalKeyAssignments: [String: String] {
        var map: [String: String] = [:]
        for generalShortcut in config.generalShortcuts {
            guard let shortcut = generalShortcut.shortcut, !shortcut.key.isEmpty else { continue }
            guard Set(shortcut.modifiers.map { $0.lowercased() }) == Set(["option"]) else { continue }
            let key = normalizeKey(shortcut.key)
            guard allShortcutKeys.contains(key), map[key] == nil else { continue }
            map[key] = generalShortcut.name
        }
        return map
    }

    private var assignedCount: Int {
        Set(keyAssignments.keys).union(generalKeyAssignments.keys).count
    }

    private func assignmentDisplay(for key: String) -> KeyAssignmentDisplay? {
        guard let appShortcut = keyAssignments[key], let shortcut = appShortcut.shortcut else { return nil }
        let info = appDisplayInfo(for: appShortcut.bundleIdentifier)
        return KeyAssignmentDisplay(
            bundleIdentifier: appShortcut.bundleIdentifier,
            name: info.name,
            icon: info.icon,
            shortcut: shortcut
        )
    }

    private func appDisplayInfo(for bundleIdentifier: String) -> (name: String, icon: NSImage?) {
        if let app = apps.first(where: { $0.bundleIdentifier == bundleIdentifier }) {
            return (app.name, app.icon)
        }
        if let url = NSWorkspace.shared.urlForApplication(withBundleIdentifier: bundleIdentifier) {
            return (url.deletingPathExtension().lastPathComponent, NSWorkspace.shared.icon(forFile: url.path))
        }
        return (bundleIdentifier, nil)
    }

    private func isTileDimmed(_ key: String) -> Bool {
        let query = assignmentSearchText.trimmingCharacters(in: .whitespaces).lowercased()
        guard !query.isEmpty else { return false }
        if shortcutKeyDisplayName(key).lowercased() == query { return false }
        guard let assignment = assignmentDisplay(for: key) else {
            if let generalName = generalKeyAssignments[key], generalName.lowercased().contains(query) {
                return false
            }
            return true
        }
        return !assignment.name.lowercased().contains(query)
            && !assignment.bundleIdentifier.lowercased().contains(query)
    }

    private func assign(_ bundleIdentifier: String, to key: String) {
        // A key holds a single app and an app lives on a single key:
        // clear the key's current occupant and any previous key for this app.
        config.appShortcuts.removeAll { appShortcut in
            guard let shortcut = appShortcut.shortcut else { return false }
            return normalizeKey(shortcut.key) == key
        }
        config.appShortcuts.removeAll { $0.bundleIdentifier == bundleIdentifier }
        config.appShortcuts.append(AppShortcutConfig(
            bundleIdentifier: bundleIdentifier,
            shortcut: ShortcutConfig(key: key, modifiers: ["option"])
        ))
        recordRecentAssignment(bundleIdentifier)
        saveConfig()
        refreshTrigger.toggle()
        updateAvailableKeys()
    }

    private static let recentAssignmentsKey = "com.snapdesk.recentlyAssignedApps"

    /// Recently assigned apps for the picker's RECENT row; falls back to
    /// currently running apps before any assignment has been made.
    private var recentBundleIds: [String] {
        let stored = UserDefaults.standard.stringArray(forKey: Self.recentAssignmentsKey) ?? []
        if !stored.isEmpty { return stored }
        return NSWorkspace.shared.runningApplications
            .filter { $0.activationPolicy == .regular }
            .compactMap { $0.bundleIdentifier }
    }

    private func recordRecentAssignment(_ bundleIdentifier: String) {
        var recents = UserDefaults.standard.stringArray(forKey: Self.recentAssignmentsKey) ?? []
        recents.removeAll { $0 == bundleIdentifier }
        recents.insert(bundleIdentifier, at: 0)
        UserDefaults.standard.set(Array(recents.prefix(8)), forKey: Self.recentAssignmentsKey)
    }

    private func removeAssignment(for key: String) {
        config.appShortcuts.removeAll { appShortcut in
            guard let shortcut = appShortcut.shortcut else { return false }
            return normalizeKey(shortcut.key) == key
        }
        saveConfig()
        refreshTrigger.toggle()
        updateAvailableKeys()
    }

    // MARK: - General shortcuts

    private var generalSection: some View {
        VStack(spacing: 0) {
            // Search bar at the top
            HStack {
                Image(systemName: "magnifyingglass")
                    .foregroundColor(.gray)

                TextField("Search shortcuts...", text: $searchText)
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
                                ),
                                keysModel: availableKeysModel
                            )
                        }
                    }
                }
            }
        }
    }

    private func loadAppsWithCache() {
        // First, load from cache immediately if available
        if let cachedApps = cacheManager.getCachedApps() {
            self.apps = cachedApps
            updateAppsWithShortcuts()
            isLoading = false

            // Fetch fresh data in background (no loading indicator)
            refreshAppsInBackground()
        } else {
            // No cache, show loading indicator
            isLoading = true

            // Fetch apps in background
            refreshAppsInBackground()
        }
    }

    private func refreshAppsInBackground() {
        isRefreshing = true

        // Run the heavy file system enumeration on a background queue
        DispatchQueue.global(qos: .userInitiated).async {
            let freshApps = self.fetchInstalledApps()

            // Update UI on main thread
            DispatchQueue.main.async {
                // Only update if data has changed or we didn't have cached data
                if self.apps.isEmpty || self.hasAppsChanged(old: self.apps, new: freshApps) {
                    self.apps = freshApps
                    self.updateAppsWithShortcuts()

                    // Save to cache
                    self.cacheManager.setCachedApps(freshApps)
                }

                self.isLoading = false
                self.isRefreshing = false
            }
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

// MARK: - Key tile

struct KeyTileView: View {
    let keyName: String
    let assignment: KeyAssignmentDisplay?
    let generalShortcutName: String?
    let isSelected: Bool
    let isDimmed: Bool
    let action: () -> Void

    private var isSpace: Bool { keyName == shortcutSpaceKey }

    var body: some View {
        Button(action: action) {
            VStack(alignment: .leading, spacing: 6) {
                if isSpace {
                    Text(shortcutKeyDisplayName(keyName))
                        .font(.system(size: 10, weight: .semibold))
                        .tracking(1.5)
                        .foregroundColor(.primary)
                } else {
                    Text(shortcutKeyDisplayName(keyName))
                        .font(.system(size: 14, weight: .semibold))
                        .foregroundColor(.primary)
                }

                Spacer(minLength: 2)

                if let assignment = assignment {
                    HStack(spacing: 4) {
                        if let icon = assignment.icon {
                            Image(nsImage: icon)
                                .resizable()
                                .aspectRatio(contentMode: .fit)
                                .frame(width: 14, height: 14)
                        }
                        Text(assignment.name)
                            .font(.system(size: 10))
                            .foregroundColor(.secondary)
                            .lineLimit(1)
                            .truncationMode(.tail)
                    }
                } else if let generalShortcutName = generalShortcutName {
                    HStack(spacing: 4) {
                        Image(systemName: "gearshape.fill")
                            .font(.system(size: 9))
                            .foregroundColor(.secondary)
                        Text(generalShortcutName)
                            .font(.system(size: 10))
                            .foregroundColor(.secondary)
                            .lineLimit(1)
                            .truncationMode(.tail)
                    }
                } else {
                    Text("Unassigned")
                        .font(.system(size: 10))
                        .foregroundColor(Color.secondary.opacity(0.55))
                        .lineLimit(1)
                        .truncationMode(.tail)
                }
            }
            .padding(8)
            .frame(maxWidth: .infinity, minHeight: isSpace ? 48 : 60, alignment: .topLeading)
            .background(
                RoundedRectangle(cornerRadius: 8)
                    .fill(isSelected ? Color.accentColor.opacity(0.08) : Color(.controlBackgroundColor))
            )
            .overlay(
                RoundedRectangle(cornerRadius: 8)
                    .stroke(isSelected ? Color.accentColor : Color(.separatorColor).opacity(0.7), lineWidth: isSelected ? 1.5 : 1)
            )
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .opacity(isDimmed ? 0.35 : 1.0)
    }
}

// MARK: - Key detail sidebar

struct KeyDetailSidebar: View {
    let keyName: String?
    let assignment: KeyAssignmentDisplay?
    let generalShortcutName: String?
    let apps: [AppInfo]
    let assignedKeyByBundleId: [String: String]
    let recentBundleIds: [String]
    let onAssign: (String) -> Void
    let onRemove: () -> Void
    let onEditGeneral: () -> Void

    @State private var showingAppPicker = false

    private var displayName: String {
        guard let keyName = keyName else { return "" }
        return shortcutKeyDisplayName(keyName)
    }

    /// True when the key is taken by an ⌥+key general shortcut (and no app),
    /// meaning it can only be edited from the General tab.
    private var isGeneralOccupied: Bool {
        assignment == nil && generalShortcutName != nil
    }

    var body: some View {
        Group {
            if keyName != nil {
                VStack(alignment: .leading, spacing: 20) {
                    HStack(spacing: 12) {
                        Text(displayName)
                            .font(.system(size: keyName == shortcutSpaceKey ? 11 : 20, weight: .semibold))
                            .frame(width: 48, height: 48)
                            .background(
                                RoundedRectangle(cornerRadius: 10)
                                    .fill(Color(.controlBackgroundColor))
                            )
                            .overlay(
                                RoundedRectangle(cornerRadius: 10)
                                    .stroke(Color(.separatorColor), lineWidth: 1)
                            )

                        VStack(alignment: .leading, spacing: 2) {
                            sectionCaption("KEY")
                            Text(displayName)
                                .font(.system(size: 13, weight: .medium))
                        }
                    }

                    VStack(alignment: .leading, spacing: 6) {
                        sectionCaption(isGeneralOccupied ? "GENERAL SHORTCUT" : "ASSIGNED APPLICATION")
                        HStack(spacing: 8) {
                            if let assignment = assignment {
                                if let icon = assignment.icon {
                                    Image(nsImage: icon)
                                        .resizable()
                                        .aspectRatio(contentMode: .fit)
                                        .frame(width: 20, height: 20)
                                }
                                VStack(alignment: .leading, spacing: 1) {
                                    Text(assignment.name)
                                        .font(.system(size: 12, weight: .medium))
                                        .lineLimit(1)
                                    Text(assignment.bundleIdentifier)
                                        .font(.system(size: 9, weight: .light))
                                        .foregroundColor(Color.secondary.opacity(0.7))
                                        .lineLimit(1)
                                        .truncationMode(.middle)
                                }
                            } else if let generalShortcutName = generalShortcutName {
                                Image(systemName: "gearshape.fill")
                                    .font(.system(size: 12))
                                    .foregroundColor(.secondary)
                                Text(generalShortcutName)
                                    .font(.system(size: 12, weight: .medium))
                                    .lineLimit(2)
                            } else {
                                Text("No application assigned")
                                    .font(.system(size: 12))
                                    .foregroundColor(.secondary)
                            }
                            Spacer(minLength: 0)
                        }
                        .padding(.horizontal, 10)
                        .padding(.vertical, 8)
                        .background(
                            RoundedRectangle(cornerRadius: 6)
                                .fill(Color(.textBackgroundColor))
                        )
                        .overlay(
                            RoundedRectangle(cornerRadius: 6)
                                .stroke(Color(.separatorColor).opacity(0.5), lineWidth: 0.5)
                        )
                    }

                    VStack(alignment: .leading, spacing: 6) {
                        sectionCaption("LAUNCH SHORTCUT")
                        HStack(spacing: 6) {
                            ForEach(modifierSymbols, id: \.self) { symbol in
                                shortcutBadge(symbol)
                            }
                            shortcutBadge(displayName)
                        }
                    }

                    if isGeneralOccupied {
                        Text("This key is used by a general shortcut and can only be changed from the General tab.")
                            .font(.system(size: 11))
                            .foregroundColor(.secondary)
                            .fixedSize(horizontal: false, vertical: true)

                        Button(action: onEditGeneral) {
                            Text("Edit in General Tab…")
                                .frame(maxWidth: .infinity)
                        }
                        .controlSize(.large)
                    } else {
                        Button(action: { showingAppPicker = true }) {
                            Text(assignment == nil ? "Assign Application…" : "Change Application…")
                                .frame(maxWidth: .infinity)
                        }
                        .controlSize(.large)
                        .buttonStyle(.borderedProminent)
                        .sheet(isPresented: $showingAppPicker) {
                            AppPickerDialog(
                                keyDisplayName: displayName,
                                apps: apps,
                                assignedKeyByBundleId: assignedKeyByBundleId,
                                recentBundleIds: recentBundleIds,
                                onAssign: { app in
                                    showingAppPicker = false
                                    onAssign(app.bundleIdentifier)
                                },
                                onCancel: { showingAppPicker = false }
                            )
                        }

                        if assignment != nil {
                            Button(action: onRemove) {
                                Text("Remove Assignment")
                                    .frame(maxWidth: .infinity)
                            }
                            .controlSize(.large)
                            .foregroundColor(.red)
                        }
                    }

                    Spacer()
                }
            } else {
                VStack(spacing: 8) {
                    Image(systemName: "keyboard")
                        .font(.system(size: 24))
                        .foregroundColor(.secondary)
                    Text("Select a key to configure its shortcut")
                        .font(.system(size: 12))
                        .foregroundColor(.secondary)
                        .multilineTextAlignment(.center)
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
            }
        }
        .padding(16)
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
    }

    private var modifierSymbols: [String] {
        let modifiers = assignment?.shortcut.modifiers ?? ["option"]
        return modifiers.compactMap { modifier in
            switch modifier.lowercased() {
            case "command":
                return "⌘"
            case "option":
                return "⌥"
            case "shift":
                return "⇧"
            case "control":
                return "⌃"
            default:
                return nil
            }
        }
    }

    private func sectionCaption(_ text: String) -> some View {
        Text(text)
            .font(.system(size: 9, weight: .semibold))
            .tracking(1)
            .foregroundColor(.secondary)
    }

    private func shortcutBadge(_ symbol: String) -> some View {
        Text(symbol)
            .font(.system(size: 12, weight: .semibold))
            .padding(.horizontal, symbol.count > 1 ? 8 : 0)
            .frame(minWidth: 28, minHeight: 28)
            .background(
                RoundedRectangle(cornerRadius: 6)
                    .fill(Color(.controlBackgroundColor))
            )
            .overlay(
                RoundedRectangle(cornerRadius: 6)
                    .stroke(Color(.separatorColor), lineWidth: 1)
            )
    }
}

// MARK: - App picker dialog

struct AppPickerDialog: View {
    let keyDisplayName: String
    let apps: [AppInfo]
    let assignedKeyByBundleId: [String: String]
    let recentBundleIds: [String]
    let onAssign: (AppInfo) -> Void
    let onCancel: () -> Void

    @State private var searchText = ""
    @State private var selectedBundleId: String? = nil

    private var filteredApps: [AppInfo] {
        if searchText.isEmpty {
            return apps
        }
        return apps.filter { app in
            app.name.lowercased().contains(searchText.lowercased()) ||
            app.bundleIdentifier.lowercased().contains(searchText.lowercased())
        }
    }

    private var recentApps: [AppInfo] {
        recentBundleIds
            .compactMap { bundleId in apps.first(where: { $0.bundleIdentifier == bundleId }) }
            .prefix(5)
            .map { $0 }
    }

    private var selectedApp: AppInfo? {
        guard let selectedBundleId = selectedBundleId else { return nil }
        return apps.first(where: { $0.bundleIdentifier == selectedBundleId })
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            // Header
            VStack(alignment: .leading, spacing: 2) {
                Text("Assign Application to “\(keyDisplayName)”")
                    .font(.system(size: 15, weight: .bold))
                Text("Choose an application to launch with this shortcut.")
                    .font(.system(size: 12))
                    .foregroundColor(.secondary)
            }
            .padding(.horizontal, 16)
            .padding(.top, 16)
            .padding(.bottom, 10)

            // Search field
            HStack(spacing: 4) {
                Image(systemName: "magnifyingglass")
                    .foregroundColor(.secondary)
                    .font(.system(size: 11))
                TextField("Search applications", text: $searchText)
                    .textFieldStyle(.plain)
                    .font(.system(size: 12))
                if !searchText.isEmpty {
                    Button(action: { searchText = "" }) {
                        Image(systemName: "xmark.circle.fill")
                            .foregroundColor(.secondary)
                            .font(.system(size: 11))
                    }
                    .buttonStyle(.plain)
                }
            }
            .padding(.horizontal, 8)
            .padding(.vertical, 6)
            .background(
                RoundedRectangle(cornerRadius: 6)
                    .fill(Color(.textBackgroundColor))
            )
            .overlay(
                RoundedRectangle(cornerRadius: 6)
                    .stroke(Color(.separatorColor).opacity(0.5), lineWidth: 0.5)
            )
            .padding(.horizontal, 16)
            .padding(.bottom, 12)

            // Content
            ScrollView {
                VStack(alignment: .leading, spacing: 12) {
                    if searchText.isEmpty && !recentApps.isEmpty {
                        VStack(alignment: .leading, spacing: 6) {
                            dialogCaption("RECENT")
                            HStack(spacing: 8) {
                                ForEach(recentApps) { app in
                                    recentTile(app)
                                }
                            }
                        }
                    }

                    VStack(alignment: .leading, spacing: 4) {
                        dialogCaption("APPLICATIONS")

                        if filteredApps.isEmpty {
                            Text(apps.isEmpty ? "Loading applications…" : "No applications match your search")
                                .font(.system(size: 12))
                                .foregroundColor(.secondary)
                                .padding(.vertical, 12)
                                .frame(maxWidth: .infinity)
                        } else {
                            LazyVStack(spacing: 1) {
                                ForEach(filteredApps) { app in
                                    appRow(app)
                                }
                            }
                        }
                    }
                }
                .padding(.horizontal, 16)
                .padding(.bottom, 12)
            }

            Divider()

            // Footer
            HStack {
                Spacer()
                Button("Cancel", action: onCancel)
                    .keyboardShortcut(.cancelAction)
                Button("Assign") {
                    if let app = selectedApp {
                        onAssign(app)
                    }
                }
                .buttonStyle(.borderedProminent)
                .keyboardShortcut(.defaultAction)
                .disabled(selectedApp == nil)
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 12)
        }
        .frame(width: 440, height: 520)
    }

    private func dialogCaption(_ text: String) -> some View {
        Text(text)
            .font(.system(size: 9, weight: .semibold))
            .tracking(1)
            .foregroundColor(.secondary)
    }

    private func recentTile(_ app: AppInfo) -> some View {
        let isSelected = selectedBundleId == app.bundleIdentifier
        return VStack(spacing: 4) {
            if let icon = app.icon {
                Image(nsImage: icon)
                    .resizable()
                    .aspectRatio(contentMode: .fit)
                    .frame(width: 28, height: 28)
            }
            Text(app.name)
                .font(.system(size: 10))
                .foregroundColor(.secondary)
                .lineLimit(1)
                .truncationMode(.tail)
        }
        .padding(.horizontal, 6)
        .frame(width: 68, height: 60)
        .background(
            RoundedRectangle(cornerRadius: 8)
                .fill(isSelected ? Color.accentColor.opacity(0.1) : Color(.controlBackgroundColor))
        )
        .overlay(
            RoundedRectangle(cornerRadius: 8)
                .stroke(isSelected ? Color.accentColor : Color(.separatorColor).opacity(0.7), lineWidth: isSelected ? 1.5 : 1)
        )
        .contentShape(Rectangle())
        .onTapGesture(count: 2) { onAssign(app) }
        .onTapGesture { selectedBundleId = app.bundleIdentifier }
    }

    private func appRow(_ app: AppInfo) -> some View {
        let isSelected = selectedBundleId == app.bundleIdentifier
        return HStack(spacing: 8) {
            if let icon = app.icon {
                Image(nsImage: icon)
                    .resizable()
                    .aspectRatio(contentMode: .fit)
                    .frame(width: 20, height: 20)
            }
            VStack(alignment: .leading, spacing: 1) {
                Text(app.name)
                    .font(.system(size: 12))
                    .lineLimit(1)
                Text(app.bundleIdentifier)
                    .font(.system(size: 9, weight: .light))
                    .foregroundColor(Color.secondary.opacity(0.7))
                    .lineLimit(1)
                    .truncationMode(.middle)
            }
            Spacer()
            if let key = assignedKeyByBundleId[app.bundleIdentifier] {
                Text(shortcutKeyDisplayName(key))
                    .font(.system(size: 10, weight: .semibold, design: .monospaced))
                    .padding(.horizontal, 5)
                    .padding(.vertical, 2)
                    .background(
                        RoundedRectangle(cornerRadius: 4)
                            .fill(Color.accentColor.opacity(0.12))
                    )
                    .foregroundColor(.accentColor)
            }
        }
        .padding(.horizontal, 8)
        .padding(.vertical, 6)
        .background(
            RoundedRectangle(cornerRadius: 6)
                .fill(isSelected ? Color.accentColor.opacity(0.12) : Color.clear)
        )
        .contentShape(Rectangle())
        .onTapGesture(count: 2) { onAssign(app) }
        .onTapGesture { selectedBundleId = app.bundleIdentifier }
    }
}

struct ModernShortcutRow: View {
    let title: String
    let subtitle: String?
    let icon: NSImage?
    let showIcon: Bool
    @Binding var shortcut: ShortcutConfig?
    @ObservedObject var keysModel: AvailableKeysModel

    init(title: String, subtitle: String?, icon: NSImage?, showIcon: Bool = true, shortcut: Binding<ShortcutConfig?>, keysModel: AvailableKeysModel) {
        self.title = title
        self.subtitle = subtitle
        self.icon = icon
        self.showIcon = showIcon
        self._shortcut = shortcut
        self.keysModel = keysModel
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

                ModernShortcutRecorder(shortcut: $shortcut, keysModel: keysModel)
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
    @ObservedObject var keysModel: AvailableKeysModel
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
            ModernShortcutRecorderPopover(shortcut: $shortcut, isPresented: $showingRecorder, keysModel: keysModel)
        }
    }
}

struct ModernShortcutRecorderPopover: View {
    @Binding var shortcut: ShortcutConfig?
    @Binding var isPresented: Bool
    @ObservedObject var keysModel: AvailableKeysModel
    @State private var isRecording = false
    @State private var currentModifiers: NSEvent.ModifierFlags = []
    @State private var currentKey: String?

    private var availableKeys: [KeyAvailability] {
        keysModel.availableKeys.filter { $0.isAvailable }
    }

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
                    shortcut = nil
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

            if !availableKeys.isEmpty {
                Divider()

                VStack(alignment: .leading, spacing: 6) {
                    Text("Available Keys")
                        .font(.system(size: 10, weight: .medium))
                        .foregroundColor(.secondary)

                    LazyVGrid(columns: Array(repeating: GridItem(.fixed(28), spacing: 6), count: 8), alignment: .leading, spacing: 6) {
                        ForEach(availableKeys) { keyAvailability in
                            KeyBadgeView(key: keyAvailability.displayName, isAvailable: true)
                        }
                    }
                }
            }
        }
        .padding()
        .frame(width: 300)
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
        // Handle Escape to cancel
        if event.keyCode == 53 {
            stopRecording()
            isPresented = false
            return
        }

        let modifiers = event.modifierFlags.intersection(.deviceIndependentFlagsMask)
        currentModifiers = modifiers

        if let key = event.charactersIgnoringModifiers?.lowercased(), !key.isEmpty {
            // Filter out non-printable characters (Enter, Tab, etc.)
            let validCharacters = CharacterSet.alphanumerics.union(CharacterSet(charactersIn: "`-=[]\\;',./"))
            guard key.unicodeScalars.allSatisfy({ validCharacters.contains($0) }) else {
                return
            }

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
