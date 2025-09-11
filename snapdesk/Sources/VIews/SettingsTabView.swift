import SwiftUI

struct SettingsTabView: View {
    // Notifications & Visual Feedback
    @AppStorage("showLayoutIndicator") private var showLayoutIndicator = true
    @AppStorage("show-all-layouts-on-toggle") private var showAllLayoutsOnToggle = false
    @AppStorage("showThrowNotifications") private var showThrowNotifications = true
    @AppStorage("notificationDuration") private var notificationDuration: Double = 1.5
    @AppStorage("notificationPosition") private var notificationPosition = "center"
    
    // Window Preview Settings (from YAML config)
    @State private var windowPreviewEnabled = true
    @State private var windowPreviewWidth: Double = 200
    @State private var windowPreviewHeight: Double = 150
    @State private var windowPreviewCacheTimeout: Double = 5.0
    
    // Startup & System
    @AppStorage("launchAtLogin") private var launchAtLogin = true
    @AppStorage("hideMenuBarIcon") private var hideMenuBarIcon = false
    @AppStorage("enableAccessibilityOnStart") private var enableAccessibilityOnStart = true
    
    // Layout & Windows  
    @AppStorage("windowGap") private var windowGap: Double = 0
    @AppStorage("windowMargin") private var windowMargin: Double = 0
    @AppStorage("defaultLayoutMode") private var defaultLayoutMode = "wide"
    @AppStorage("animateWindowTransitions") private var animateWindowTransitions = true
    @AppStorage("respectWindowMinimumSize") private var respectWindowMinimumSize = true
    @AppStorage("autoExpandNewWindows") private var autoExpandNewWindows = true
    
