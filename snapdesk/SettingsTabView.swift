//
//  SettingsTabView.swift
//  snapdesk
//
//  Created by Pedro Knup on 20/04/2025.
//

import SwiftUI

struct SettingsTabView: View {
    @AppStorage("showLayoutIndicator") private var showLayoutIndicator = true
    @AppStorage("launchAtLogin") private var launchAtLogin = false
    @AppStorage("windowGap") private var windowGap: Double = 4

    var body: some View {
        VStack(alignment: .leading, spacing: 20) {
            GroupBox(label: Text("Appearance").bold()) {
                Toggle("Show Layout Indicator", isOn: $showLayoutIndicator)
                    .help("Display the current layout indicator in the menu bar")
            }

            GroupBox(label: Text("Startup").bold()) {
                Toggle("Launch at Login", isOn: $launchAtLogin)
                    .help("Start SnapDesk automatically when you log in to your Mac")
            }

            GroupBox(label: Text("Layout").bold()) {
                HStack {
                    Text("Window Gap")
                    Spacer()
                    TextField("Gap", value: $windowGap, format: .number)
                        .textFieldStyle(.roundedBorder)
                        .frame(width: 60)
                    Text("px")
                }
                .help("Space between windows when using a multi-window layout")
            }

            Spacer()
        }
        .padding(24)
        .frame(width: 360)
    }
}


#Preview {
    SettingsTabView()
}
