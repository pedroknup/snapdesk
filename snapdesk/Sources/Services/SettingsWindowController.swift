//
//  SettingsWindowController.swift
//  snapdesk
//
//  Created by Pedro Knup on 20/04/2025.
//

import Cocoa
import SwiftUI

class SettingsWindowController: NSWindowController {
    private var hostingController: NSHostingController<PreferencesView>!
    private var viewModel = PreferencesViewModel()

    init() {
        log("🔧 Initializing SettingsWindowController")
        
        let view = PreferencesView(viewModel: viewModel)
        hostingController = NSHostingController(rootView: view)
        
        log("📐 Creating settings window...")
        let window = NSWindow(contentViewController: hostingController)
        window.title = "Snapdesk Settings"
        window.setContentSize(NSSize(width: 800, height: 600))
        window.styleMask = [.titled, .closable, .miniaturizable, .resizable]
        window.center()
        
        // Additional window configuration to ensure visibility
        window.isReleasedWhenClosed = false
        window.level = .floating // Temporarily set to floating to ensure it shows
        
        super.init(window: window)
        
        log("✅ SettingsWindowController initialized successfully")
    }

    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    func showTab(_ tab: SettingsTab) {
        log("📱 Showing settings tab: \(tab.title)")
        viewModel.selectedTab = tab
        
        // Ensure window is valid
        guard let window = window else {
            log("❌ Window is nil in showTab")
            return
        }
        
        log("🪟 Window exists, showing it...")
        showWindow(nil)
        window.makeKeyAndOrderFront(nil)
        
        // Force the window to be visible
        window.orderFrontRegardless()
        window.makeMain()
        window.makeKey()
        
        // Activate the app
        NSApp.activate(ignoringOtherApps: true)
        
        log("✅ Settings window should now be visible")
    }
}