    // Advanced
    @AppStorage("enableDebugLogging") private var enableDebugLogging = false
    @AppStorage("showLogsView") private var showLogsView = false
    @AppStorage("windowDetectionInterval") private var windowDetectionInterval: Double = 0.5
    @AppStorage("focusFollowsMouse") private var focusFollowsMouse = true

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 32) {
                // Notifications & Visual Feedback
                VStack(alignment: .leading, spacing: 12) {
                    Text("Notifications & Visual Feedback")
                        .font(.headline)

                    Toggle("Show Layout Change Notifications", isOn: $showLayoutIndicator)
                        .help("Display floating notification when toggling between layouts")
                    
                    Toggle("Show All Layouts Grid", isOn: $showAllLayoutsOnToggle)
                        .help("Display all layout options in a grid view when toggling (instead of just text)")
                    
                    Toggle("Show Window Throw Notifications", isOn: $showThrowNotifications)
                        .help("Display notification when moving windows between screens")
                    
                    Toggle("Show Window Preview Screenshots", isOn: $windowPreviewEnabled)
                        .help("Display window screenshots when cycling through app windows")
                        .onChange(of: windowPreviewEnabled) { _ in
                            saveWindowPreviewConfig()
                        }
                    
                    if windowPreviewEnabled {
                        VStack(alignment: .leading, spacing: 8) {
                            HStack {
                                Text("Preview Width:")
                                    .foregroundColor(.secondary)
                                Slider(value: $windowPreviewWidth, in: 100...400, step: 10)
                                    .onChange(of: windowPreviewWidth) { _ in
                                        saveWindowPreviewConfig()
                                    }
                                Text("\(Int(windowPreviewWidth))px")
                                    .foregroundColor(.secondary)
                                    .frame(width: 45, alignment: .trailing)
                            }
                            
                            HStack {
                                Text("Preview Height:")
                                    .foregroundColor(.secondary)
                                Slider(value: $windowPreviewHeight, in: 75...300, step: 10)
                                    .onChange(of: windowPreviewHeight) { _ in
                                        saveWindowPreviewConfig()
                                    }
                                Text("\(Int(windowPreviewHeight))px")
                                    .foregroundColor(.secondary)
                                    .frame(width: 45, alignment: .trailing)
                            }
                        }
                        .padding(.leading, 20)
                    }
                }

                // Startup & System
                VStack(alignment: .leading, spacing: 12) {
                    Text("Startup & System")
                        .font(.headline)

                    Toggle("Launch at Login", isOn: $launchAtLogin)
                        .help("Start Snapdesk automatically when you log in to your Mac")
                        .onChange(of: launchAtLogin) { newValue in
                            UserConfiguration.shared.setLaunchAtLogin(newValue)
                        }
                    
                    Toggle("Hide Menu Bar Icon", isOn: $hideMenuBarIcon)
                        .help("Hide the Snapdesk icon from the menu bar (access via shortcuts only)")
                }

                // Layout & Windows
                VStack(alignment: .leading, spacing: 12) {
                    Text("Layout & Windows")
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
                    
                    HStack(spacing: 8) {
                        Text("Window Margin")
                        Spacer()
                        TextField("Margin", value: $windowMargin, format: .number)
                            .textFieldStyle(.roundedBorder)
                            .frame(width: 60)
                        Text("px")
                            .foregroundColor(.secondary)
                    }
                    .help("Space around each individual window (applies to all windows)")
                    
                    HStack(spacing: 8) {
                        Text("Default Layout Mode")
                        Spacer()
                        Picker("Layout", selection: $defaultLayoutMode) {
                            Text("Wide").tag("wide")
                            Text("Tall").tag("tall")
                            Text("Fullscreen").tag("fullscreen")
                            Text("Floating").tag("floating")
                        }
                        .pickerStyle(MenuPickerStyle())
                        .frame(width: 120)
                    }
                    .help("Default layout for new WindowSets")
                      
                    Toggle("Auto-Expand New Windows", isOn: $autoExpandNewWindows)
                        .help("Automatically expand new windows to fit their assigned layout")
                    
                    Toggle("Mouse Follows Focus", isOn: $focusFollowsMouse)
                        .help("Mouse cursor moves to the center of the focused window as the focus changes")
                }

                // Advanced  
                VStack(alignment: .leading, spacing: 12) {
                    Text("Advanced")
                        .font(.headline)
                    
                    Toggle("Enable Debug Logging", isOn: $enableDebugLogging)
                        .help("Show detailed logging information in Console.app (for troubleshooting)")
                    
                    Toggle("Show Logs View", isOn: $showLogsView)
                        .help("Display a persistent debug log viewer on screen (bottom right corner)")
                    
                    HStack(spacing: 8) {
                        Text("Window Detection Interval")
                        Spacer()
                        TextField("Interval", value: $windowDetectionInterval, format: .number)
                            .textFieldStyle(.roundedBorder)
                            .frame(width: 60)
                        Text("sec")
                            .foregroundColor(.secondary)
                    }
                    .help("How often to check for new windows (lower = more responsive, higher CPU usage)")
                }

                Spacer(minLength: 20)
            }
            .padding(.horizontal, 32)
            .padding(.top, 32)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .onAppear {
            loadWindowPreviewConfig()
            loadStartupSettings()
        }
    }
    
    // MARK: - Window Preview Configuration
    
    private func loadWindowPreviewConfig() {
        if let config = ConfigurationManager.shared.loadConfig() {
            windowPreviewEnabled = config.windowPreview.enabled
            windowPreviewWidth = Double(config.windowPreview.maxWidth)
            windowPreviewHeight = Double(config.windowPreview.maxHeight)
            windowPreviewCacheTimeout = config.windowPreview.cacheTimeoutSeconds
        }
    }
    
    private func saveWindowPreviewConfig() {
        guard var config = ConfigurationManager.shared.loadConfig() else { 
            return 
        }
        
        // Update the window preview settings
        config.windowPreview.enabled = windowPreviewEnabled
        config.windowPreview.maxWidth = CGFloat(windowPreviewWidth)
        config.windowPreview.maxHeight = CGFloat(windowPreviewHeight)
        config.windowPreview.cacheTimeoutSeconds = windowPreviewCacheTimeout
        
        // Save the updated configuration
        try? ConfigurationManager.shared.saveConfig(config)
        
        // Clear screenshot cache when settings change
        WindowScreenshotCapture.clearCache()
    }
    
    // MARK: - Startup Settings
    
    private func loadStartupSettings() {
        launchAtLogin = UserConfiguration.shared.launchAtLogin()
    }
}
