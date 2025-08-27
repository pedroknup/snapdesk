//
//  SimpleWindowManager.swift
//  snapdesk
//
//  Created by Pedro Knup on 27/08/2025.
//

import Foundation
import AppKit

class SimpleWindowManager: WindowManaging {
    
    private var currentBundleIDCycling: String?
    private var bundleIDCycleIndex: Int = 0
    private var windowIndexWithinSet: Int = 0
    private var currentWindowSet: WindowSet?
    
    // New state for tracking the current focus within the active WindowSet
    private var currentFocusedWindowSetID: UUID?
    private var currentWindowIndexInActiveSet: Int = 0
    
    private var workspace: WorkspaceModel

    init() {
        var ws = snapdesk.WorkspaceModel()

        let discovered = scanWindows()
        for (win, screen) in discovered {
            if let idx = ws.screens.firstIndex(where: { $0.screen == screen }) {
                // Create a fresh WindowSet just for this window
                let newSet = WindowSet(layout: .wide, windows: [win], screenID: screen.screenID())
                ws.screens[idx].windowSets.append(newSet)
            }
        }

        self.workspace = ws
        
        // Setup window observers
        setupWindowObservers()

        print("Workspace initialized with \(ws.screens.count) screens and \(discovered.count) windows")

        for screenWS in ws.screens {
            let frame = screenWS.screen.frame()
            print("\n🖥️  Screen \(screenWS.screen.screenID() ?? "?") frame=\(NSStringFromRect(frame))")

            for (setIndex, set) in screenWS.windowSets.enumerated() {
                let windowCount = set.windows.count
                print("   ▾ WindowSet \(setIndex) [layout=\(set.layout)] — \(windowCount) window(s)")

                if set.windows.isEmpty {
                    print("      (no windows)")
                } else {
                    for (wIndex, w) in set.windows.enumerated() {
                        let title = w.title() ?? "<untitled>"
                        let rect  = NSStringFromRect(w.frame())
                        print("      [\(wIndex)] PID \(w.pid()) — \"\(title)\" frame=\(rect)")
                    }
                }
            }
        }
    }

    
    func addWindowToLayout(_ bundleID: String) {
        log("➕ addWindowToLayout(\(bundleID)) called")
        
        // Use the current WindowSet if it exists
        guard let currentWindowSet = currentWindowSet else {
            log("❌ No current WindowSet - focus an app first")
            return
        }
        
        guard let (nextWindowSet, windowToAdd) = getNextWindowSetToFocus(for: bundleID) else {
            log("❌ No next window found to add to layout")
            return
        }
        
        
        guard let windowToAdd = windowToAdd else {
            log("❌ No window found in next WindowSet to add")
            return
        }
        
        log("🔄 Adding window '\(windowToAdd.title() ?? "<untitled>")' to current WindowSet")
        
        // Add the window to the current WindowSet
        currentWindowSet.windows.append(windowToAdd)
        
        // Remove the window from its original WindowSet and clean up empty sets
        removeWindowFromOriginalWindowSet(windowToAdd, bundleID: bundleID)
        
        // Expand all windows in the updated WindowSet according to its layout
        currentWindowSet.expandWindows()
        
        // Focus the newly added window
        log("🎯 Focusing newly added window: \(windowToAdd.title() ?? "<untitled>")")
        windowToAdd.focus()
        
        // Move cursor to center of newly focused window
        moveCursorToCenter(of: windowToAdd)
        
        log("✅ Window successfully added to layout. WindowSet now has \(currentWindowSet.windows.count) windows")
    }
    
    /// Gets the bundle ID for the first window in a WindowSet
    private func getCurrentWindowSetBundleID(_ windowSet: WindowSet) -> String? {
        guard let firstWindow = windowSet.windows.first else { return nil }
        guard let app = NSRunningApplication(processIdentifier: firstWindow.pid()) else { return nil }
        return app.bundleIdentifier
    }
    
    /// Gets the next window that should be added to the current layout
    private func getNextWindowToAdd(for bundleID: String) -> (WindowSet, AXWindow?)? {
        let windowSets = windowSets(for: bundleID)
        guard windowSets.count > 1 else {
            log("❌ Only one WindowSet found for \(bundleID), nothing to add")
            return nil
        }
        
        // Get the next WindowSet in the cycle (the one that would be focused next)
        let nextCycleIndex = (bundleIDCycleIndex + 1) % windowSets.count
        let nextWindowSet = windowSets[nextCycleIndex]
        let windowToAdd = nextWindowSet.windows.first
        
        return (nextWindowSet, windowToAdd)
    }
    
