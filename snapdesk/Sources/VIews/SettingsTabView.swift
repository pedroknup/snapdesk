import SwiftUI

struct SettingsTabView: View {
    @AppStorage("showLayoutIndicator") private var showLayoutIndicator = true
    @AppStorage("launchAtLogin") private var launchAtLogin = false
    @AppStorage("windowGap") private var windowGap: Double = 4

    var body: some View {
        VStack(alignment: .leading, spacing: 32) {
            VStack(alignment: .leading, spacing: 12) {
                Text("Appearance")
                    .font(.headline)

                Toggle("Show Layout Indicator", isOn: $showLayoutIndicator)
                    .help("Display the current layout indicator in the menu bar")
            }

            VStack(alignment: .leading, spacing: 12) {
                Text("Startup")
                    .font(.headline)

                Toggle("Launch at Login", isOn: $launchAtLogin)
                    .help("Start SnapDesk automatically when you log in to your Mac")
            }

            VStack(alignment: .leading, spacing: 12) {
                Text("Layout")
                    .font(.headline)

                HStack(spacing: 8) {
                    Text("Window Gap")
                    Spacer()
                    TextField("Gap", value: $windowGap, format: .number)
                        .textFieldStyle(.roundedBorder)
                        .frame(width: 60)
                    Text("px")
                        .foregroundColor(.secondary)
                }
                .help("Space between windows when using a multi-window layout")
            }

            Spacer()
        }
        .padding(.horizontal, 32)
        .padding(.top, 32)
        .frame(maxWidth: .infinity, alignment: .leading)
    }
}
