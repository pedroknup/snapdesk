//
//  snapdeskApp.swift
//  snapdesk
//
//  Created by Pedro Knup on 04/04/2025.
//


import Cocoa

@objc(SnapdeskApp)
class SnapdeskApp: NSObject, NSApplicationDelegate {
    var windowController: WindowController!
    var hotkeyManager: HotkeyManager!
    var statusItem: NSStatusItem?
    var settingsWindowController: SettingsWindowController?
    
    func applicationDidFinishLaunching(_ notification: Notification) {
        // Check if another instance is running
        let bundleIdentifier = Bundle.main.bundleIdentifier ?? "com.pedroknup.snapdesk"
        let runningApps = NSRunningApplication.runningApplications(withBundleIdentifier: bundleIdentifier)
        
        if runningApps.count > 1 {
            let alert = NSAlert()
            alert.messageText = "SnapDesk is already running"
            alert.informativeText = "Another instance of SnapDesk is already running. Please close it before starting a new instance."
            alert.alertStyle = .warning
            alert.addButton(withTitle: "OK")
            alert.runModal()
            NSApp.terminate(nil)
            return
        }
        
        NSApplication.shared.setActivationPolicy(.accessory)
        let trusted = AXIsProcessTrusted()
        log("🔐 AX trusted? \(trusted)")
        if !trusted {
            let options = [kAXTrustedCheckOptionPrompt.takeRetainedValue() as String: true] as CFDictionary
            _ = AXIsProcessTrustedWithOptions(options)
            log("⚠️ Not trusted. Exiting...")≈
            exit(1)
        }

        windowController = WindowController()
        //windowController.startFocusObserver()
        //windowController.startFocusPollingFallback()
        
        hotkeyManager = HotkeyManager(controller: windowController)
        
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
            button.image?.isTemplate = true // 🔥 this enables proper styling
        }

        // 🧾 Create menu
        let menu = NSMenu()
        
        let versionItem = NSMenuItem(title: "Version 0.0.1 (beta)", action: nil, keyEquivalent: "")
        versionItem.isEnabled = false
        menu.addItem(versionItem)
        menu.addItem(NSMenuItem.separator())
        
        menu.addItem(NSMenuItem(title: "Preferences", action: #selector(openSettings), keyEquivalent: ","))
        menu.addItem(NSMenuItem(title: "About SnapDesk", action: #selector(showAbout), keyEquivalent: ""))
        menu.addItem(NSMenuItem.separator())
        menu.addItem(NSMenuItem(title: "Quit Snapdesk", action: #selector(quitApp), keyEquivalent: "q"))

        statusItem?.menu = menu
        
        log("🚀 Snapdesk is listening for hotkeys")
        
    }
    
    
    @objc func appDidLaunch(_ notification: Notification) {
        if let app = notification.userInfo?[NSWorkspace.applicationUserInfoKey] as? NSRunningApplication {
            log("🚀 App launched: \(app.localizedName ?? "Unknown") [\(app.bundleIdentifier ?? "No Bundle ID")]")
            windowController?.trackWindowsForApp(app)
        }
    }

    @objc func appDidTerminate(_ notification: Notification) {
        if let app = notification.userInfo?[NSWorkspace.applicationUserInfoKey] as? NSRunningApplication {
            log("❌ App terminated: \(app.localizedName ?? "Unknown") [\(app.bundleIdentifier ?? "No Bundle ID")]")
            windowController?.scanAndTrackWindows()
        }
    }
    
    @objc func quitApp() {
        log("👋 Quit clicked")
        NSApp.terminate(nil)
    }
    
    @objc func openSettings() {
        log("⚙️ Settings clicked")
        if settingsWindowController == nil {
            settingsWindowController = SettingsWindowController()
        }
        settingsWindowController?.showTab(.settings)
    }

    @objc func showAbout() {
        log("ℹ️ About clicked")
        if settingsWindowController == nil {
            settingsWindowController = SettingsWindowController()
        }
        settingsWindowController?.showTab(.about)
    }


}