    /// Removes a window from its original WindowSet and cleans up empty WindowSets
    private func removeWindowFromOriginalWindowSet(_ window: AXWindow, bundleID: String) {
        for screenIndex in workspace.screens.indices {
            for windowSetIndex in workspace.screens[screenIndex].windowSets.indices.reversed() {
                let windowSet = workspace.screens[screenIndex].windowSets[windowSetIndex]
                
                // Check if this WindowSet contains the window and belongs to the same app
                if let windowIndex = windowSet.windows.firstIndex(where: { $0.cgID() == window.cgID() }) {
                    // Remove the window from this WindowSet
                    windowSet.windows.remove(at: windowIndex)
                    log("🗑️ Removed window from original WindowSet")
                    
                    // If the WindowSet is now empty, remove it entirely
                    if windowSet.windows.isEmpty {
                        workspace.screens[screenIndex].windowSets.remove(at: windowSetIndex)
                        log("🧹 Removed empty WindowSet")
                    }
                    return
                }
            }
        }
    }
    
    
    private func currentWindow() -> AXUIElement? {
         return frontmostWindow()
     }
    
    private func screenList() -> [NSScreen] {
        // Sort screens in a stable order (menu bar first)
        return NSScreen.screens
    }
    
    // MARK: - Screen Management
    
    func toggleFullScreen() {
        log("🖥 toggleFullScreen() called")
        // TODO: Implement full screen toggle functionality
    }
    
    func focusScreen(_ screenNumber: Int) {
        log("🎯 focusScreen(\(screenNumber)) called")
        // TODO: Implement screen focus functionality
    }
    
    func throwToScreen(_ screenNumber: Int) {
        log("📤 throwToScreen(\(screenNumber)) called")
        
        // Get the currently focused window
        guard let focusedWindow = frontmostWindow() else {
            log("❌ No focused window found")
            FloatingWindowHelper.showFloatingWindow(
                text: "No focused window", 
                position: .center, 
                duration: 2.0
            )
            return
        }
        
        let axWindow = AXWindow(axElement: focusedWindow)
        
        // Get available screens (sorted consistently)
        let screens = AMScreen.availableScreens
        let screenIndex = screenNumber - 1  // Convert 1-based to 0-based index
        
        guard screenIndex >= 0 && screenIndex < screens.count else {
            log("❌ Invalid screen number: \(screenNumber) (only \(screens.count) screens available)")
            FloatingWindowHelper.showFloatingWindow(
                text: "Screen \(screenNumber) not available", 
                position: .center, 
                duration: 2.0
            )
            return
        }
        
        let targetScreen = screens[screenIndex]
        log("🎯 Throwing window '\(axWindow.title() ?? "<untitled>")' to screen \(screenNumber)")
        
        // Find the current WindowSet containing this window
        if let (currentWindowSet, windowIndex, _) = findWindowSetContaining(axWindow) {
            log("📦 Found window in WindowSet with \(currentWindowSet.windows.count) windows")
            
            // Remove window from current WindowSet
            currentWindowSet.windows.remove(at: windowIndex)
            
            // Clean up empty WindowSet
            if currentWindowSet.windows.isEmpty {
                removeEmptyWindowSet(currentWindowSet)
            } else {
                // Re-expand remaining windows in the original WindowSet
                currentWindowSet.expandWindows()
            }
        }
        
        // Create a new WindowSet on the target screen
        let newWindowSet = WindowSet(layout: .wide, windows: [axWindow], screenID: targetScreen.screenID())
        
        // Add the new WindowSet to the target screen's workspace
        if let screenWSIndex = workspace.screens.firstIndex(where: { $0.screen == targetScreen }) {
            workspace.screens[screenWSIndex].windowSets.append(newWindowSet)
        } else {
            // Create new screen workspace if it doesn't exist
            let newScreenWS = ScreenWorkspace(screen: targetScreen, sets: [newWindowSet])
            workspace.screens.append(newScreenWS)
        }
        
        // Expand the window on the new screen
        newWindowSet.expandWindows()
        
        // Focus the moved window
        axWindow.focus()
        moveCursorToCenter(of: axWindow)
        
        // Show confirmation
        FloatingWindowHelper.showFloatingWindow(
            text: "Moved to Screen \(screenNumber)", 
            position: .center, 
            duration: 1.5
        )
        
        log("✅ Successfully threw window to screen \(screenNumber)")
    }
    
