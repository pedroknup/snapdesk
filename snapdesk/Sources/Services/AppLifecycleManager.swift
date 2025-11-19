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
                    DispatchQueue.main.asyncAfter(deadline: .now() + 1.5) {
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
        DispatchQueue.main.asyncAfter(deadline: .now() + 1.0) { [weak self] in
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
        guard app.bundleIdentifier != nil else { return }
        
        let pid = app.processIdentifier
        
        // Skip if we already have an observer for this app
        guard applicationObservers[pid] == nil else { return }
        
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
            }
        }, &observer)
        
        guard result == .success, let observer = observer else {
            return
        }
        
        // Add observer for window creation notifications on this application
        let addResult = AXObserverAddNotification(
            observer,
            appElement,
            kAXCreatedNotification as CFString,
            Unmanaged.passUnretained(self).toOpaque()
        )
        
        if addResult == .success {
            // Start observing
            CFRunLoopAddSource(
                CFRunLoopGetCurrent(),
                AXObserverGetRunLoopSource(observer),
                .defaultMode
            )
            applicationObservers[pid] = observer
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
        
        guard role == (kAXWindowRole as String),
              subrole != (kAXSystemDialogSubrole as String),
              subrole != (kAXFloatingWindowSubrole as String),
              subrole != "AXSheet" else {
            return
        }
        
        // Get the window's process ID to identify the app
        var pid: pid_t = 0
        guard AXUIElementGetPid(windowElement, &pid) == .success,
              let app = NSRunningApplication(processIdentifier: pid),
              let bundleID = app.bundleIdentifier else {
            return
        }
        
        // Skip SnapDesk's own windows immediately
        if bundleID == "com.pedroknup.snapdesk" {
            return
        }
        
        // Create AXWindow wrapper
        let axWindow = AXWindow(axElement: windowElement)
        
        // Check if this window should be managed before adding it
        guard axWindow.shouldBeManaged() else {
            return
        }
        
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