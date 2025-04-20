//
//  SettingsWindowController.swift
//  snapdesk
//
//  Created by Pedro Knup on 20/04/2025.
//

import Cocoa
import SwiftUI

class SettingsWindowController: NSWindowController {
    private var hostingController: NSHostingController<SettingsView>!
    private var viewModel = SettingsViewModel()

    init() {
        let view = SettingsView(viewModel: viewModel)
        hostingController = NSHostingController(rootView: view)

        let window = NSWindow(contentViewController: hostingController)
        window.title = "Snapdesk Settings"
        window.setContentSize(NSSize(width: 800, height: 600))
        window.styleMask = [.titled, .closable, .miniaturizable, .resizable]
        window.center()

        super.init(window: window)
    }

    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    func showTab(_ tab: SettingsTab) {
        viewModel.selectedTab = tab
        showWindow(nil)
        window?.makeKeyAndOrderFront(nil)
        NSApp.activate(ignoringOtherApps: true)
    }
}