    // MARK: - App Management
    
    func focusApp(_ bundleID: String) {
        log("🎯 NEW focusApp(\(bundleID)) called")
        
        guard let (windowSet, targetWindow) = getNextWindowSetToFocus(for: bundleID) else {
            // No windows found - try to launch the app
            log("🚀 No windows found for \(bundleID), attempting to launch app")
            launchApp(bundleID: bundleID)
            return
        }
        
        // Expand all windows in the current WindowSet according to its layout
        windowSet.expandWindows()
        
        if let targetWindow = targetWindow {
            log("🎯 Focusing window: \(targetWindow.title() ?? "<untitled>")")
            targetWindow.focus()
            
            // Move cursor to center of focused window
            moveCursorToCenter(of: targetWindow)
        }
    }
    
    /// Returns the next WindowSet that should be focused for a given bundle ID and the target window within it
    /// - Parameter bundleID: The bundle identifier of the app
    /// - Returns: A tuple containing the WindowSet to focus and the target window, or nil if no windows exist
    private func getNextWindowSetToFocus(for bundleID: String) -> (WindowSet, AXWindow?)? {
        let windowSets = windowSets(for: bundleID)
        log("Found \(windowSets.count) WindowSets for \(bundleID)")
        
        guard !windowSets.isEmpty else {
            return nil
        }
        
        // Check if we're cycling through the same app
        if currentBundleIDCycling != bundleID {
            // Reset cycling for new app
            currentBundleIDCycling = bundleID
            bundleIDCycleIndex = 0
            windowIndexWithinSet = 0
            currentFocusedWindowSetID = nil
            currentWindowIndexInActiveSet = 0
            log("🔄 Starting new cycle for \(bundleID) - available WindowSets: \(windowSets.count)")
        } else {
            // Continue cycling through the same app
            // Ensure bundleIDCycleIndex is within bounds
            if bundleIDCycleIndex >= windowSets.count {
                bundleIDCycleIndex = 0
                log("⚠️ bundleIDCycleIndex was out of bounds, resetting to 0")
            }
            
            let currentSet = windowSets[bundleIDCycleIndex]
            let bundleWindowsInCurrentSet = currentSet.windows.filter { window in
                guard let app = NSRunningApplication(processIdentifier: window.pid()) else { return false }
                return app.bundleIdentifier == bundleID
            }
            
            // Check if we're still in the same WindowSet and have more windows to cycle through
            if currentFocusedWindowSetID == currentSet.id && bundleWindowsInCurrentSet.count > 1 {
                // Cycle to next window within the same WindowSet
                currentWindowIndexInActiveSet = (currentWindowIndexInActiveSet + 1) % bundleWindowsInCurrentSet.count
                log("🔄 Cycling to window \(currentWindowIndexInActiveSet) within WindowSet (has \(bundleWindowsInCurrentSet.count) windows)")
            } else {
                // Move to next WindowSet
                bundleIDCycleIndex = (bundleIDCycleIndex + 1) % windowSets.count
                windowIndexWithinSet = 0
                currentWindowIndexInActiveSet = 0
                log("🔄 Moving to next WindowSet \(bundleIDCycleIndex) for \(bundleID)")
            }
        }
        
        // Ensure bundleIDCycleIndex is still within bounds before final access
        if bundleIDCycleIndex >= windowSets.count {
            bundleIDCycleIndex = 0
            log("⚠️ bundleIDCycleIndex was out of bounds at final access, resetting to 0")
        }
        
        let currentSet = windowSets[bundleIDCycleIndex]
        
        // Find the target window from the bundle within the current WindowSet
        let bundleWindowsInSet = currentSet.windows.filter { window in
            guard let app = NSRunningApplication(processIdentifier: window.pid()) else { return false }
            return app.bundleIdentifier == bundleID
        }
        
        log("📊 WindowSet \(bundleIDCycleIndex) has \(currentSet.windows.count) total windows, \(bundleWindowsInSet.count) from bundle \(bundleID)")
        
        // Use the new cycling index for window selection
        let targetWindow: AXWindow?
        if currentFocusedWindowSetID == currentSet.id && bundleWindowsInSet.count > currentWindowIndexInActiveSet {
            targetWindow = bundleWindowsInSet[currentWindowIndexInActiveSet]
        } else {
            targetWindow = bundleWindowsInSet.first
            currentWindowIndexInActiveSet = 0
        }
        
        // Update the focused WindowSet ID
        currentFocusedWindowSetID = currentSet.id
        
        if let targetWindow = targetWindow {
            log("✅ Selected target window: \(targetWindow.title() ?? "<untitled>") (index \(currentWindowIndexInActiveSet) of \(bundleWindowsInSet.count))")
            
            // Debug: Show all windows in the current set with their indices
            if bundleWindowsInSet.count > 1 {
                log("🔍 Available windows in WindowSet \(currentSet.id):")
                for (index, window) in bundleWindowsInSet.enumerated() {
                    let marker = index == currentWindowIndexInActiveSet ? "→" : " "
                    log("  \(marker) [\(index)] \(window.title() ?? "<untitled>")")
                }
            }
        } else {
            log("❌ No target window found in WindowSet \(bundleIDCycleIndex) for bundle \(bundleID)")
        }
        
        // Store the current WindowSet for potential use in addWindowToLayout
        currentWindowSet = currentSet
        
        return (currentSet, targetWindow)
    }
    
