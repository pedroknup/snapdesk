//
//  AppLifecycleManager.swift
//  snapdesk
//
//  Created by Pedro Knup on 05/09/2025.
//

import Foundation
import AppKit

// MARK: - AX Extensions for Window Observer

private extension AXUIElement {
    func axCopyAttribute<T>(_ attr: CFString) -> T? {
        var ref: CFTypeRef?
        let err = AXUIElementCopyAttributeValue(self, attr, &ref)
        guard err == .success, let v = ref as? T else { return nil }
        return v
    }
}

protocol AppLifecycleDelegate: AnyObject {
    func appDidLaunch(_ app: NSRunningApplication)
    func appDidTerminate(_ app: NSRunningApplication)
    func appDidActivate(_ app: NSRunningApplication)
    func windowDidCreate(_ window: AXWindow, for app: NSRunningApplication)
    func windowDidBecomeKey()
    func windowDidBecomeMain()
    func screenParametersDidChange()
}

class AppLifecycleManager {
    
    weak var delegate: AppLifecycleDelegate?
    
    private var applicationObservers: [pid_t: AXObserver] = [:]
    private var isProgrammaticFocus: Bool = false
    
    init() {
        setupObservers()
    }
    
    // MARK: - Public Interface
    
    /// Sets the programmatic focus flag (used to distinguish hotkey-triggered focus from manual focus)
    func setProgrammaticFocus(_ value: Bool) {
        isProgrammaticFocus = value
    }
    
    /// Gets the programmatic focus flag
    var getProgrammaticFocus: Bool {
        return isProgrammaticFocus
    }
    
