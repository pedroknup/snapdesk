//
//  ShotcutsView.swift
//  snapdesk
//
//  Created by Pedro Knup on 20/04/2025.
//

import SwiftUI
import AppKit

struct AppInfo: Identifiable {
    let id = UUID()
    let name: String
    let path: String
    let icon: NSImage
}

struct ShortcutItem: Identifiable {
    let id = UUID()
    let name: String
    let action: () -> Void
}

struct ShortcutsTabView: View {
    @State private var apps: [AppInfo] = []
    @State private var isLoading = true
    
    private let generalShortcuts: [ShortcutItem] = [
        ShortcutItem(name: "Toggle Full Screen layout for the current screen", action: {}),
        ShortcutItem(name: "Throw focused window to Screen 1", action: {}),
        ShortcutItem(name: "Throw focused window to Screen 2", action: {}),
        ShortcutItem(name: "Throw focused window to Screen 3", action: {}),
        ShortcutItem(name: "Throw focused window to Screen 4", action: {}),
        ShortcutItem(name: "Throw focused window to Screen 5", action: {}),
        ShortcutItem(name: "Throw focused window to Screen 6", action: {}),
        ShortcutItem(name: "Add focused app to layout group", action: {}),
        ShortcutItem(name: "Remove focused app from layout group", action: {})
    ]

    var body: some View {
        List {
            Section("General") {
                ForEach(generalShortcuts) { shortcut in
                    HStack {
                        Text(shortcut.name)
                        Spacer()
                        Button("Configure") {
                            shortcut.action()
                        }
                        .buttonStyle(.borderless)
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
                                Text(app.path).font(.caption).foregroundColor(.gray)
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
            }
        }
        .navigationTitle("Shortcuts")
    }

    private func loadApps() async {
        isLoading = true
        apps = await Task.detached(priority: .userInitiated) {
            fetchInstalledApps()
        }.value
        isLoading = false
    }

    func fetchInstalledApps() -> [AppInfo] {
        let appPaths = FileManager.default.urls(for: .applicationDirectory, in: .localDomainMask)
        var results: [AppInfo] = []

        if let appsURL = appPaths.first {
            let enumerator = FileManager.default.enumerator(at: appsURL, includingPropertiesForKeys: nil)
            while let fileURL = enumerator?.nextObject() as? URL {
                if fileURL.pathExtension == "app" {
                    let name = fileURL.deletingPathExtension().lastPathComponent
                    let icon = NSWorkspace.shared.icon(forFile: fileURL.path)
                    results.append(AppInfo(name: name, path: fileURL.path, icon: icon))
                }
            }
        }

        return results.sorted { $0.name.lowercased() < $1.name.lowercased() }
    }
}

#Preview {
    ShortcutsTabView()
}