    /// Moves the mouse cursor to the center of the given window
    private func moveCursorToCenter(of window: AXWindow) {
        let windowFrame = window.frame()
        let centerPoint = NSPoint(
            x: windowFrame.midX,
            y: windowFrame.midY
        )
        
        log("🖱️ Moving cursor to center of window at \(NSStringFromPoint(centerPoint))")
        
        // Create and post mouse move event
        if let mouseMoveEvent = CGEvent(
            mouseEventSource: nil,
            mouseType: .mouseMoved,
            mouseCursorPosition: centerPoint,
            mouseButton: .left
        ) {
            mouseMoveEvent.flags = CGEventFlags(rawValue: 0)
            mouseMoveEvent.post(tap: .cghidEventTap)
        }
    }
    
    private func launchApp(bundleID: String) {
        log("🚀 Launching app with bundle ID: \(bundleID)")
        
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
                    
                    // Reset cycling state for the newly launched app
                    DispatchQueue.main.async {
                        self.currentBundleIDCycling = bundleID
                        self.bundleIDCycleIndex = 0
                        self.currentFocusedWindowSetID = nil
                        self.currentWindowIndexInActiveSet = 0
                        
                        // Give the app time to create windows, then refresh
                        DispatchQueue.main.asyncAfter(deadline: .now() + 1.5) {
                            self.refreshWindows()
                        }
                    }
                }
            }
        } else {
            log("❌ Could not find app with bundle ID: \(bundleID)")
        }
    }
    
    // MARK: - WindowManaging methods

       func focusScreen(at index: Int) {
           let screens = screenList()
           guard index < screens.count else { return }
           let targetScreen = screens[index]

           // Find a window on that screen and focus it
           if let window = windowOnScreen(targetScreen) {
               AXUIElementSetAttributeValue(window, kAXFocusedAttribute as CFString, kCFBooleanTrue)
           }
       }

       func throwFrontmostWindow(toScreen index: Int) {
           log("📤 throwFrontmostWindow(toScreen: \(index)) called")
           // Use the new throwToScreen method with 1-based indexing
           throwToScreen(index + 1)
       }

       func throwToCurrentLayout() {
           guard let window = currentWindow(),
                 let screen = NSScreen.main else { return }

           // Example: tile full width, half height
           let vf = screen.visibleFrame
           let target = CGRect(x: vf.minX,
                               y: vf.midY,
                               width: vf.width,
                               height: vf.height/2)
           move(window: window, to: target)
       }

       func increaseMainPanelCount() {
           print("TODO: implement layout engine, increase main count")
       }

       func decreaseMainPanelCount() {
           print("TODO: implement layout engine, decrease main count")
       }

       func cycleWindowsClockwise() {
           print("TODO: cycle window focus clockwise")
       }

       func cycleWindowsCounterclockwise() {
           print("TODO: cycle window focus counterclockwise")
       }

       func removeCurrentWindowFromLayout() {
           log("🗑️ removeCurrentWindowFromLayout() called")
           
           // Get the currently focused window
           guard let focusedWindow = frontmostWindow() else {
               log("❌ No focused window found")
               return
           }
           
           let axWindow = AXWindow(axElement: focusedWindow)
           
           log("🎯 Removing window from layout: \(axWindow.title() ?? "<untitled>")")
           
           // Find which WindowSet contains the focused window
           guard let (windowSet, windowIndex, screenIndex) = findWindowSetContaining(axWindow) else {
               log("❌ Focused window not found in any WindowSet")
               return
           }
           
           // Check if the WindowSet has more than one window
           if windowSet.windows.count <= 1 {
               log("⚠️ WindowSet only has one window - nothing to remove from layout")
               return
           }
           
           log("📤 Removing window from WindowSet with \(windowSet.windows.count) windows")
           
           // Determine which window should be focused after removal (the previous one, or first if removing first)
           let windowToFocusIndex = windowIndex > 0 ? windowIndex - 1 : 0
           let windowToFocus = windowSet.windows[windowToFocusIndex]
           
           // Remove the window from the current WindowSet
           windowSet.windows.remove(at: windowIndex)
           
           // Create a new standalone WindowSet for the removed window
           guard let nsScreen: NSScreen = axWindow.screen() else {
               log("❌ Could not determine screen for window")
               return
           }
           
           let screen = AMScreen(screen: nsScreen)
           
           let newWindowSet = WindowSet(layout: .wide, windows: [axWindow], screenID: screen.screenID())
           
           // Add the new WindowSet to the appropriate screen workspace
           if let screenWSIndex = workspace.screens.firstIndex(where: { $0.screen == screen }) {
               workspace.screens[screenWSIndex].windowSets.append(newWindowSet)
           }
           
           // Expand the original WindowSet (now with one less window) and focus the previous window
           windowSet.expandWindows()
           
           // Focus the window that was before the removed window in the original layout
           windowToFocus.focus()
           moveCursorToCenter(of: windowToFocus)
           
           log("✅ Successfully removed window from layout. Original WindowSet now has \(windowSet.windows.count) windows, focused: \(windowToFocus.title() ?? "<untitled>")")
       }
       
       func toggleLayoutForCurrentWindowSet() {
           log("🔄 toggleLayoutForCurrentWindowSet() called")
           
           // Use the current WindowSet if available, otherwise find it from the focused window
           var targetWindowSet: WindowSet?
           
           if let currentWindowSet = currentWindowSet {
               targetWindowSet = currentWindowSet
           } else {
               // Try to find the WindowSet containing the current focused window
               guard let focusedWindow = frontmostWindow() else {
                   log("❌ No focused window found and no current WindowSet")
                   return
               }
               
               let axWindow = AXWindow(axElement: focusedWindow)
               if let (windowSet, _, _) = findWindowSetContaining(axWindow) {
                   targetWindowSet = windowSet
                   currentWindowSet = windowSet
               }
           }
           
           guard let windowSet = targetWindowSet else {
               log("❌ No WindowSet found to toggle layout")
               return
           }
           
           log("🎯 Toggling layout for WindowSet with \(windowSet.windows.count) windows")
           windowSet.toggleLayout()
       }
       
       /// Finds the WindowSet containing the given window and returns the WindowSet, window index, and screen index
       private func findWindowSetContaining(_ window: AXWindow) -> (WindowSet, Int, Int)? {
           for (screenIndex, screenWS) in workspace.screens.enumerated() {
               for windowSet in screenWS.windowSets {
                   if let windowIndex = windowSet.windows.firstIndex(where: { $0.cgID() == window.cgID() }) {
                       return (windowSet, windowIndex, screenIndex)
                   }
               }
           }
           return nil
       }
       
       /// Removes an empty WindowSet from the workspace
       private func removeEmptyWindowSet(_ windowSet: WindowSet) {
           for screenIndex in workspace.screens.indices {
               if let setIndex = workspace.screens[screenIndex].windowSets.firstIndex(where: { $0.id == windowSet.id }) {
                   workspace.screens[screenIndex].windowSets.remove(at: setIndex)
                   log("🧹 Removed empty WindowSet from screen \(screenIndex)")
                   break
               }
           }
       }

       func toggleFullScreenLayout() {
           guard let window = currentWindow(),
                 let screen = NSScreen.main else { return }
           let vf = screen.visibleFrame
           move(window: window, to: vf)
       }

       // MARK: - Utilities

       private func windowOnScreen(_ screen: NSScreen) -> AXUIElement? {
           // Super simple: if the frontmost window is already on this screen, return it
           if let w = currentWindow(),
              let f = windowFrame(of: w),
              f.intersects(screen.frame) {
               return w
           }
           return nil
       }
    
    /// Returns all WindowSets that contain at least one window belonging to the given bundle ID, sorted consistently.
    private func windowSetsold(for bundleID: String) -> [WindowSet] {
        var matchingSets: [WindowSet] = []

        for screenWS in workspace.screens {
            for set in screenWS.windowSets {
                let matches = set.windows.contains { win in
                    guard let app = NSRunningApplication(processIdentifier: win.pid()) else {
                        return false
                    }
                    return app.bundleIdentifier == bundleID
                }

                if matches {
                    matchingSets.append(set)
                }
            }
        }

       return matchingSets
    }
    
    // MARK: - Window Observers
    
    private func setupWindowObservers() {
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
        
        // Set up accessibility observer for window focus changes
        setupAccessibilityObserver()
    }
    
    @objc private func applicationDidLaunch(_ notification: Notification) {
        guard let app = notification.userInfo?[NSWorkspace.applicationUserInfoKey] as? NSRunningApplication else {
            return
        }
        
        log("🚀 Application launched: \(app.localizedName ?? "Unknown") (\(app.bundleIdentifier ?? "no bundle"))")
        
        // Give the app a moment to create windows
        DispatchQueue.main.asyncAfter(deadline: .now() + 1.0) { [weak self] in
            self?.refreshWindows()
        }
    }
    
    @objc private func applicationDidTerminate(_ notification: Notification) {
        guard let app = notification.userInfo?[NSWorkspace.applicationUserInfoKey] as? NSRunningApplication else {
            return
        }
        
        log("❌ Application terminated: \(app.localizedName ?? "Unknown") (\(app.bundleIdentifier ?? "no bundle"))")
        
        // Reset cycling if the terminated app was being cycled
        if let bundleID = app.bundleIdentifier, bundleID == currentBundleIDCycling {
            currentBundleIDCycling = nil
            bundleIDCycleIndex = 0
            windowIndexWithinSet = 0
            currentWindowSet = nil
            currentFocusedWindowSetID = nil
            currentWindowIndexInActiveSet = 0
        }
        
        refreshWindows()
    }
    
    @objc private func applicationDidActivate(_ notification: Notification) {
        guard let app = notification.userInfo?[NSWorkspace.applicationUserInfoKey] as? NSRunningApplication else {
            return
        }
        
        log("🎯 Application activated: \(app.localizedName ?? "Unknown") (\(app.bundleIdentifier ?? "no bundle"))")
        
        // Reset cycling if a different app was activated manually
        if let bundleID = app.bundleIdentifier, bundleID != currentBundleIDCycling {
            currentBundleIDCycling = nil
            bundleIDCycleIndex = 0
            windowIndexWithinSet = 0
            currentWindowSet = nil
            currentFocusedWindowSetID = nil
            currentWindowIndexInActiveSet = 0
        }
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
    
    @objc private func windowDidBecomeKey(_ notification: Notification) {
        // Only update if this is a window change we care about
        DispatchQueue.main.async { [weak self] in
            self?.updateCurrentWindowSetFromFocus()
        }
    }
    
    @objc private func windowDidBecomeMain(_ notification: Notification) {
        // Only update if this is a window change we care about  
        DispatchQueue.main.async { [weak self] in
            self?.updateCurrentWindowSetFromFocus()
        }
    }
    
    /// Efficiently updates currentWindowSet based on the current focus (called only when focus actually changes)
    private func updateCurrentWindowSetFromFocus() {
        guard let focusedWindow = frontmostWindow() else { return }
        let axWindow = AXWindow(axElement: focusedWindow)
        
        // Find which WindowSet contains this focused window
        for screenWS in workspace.screens {
            for windowSet in screenWS.windowSets {
                if windowSet.windows.contains(where: { $0.cgID() == axWindow.cgID() }) {
                    // Update currentWindowSet if it's different
                    if currentWindowSet?.id != windowSet.id {
                        currentWindowSet = windowSet
                        
                        // Update cycling state for the focused window's app
                        if let app = NSRunningApplication(processIdentifier: axWindow.pid()),
                           let bundleID = app.bundleIdentifier {
                            
                            // If we switched to a different app, reset cycling
                            if currentBundleIDCycling != bundleID {
                                currentBundleIDCycling = bundleID
                                bundleIDCycleIndex = 0
                            }
                            
                            // Update the cycle index to match the focused WindowSet
                            let windowSets = windowSets(for: bundleID)
                            if let setIndex = windowSets.firstIndex(where: { $0.id == windowSet.id }) {
                                bundleIDCycleIndex = setIndex
                                
                                // Find the window index within the WindowSet
                                if let windowIndex = windowSet.windows.firstIndex(where: { $0.cgID() == axWindow.cgID() }) {
                                    windowIndexWithinSet = windowIndex
                                } else {
                                    windowIndexWithinSet = 0
                                }
                            }
                        }
                        
                        log("🎯 Focus changed to WindowSet with \(windowSet.windows.count) window(s)")
                    }
                    return
                }
            }
        }
    }
    
    private func refreshWindows() {
        log("🔄 Refreshing windows...")
        
        // Clear existing window sets
        for i in workspace.screens.indices {
            workspace.screens[i].windowSets.removeAll()
        }
        
        // Rescan windows and rebuild window sets
        let discovered = scanWindows()
        for (win, screen) in discovered {
            if let idx = workspace.screens.firstIndex(where: { $0.screen == screen }) {
                addWindow(win, to: &workspace.screens[idx])
            }
        }
        
        log("✅ Window refresh complete. Total windows: \(discovered.count)")
    }
    
    private func addWindow(_ window: AXWindow, to screenWS: inout ScreenWorkspace) {
        // Create a separate WindowSet for each window to enable cycling
        let newSet = WindowSet(layout: .wide, windows: [window], screenID: screenWS.screen.screenID())
        screenWS.windowSets.append(newSet)
    }
    
    /// Returns all WindowSets that contain at least one window belonging to the given bundle ID, sorted consistently.
    private func windowSets(for bundleID: String) -> [WindowSet] {
        var matchingSets: [WindowSet] = []
        var seenWindowIDs: Set<CGWindowID> = []

        for screenWS in workspace.screens {
            for set in screenWS.windowSets {
                // Filter windows in this set to only those belonging to the requested bundle
                let bundleWindows = set.windows.filter { win in
                    guard let app = NSRunningApplication(processIdentifier: win.pid()) else {
                        return false
                    }
                    return app.bundleIdentifier == bundleID
                }

                // Only include WindowSets that have windows from this bundle that we haven't seen before
                let uniqueBundleWindows = bundleWindows.filter { window in
                    let windowID = window.cgID()
                    if seenWindowIDs.contains(windowID) {
                        return false // Skip duplicate window
                    }
                    seenWindowIDs.insert(windowID)
                    return true
                }

                if !uniqueBundleWindows.isEmpty {
                    matchingSets.append(set)
                }
            }
        }

        log("🔍 Found \(matchingSets.count) WindowSets containing windows for \(bundleID)")
        
        // Debug: Show details of each WindowSet found
        for (index, set) in matchingSets.enumerated() {
            let bundleWindows = set.windows.filter { win in
                guard let app = NSRunningApplication(processIdentifier: win.pid()) else { return false }
                return app.bundleIdentifier == bundleID
            }
            let windowTitles = bundleWindows.map { $0.title() ?? "<untitled>" }.joined(separator: ", ")
            log("  WindowSet \(index): \(bundleWindows.count) \(bundleID) windows - [\(windowTitles)]")
        }
        
        return matchingSets
    }
    
    deinit {
        NSWorkspace.shared.notificationCenter.removeObserver(self)
    }
}