    /// Launches an app with the given bundle ID
    func launchApp(bundleID: String) {
        // Try to launch the app using NSWorkspace
        let workspace = NSWorkspace.shared
        
        // First, try to find the app path by bundle identifier
        if let appURL = workspace.urlForApplication(withBundleIdentifier: bundleID) {
            log("📱 Found app at path: \(appURL.path)")
            
            workspace.openApplication(at: appURL, configuration: NSWorkspace.OpenConfiguration()) { runningApp, error in
                if let error = error {
                    log("❌ Failed to launch app: \(error.localizedDescription)")
                } else if let app = runningApp {
                    log("✅ Successfully launched: \(app.localizedName ?? "Unknown")")

                    // Give the app time to create windows, then notify delegate
                    DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) {
                        self.delegate?.appDidLaunch(app)
                    }
                }
            }
        } else {
            log("❌ Could not find app with bundle ID: \(bundleID)")
        }
    }
    
    // MARK: - Private Setup Methods
    
    private func setupObservers() {
        setupWorkspaceObservers()
        setupAccessibilityObserver()
        setupScreenChangeObserver()
        setupApplicationObservers()
    }
    
    private func setupWorkspaceObservers() {
        // Add workspace notification observers for window lifecycle
        let workspaceNotificationCenter = NSWorkspace.shared.notificationCenter
        
        workspaceNotificationCenter.addObserver(
            self,
            selector: #selector(applicationDidLaunch(_:)),
            name: NSWorkspace.didLaunchApplicationNotification,
            object: nil
        )
        
        workspaceNotificationCenter.addObserver(
            self,
            selector: #selector(applicationDidTerminate(_:)),
            name: NSWorkspace.didTerminateApplicationNotification,
            object: nil
        )
        
        workspaceNotificationCenter.addObserver(
            self,
            selector: #selector(applicationDidActivate(_:)),
            name: NSWorkspace.didActivateApplicationNotification,
            object: nil
        )
    }
    
    /// Sets up lightweight accessibility observer for window focus changes
    private func setupAccessibilityObserver() {
        // Use NSWorkspace notifications which are much more efficient than polling
        // These fire only when actual focus changes occur
        
        NotificationCenter.default.addObserver(
            self,
            selector: #selector(windowDidBecomeKey(_:)),
            name: NSWindow.didBecomeKeyNotification,
            object: nil
        )
        
        NotificationCenter.default.addObserver(
            self,
            selector: #selector(windowDidBecomeMain(_:)),
            name: NSWindow.didBecomeMainNotification,
            object: nil
        )
    }
    
    private func setupScreenChangeObserver() {
        // Listen for screen configuration changes
        NotificationCenter.default.addObserver(
            self,
            selector: #selector(screenParametersDidChange(_:)),
            name: NSApplication.didChangeScreenParametersNotification,
            object: nil
        )
    }
    
    private func setupApplicationObservers() {
        // Set up observers for all currently running applications
        for app in NSWorkspace.shared.runningApplications {
            if app.bundleIdentifier != nil, app.isManageable == .manageable {
                setupObserver(for: app)
            }
        }
    }
    
    // MARK: - Notification Handlers
    
    @objc private func applicationDidLaunch(_ notification: Notification) {
        guard let app = notification.userInfo?[NSWorkspace.applicationUserInfoKey] as? NSRunningApplication else {
            return
        }
        
        // Only log manageable applications
        if app.isManageable == .manageable {
            log("🚀 App launched: \(app.localizedName ?? "Unknown")")
        }
        
        // Set up observer for the new app
        if app.bundleIdentifier != nil, app.isManageable == .manageable {
            setupObserver(for: app)
        }

        // Give the app a moment to create windows, then notify delegate
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) { [weak self] in
            self?.delegate?.appDidLaunch(app)
        }
    }
    
    @objc private func applicationDidTerminate(_ notification: Notification) {
        guard let app = notification.userInfo?[NSWorkspace.applicationUserInfoKey] as? NSRunningApplication else {
            return
        }
        
        // Only log if we were managing this app
        if applicationObservers[app.processIdentifier] != nil {
            log("❌ App terminated: \(app.localizedName ?? "Unknown")")
        }
        
        // Remove observer for the terminated app
        removeObserver(for: app)
        
        delegate?.appDidTerminate(app)
    }
    
    @objc private func applicationDidActivate(_ notification: Notification) {
        guard let app = notification.userInfo?[NSWorkspace.applicationUserInfoKey] as? NSRunningApplication else {
            return
        }
        
        // Skip SnapDesk's own activation
        if app.bundleIdentifier == "com.pedroknup.snapdesk" {
            return
        }
        
        // Don't notify delegate if we're programmatically focusing via hotkey
        if !isProgrammaticFocus {
            delegate?.appDidActivate(app)
        }
    }
    
    @objc private func windowDidBecomeKey(_ notification: Notification) {
        // Only update if this is a window change we care about
        DispatchQueue.main.async { [weak self] in
            self?.delegate?.windowDidBecomeKey()
        }
    }
    
    @objc private func windowDidBecomeMain(_ notification: Notification) {
        // Only update if this is a window change we care about  
        DispatchQueue.main.async { [weak self] in
            self?.delegate?.windowDidBecomeMain()
        }
    }
    
    @objc private func screenParametersDidChange(_ notification: Notification) {
        let timestamp = Date()
        log("🖥️ Screen configuration changed at \(timestamp)")
        log("📋 Notification object: \(notification.object ?? "nil")")
        log("📋 Notification userInfo: \(notification.userInfo ?? [:])")

        // Add a small delay to let the system stabilize before processing
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) { [weak self] in
            log("🔄 Processing screen parameter change after delay...")
            self?.delegate?.screenParametersDidChange()
        }
    }
    
    // MARK: - Application Window Observers
    
    private func setupObserver(for app: NSRunningApplication) {
        guard let bundleID = app.bundleIdentifier else { return }

        let pid = app.processIdentifier
        let appName = app.localizedName ?? bundleID

        // Skip if we already have an observer for this app
        guard applicationObservers[pid] == nil else {
            log("🔍 Observer already exists for \(appName) (PID: \(pid))")
            return
        }

        log("🔧 Setting up observer for \(appName) (PID: \(pid))")

        // Create application element
        let appElement = AXUIElementCreateApplication(pid)

        var observer: AXObserver?
        let result = AXObserverCreate(pid, { observer, element, notification, userData in
            guard let userData = userData else { return }
            let manager = Unmanaged<AppLifecycleManager>.fromOpaque(userData).takeUnretainedValue()

            let notificationName = notification as String
            if notificationName == kAXCreatedNotification as String {
                DispatchQueue.main.async {
                    manager.handleWindowCreated(element)
                }
            } else if notificationName == kAXWindowDeminiaturizedNotification as String {
                DispatchQueue.main.async {
                    manager.handleWindowDeminiaturized(element)
                }
            }
        }, &observer)

        guard result == .success, let observer = observer else {
            log("❌ Failed to create observer for \(appName) (PID: \(pid)): AXError \(result.rawValue)")
            return
        }

        // Add observers for window notifications on this application
        let notifications: [(CFString, String)] = [
            (kAXCreatedNotification as CFString, "kAXCreatedNotification"),
            (kAXWindowDeminiaturizedNotification as CFString, "kAXWindowDeminiaturizedNotification")
        ]

        var successCount = 0
        for (notification, name) in notifications {
            let addResult = AXObserverAddNotification(
                observer,
                appElement,
                notification,
                Unmanaged.passUnretained(self).toOpaque()
            )

            if addResult == .success {
                successCount += 1
            } else {
                log("⚠️ Failed to add \(name) for \(appName) (PID: \(pid)): AXError \(addResult.rawValue)")
            }
        }

        if successCount > 0 {
            // Start observing
            CFRunLoopAddSource(
                CFRunLoopGetCurrent(),
                AXObserverGetRunLoopSource(observer),
                .defaultMode
            )
            applicationObservers[pid] = observer
            log("✅ Observer registered successfully for \(appName) (PID: \(pid)) - \(successCount)/\(notifications.count) notifications")
        } else {
            log("❌ Failed to add any notifications for \(appName) (PID: \(pid))")
        }
    }
    
    private func removeObserver(for app: NSRunningApplication) {
        let pid = app.processIdentifier
        
        if let observer = applicationObservers.removeValue(forKey: pid) {
            CFRunLoopRemoveSource(
                CFRunLoopGetCurrent(),
                AXObserverGetRunLoopSource(observer),
                .defaultMode
            )
            // Observer removed for terminated app
        }
    }
    
    private func handleWindowCreated(_ windowElement: AXUIElement) {
        // Check if this is a standard window we should track
        let role: String? = windowElement.axCopyAttribute(kAXRoleAttribute as CFString)
        let subrole: String? = windowElement.axCopyAttribute(kAXSubroleAttribute as CFString)

        // Get the window's process ID for logging
        var pid: pid_t = 0
        let pidResult = AXUIElementGetPid(windowElement, &pid)
        let app = pidResult == .success ? NSRunningApplication(processIdentifier: pid) : nil
        let appName = app?.localizedName ?? "Unknown"

        log("🪟 Window created notification received for \(appName) - role: \(role ?? "nil"), subrole: \(subrole ?? "nil")")

        guard role == (kAXWindowRole as String) else {
            log("   ⏩ Filtered: role is not AXWindow")
            return
        }

        guard subrole != (kAXSystemDialogSubrole as String),
              subrole != (kAXFloatingWindowSubrole as String),
              subrole != "AXSheet" else {
            log("   ⏩ Filtered: subrole is system dialog/floating/sheet")
            return
        }

        // Get the window's process ID to identify the app
        guard pidResult == .success,
              let app = app,
              let bundleID = app.bundleIdentifier else {
            log("   ⏩ Filtered: failed to get PID or bundle ID")
            return
        }

        // Skip SnapDesk's own windows immediately
        if bundleID == "com.pedroknup.snapdesk" {
            log("   ⏩ Filtered: SnapDesk's own window")
            return
        }

        // Create AXWindow wrapper
        let axWindow = AXWindow(axElement: windowElement)

        // Check if this window should be managed before adding it
        guard axWindow.shouldBeManaged() else {
            log("   ⏩ Filtered: shouldBeManaged() returned false, will retry after delay")

            // Retry after a short delay - window might not be fully initialized yet
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) { [weak self] in
                log("   🔄 Retrying shouldBeManaged() for \(appName)")
                if axWindow.shouldBeManaged() {
                    log("   ✅ Window now passes checks on retry, notifying delegate for \(appName)")
                    self?.delegate?.windowDidCreate(axWindow, for: app)
                } else {
                    log("   ❌ Window still fails shouldBeManaged() after retry for \(appName)")
                }
            }
            return
        }

        log("   ✅ Window passed all checks, notifying delegate for \(appName)")
        delegate?.windowDidCreate(axWindow, for: app)
    }

    private func handleWindowDeminiaturized(_ windowElement: AXUIElement) {
        // Get the window's process ID for logging
        var pid: pid_t = 0
        let pidResult = AXUIElementGetPid(windowElement, &pid)
        let app = pidResult == .success ? NSRunningApplication(processIdentifier: pid) : nil
        let appName = app?.localizedName ?? "Unknown"

        log("🔼 Window deminiaturized notification received for \(appName)")

        guard pidResult == .success,
              let app = app,
              let bundleID = app.bundleIdentifier else {
            log("   ⏩ Filtered: failed to get PID or bundle ID")
            return
        }

        // Skip SnapDesk's own windows
        if bundleID == "com.pedroknup.snapdesk" {
            log("   ⏩ Filtered: SnapDesk's own window")
            return
        }

        // Create AXWindow wrapper
        let axWindow = AXWindow(axElement: windowElement)

        // Check if this window should be managed
        guard axWindow.shouldBeManaged() else {
            log("   ⏩ Filtered: shouldBeManaged() returned false, will retry after delay")

            // Retry after a short delay - window might not be fully restored yet
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) { [weak self] in
                log("   🔄 Retrying shouldBeManaged() for deminiaturized window from \(appName)")
                if axWindow.shouldBeManaged() {
                    log("   ✅ Window now passes checks on retry, notifying delegate for \(appName)")
                    self?.delegate?.windowDidCreate(axWindow, for: app)
                } else {
                    log("   ❌ Window still fails shouldBeManaged() after retry for \(appName)")
                }
            }
            return
        }

        log("   ✅ Deminiaturized window passed all checks, notifying delegate for \(appName)")
        delegate?.windowDidCreate(axWindow, for: app)
    }

    // MARK: - Cleanup
    
    deinit {
        NSWorkspace.shared.notificationCenter.removeObserver(self)
        NotificationCenter.default.removeObserver(self)
        
        // Clean up all application observers
        for (_, observer) in applicationObservers {
            CFRunLoopRemoveSource(
                CFRunLoopGetCurrent(),
                AXObserverGetRunLoopSource(observer),
                .defaultMode
            )
        }
        applicationObservers.removeAll()
    }
}