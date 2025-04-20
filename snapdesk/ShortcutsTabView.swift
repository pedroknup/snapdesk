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

struct ShortcutsView: View {
    @State private var apps: [AppInfo] = []

    var body: some View {
        List(apps) { app in
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
        .onAppear {
            apps = fetchInstalledApps()
        }
        .navigationTitle("Installed Applications")
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
    ShortcutsView()
}
