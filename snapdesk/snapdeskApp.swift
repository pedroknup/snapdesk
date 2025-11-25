//
//  snapdeskApp.swift
//  snapdesk
//
//  Created by Pedro Knup on 04/04/2025.
//


import Cocoa

@objc(SnapdeskApp)
class SnapdeskApp: NSObject, NSApplicationDelegate {
    var windowManager: WorkspaceCoordinator!
    var hotkeyManager: HotkeyManager!
    var statusItem: NSStatusItem?
    var settingsWindowController: SettingsWindowController?
    
    func applicationDidFinishLaunching(_ notification: Notification) {
        // Force SwiftyBeaver logging setup early to capture all logs
        _ = log
        log("App startup beginning - logging system initialized")
        
        // Check if another instance is running
        let bundleIdentifier = Bundle.main.bundleIdentifier ?? "com.pedroknup.snapdesk"
        let runningApps = NSRunningApplication.runningApplications(withBundleIdentifier: bundleIdentifier)
        
        if runningApps.count > 1 {
            let alert = NSAlert()
            alert.messageText = "Snapdesk is already running"
            alert.informativeText = "Another instance of Snapdesk is already running. Please close it before starting a new instance."
            alert.alertStyle = .warning
            alert.addButton(withTitle: "OK")
            alert.runModal()
            NSApp.terminate(nil)
            return
        }
        
        NSApplication.shared.setActivationPolicy(.accessory)
        let trusted = AXIsProcessTrusted()
        log("AX trusted? \(trusted)")
        if !trusted {
            let options = [kAXTrustedCheckOptionPrompt.takeRetainedValue() as String: true] as CFDictionary
            _ = AXIsProcessTrustedWithOptions(options)
            log("Not trusted. Exiting...")
            exit(1)
        }

        windowManager = WorkspaceCoordinator()

        // Initialize HotkeyManager
        hotkeyManager = HotkeyManager(windowManager: windowManager)

        // Set up hotkeys using the protocol-based pattern
        Task {
            await hotkeyManager.setUpWithWindowController(windowManager)
        }
        
        NSWorkspace.shared.notificationCenter.addObserver(
            self,
            selector: #selector(appDidLaunch(_:)),
            name: NSWorkspace.didLaunchApplicationNotification,
            object: nil
        )

        NSWorkspace.shared.notificationCenter.addObserver(
            self,
            selector: #selector(appDidTerminate(_:)),
            name: NSWorkspace.didTerminateApplicationNotification,
            object: nil
        )

        statusItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.squareLength)

        if let button = statusItem?.button {
            button.image = NSImage(named: "snapdesk-status-bar-icon")
            button.image?.isTemplate = true
        }
        let menu = NSMenu()
        
        let versionItem = NSMenuItem(title: "Version 0.0.1 (beta)", action: nil, keyEquivalent: "")
        versionItem.isEnabled = false
        menu.addItem(versionItem)
        menu.addItem(NSMenuItem.separator())
        menu.addItem(NSMenuItem(title: "Revaluate Windows", action: #selector(revaluateWindows), keyEquivalent: "r"))
        menu.addItem(NSMenuItem(title: "Test Floating Windows", action: #selector(testFloatingWindows), keyEquivalent: "t"))
        menu.addItem(NSMenuItem(title: "Toggle Debug Viewer", action: #selector(toggleDebugViewer), keyEquivalent: "d"))
        
        menu.addItem(NSMenuItem(title: "Preferences", action: #selector(openSettings), keyEquivalent: ","))
        menu.addItem(NSMenuItem(title: "About Snapdesk", action: #selector(showAbout), keyEquivalent: ""))
        menu.addItem(NSMenuItem.separator())
        menu.addItem(NSMenuItem(title: "Quit Snapdesk", action: #selector(quitApp), keyEquivalent: "q"))

        statusItem?.menu = menu

        log("Snapdesk is listening for hotkeys")

        NotificationService.showFloatingWindow(text: "Snapdesk loaded", position: .center, duration: 3.0)

        _ = DebugLogViewer.shared
        log("Debug log viewer initialized")
        
    }
    
    
    @objc func appDidLaunch(_ notification: Notification) {
    }

    @objc func appDidTerminate(_ notification: Notification) {
    }

    @objc func quitApp() {
        log("Quit clicked")
        NSApp.terminate(nil)
    }

    @objc func openSettings() {
        log("Settings clicked")
        
        // Ensure we're on the main thread
        DispatchQueue.main.async { [weak self] in
            if self?.settingsWindowController == nil {
                self?.settingsWindowController = SettingsWindowController()
            }

            self?.settingsWindowController?.showTab(.settings)
        }
    }

    @objc func showAbout() {
        log("About clicked")

        DispatchQueue.main.async { [weak self] in
            if self?.settingsWindowController == nil {
                self?.settingsWindowController = SettingsWindowController()
            }

            self?.settingsWindowController?.showTab(.about)
        }
    }

    @objc func revaluateWindows() {
        log("Revaluate windows clicked")
    }

    @objc func testFloatingWindows() {
        log("Test floating windows clicked")
        NotificationService.showMultipleDemo()
    }
    
    @objc func toggleDebugViewer() {
        let currentValue = UserDefaults.standard.object(forKey: "showLogsView") as? Bool ?? false
        UserDefaults.standard.set(!currentValue, forKey: "showLogsView")
    }
    
    // Method to reload hotkey configuration when settings change
    func reloadHotkeyConfiguration() {
        hotkeyManager?.reloadConfiguration()
    }


}

