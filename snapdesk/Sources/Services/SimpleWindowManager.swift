//
//  SimpleWindowManager.swift
//  snapdesk
//
//  Created by Pedro Knup on 27/08/2025.
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

class SimpleWindowManager: WindowManaging {
    
    private var currentBundleIDCycling: String?
    private var bundleIDCycleIndex: Int = 0
    private var windowIndexWithinSet: Int = 0
    private var currentWindowSet: WindowSet?
    
    // New state for tracking the current focus within the active WindowSet
    private var currentFocusedWindowSetID: UUID?
    private var currentWindowIndexInActiveSet: Int = 0
    
    // Flag to track when we're programmatically focusing an app via hotkey
    private var isProgrammaticFocus: Bool = false
    
    private var workspace: WorkspaceModel

    /// Gets the default layout mode from settings
    private func getDefaultLayoutMode() -> LayoutKind {
        let defaultLayoutString = UserDefaults.standard.string(forKey: "defaultLayoutMode") ?? "wide"
        
        switch defaultLayoutString.lowercased() {
        case "tall":
            return .tall
        case "fullscreen":
            return .fullscreen
        case "floating":
            return .floating
        default:
            return .wide
        }
    }
    
    /// Gets whether auto-expand new windows is enabled
    private func shouldAutoExpandNewWindows() -> Bool {
        return UserDefaults.standard.object(forKey: "autoExpandNewWindows") as? Bool ?? true
    }

    init() {
        // Initialize workspace first
        var ws = snapdesk.WorkspaceModel()
        self.workspace = ws

        let discovered = scanWindows()
        let defaultLayout = getDefaultLayoutMode()
        
        for (win, screen) in discovered {
            if let idx = workspace.screens.firstIndex(where: { $0.screen == screen }) {
                // Create a fresh WindowSet with the default layout
                let newSet = WindowSet(layout: defaultLayout, windows: [win], screenID: screen.screenID())
                workspace.screens[idx].windowSets.append(newSet)
                
                // Auto-expand the window if the setting is enabled (without bringing to front during startup)
                if shouldAutoExpandNewWindows() {
                    newSet.expandWindows(on: screen, bringToFront: false)
                }
            }
        }
        
        // Setup window observers
        setupWindowObservers()
        
        // Setup screen change observer
        setupScreenChangeObserver()
        
        // Final comprehensive pass: Ensure ALL windows are expanded if auto-expand is enabled
        if shouldAutoExpandNewWindows() {
            DispatchQueue.main.async { [weak self] in
                guard let self = self else { return }
                
                for screenWS in self.workspace.screens {
                    for windowSet in screenWS.windowSets {
                        // Expand windows without bringing to front during startup
                        windowSet.expandWindows(on: screenWS.screen, bringToFront: false)
                    }
                }
            }
        }

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
        log("➕ addWindowToLayout called for bundleID: \(bundleID)")
        
        // Use the current WindowSet if it exists
        guard let currentWindowSet = currentWindowSet else {
            log("❌ No current WindowSet - focus an app first")
            return
        }
        
        // Find all WindowSets that contain windows from this bundle
        let allWindowSets = windowSets(for: bundleID)
        log("📊 Found \(allWindowSets.count) WindowSets for \(bundleID)")
        
        // Find a window from this bundle that's NOT in the current WindowSet
        var windowToAdd: AXWindow? = nil
        var sourceWindowSet: WindowSet? = nil
        
        for windowSet in allWindowSets {
            // Skip the current WindowSet
            if windowSet.id == currentWindowSet.id {
                continue
            }
            
            // Find windows in this set that belong to the bundle
            for window in windowSet.windows {
                guard let app = NSRunningApplication(processIdentifier: window.pid()),
                      app.bundleIdentifier == bundleID else { continue }
                
                // Found a window to add
                windowToAdd = window
                sourceWindowSet = windowSet
                break
            }
            
            if windowToAdd != nil {
                break
            }
        }
        
        guard let windowToAdd = windowToAdd else {
            log("❌ No window found from bundle \(bundleID) outside current WindowSet")
            return
        }
        
        log("🔄 Adding window '\(windowToAdd.title() ?? "<untitled>")' to current WindowSet")
        
        // Add the window to the current WindowSet
        currentWindowSet.windows.append(windowToAdd)
        
        // Remove the window from its original WindowSet and clean up empty sets
        removeWindowFromOriginalWindowSet(windowToAdd, bundleID: bundleID)
        
        // If the layout is floating, change it to wide for proper tiling
        if currentWindowSet.layout == .floating {
            log("🔄 Changing layout from floating to wide for proper window arrangement")
            currentWindowSet.layout = .wide
        }
        
        // Log the current state before expanding
        log("📊 Current WindowSet has \(currentWindowSet.windows.count) windows, layout: \(currentWindowSet.layout), screenID: \(currentWindowSet.screenID ?? "nil")")
        
        // Expand all windows in the updated WindowSet according to its layout
        currentWindowSet.expandWindows()
        
        // Focus the newly added window
        windowToAdd.raise()
        windowToAdd.focus()
        moveCursorToCenter(of: windowToAdd)
        
        log("✅ Successfully added window to layout. WindowSet now has \(currentWindowSet.windows.count) windows")
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
        // TODO: Implement screen focus functionality
    }
    
    func throwToScreen(_ screenNumber: Int) {
        
        // Get the currently focused window
        guard let focusedWindow = frontmostWindow() else {
            log("❌ No focused window found")
            let showThrowNotifications = UserDefaults.standard.object(forKey: "showThrowNotifications") as? Bool ?? true
            if showThrowNotifications {
                FloatingWindowHelper.showFloatingWindow(
                    text: "No focused window", 
                    position: .center, 
                    duration: 2.0
                )
            }
            return
        }
        
        let axWindow = AXWindow(axElement: focusedWindow)
        
        // Get available screens (sorted consistently)
        let screens = AMScreen.availableScreens
        let screenIndex = screenNumber - 1  // Convert 1-based to 0-based index
        
        guard screenIndex >= 0 && screenIndex < screens.count else {
            let showThrowNotifications = UserDefaults.standard.object(forKey: "showThrowNotifications") as? Bool ?? true
            if showThrowNotifications {
                FloatingWindowHelper.showFloatingWindow(
                    text: "Screen \(screenNumber) not available", 
                    position: .center, 
                    duration: 2.0
                )
            }
            return
        }
        
        let targetScreen = screens[screenIndex]
        
        // Find the current WindowSet containing this window
        if let (currentWindowSet, windowIndex, _) = findWindowSetContaining(axWindow) {
            
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
        
        // Create a new WindowSet on the target screen with default layout
        let targetScreenID = targetScreen.screenID()
        let defaultLayout = getDefaultLayoutMode()
        let newWindowSet = WindowSet(layout: defaultLayout, windows: [axWindow], screenID: targetScreenID)
        
        log("📐 Created new WindowSet with screen ID: \(targetScreenID ?? "nil")")
        log("📐 Target screen frame: \(NSStringFromRect(targetScreen.adjustedFrame()))")
        
        // Add the new WindowSet to the target screen's workspace
        if let screenWSIndex = workspace.screens.firstIndex(where: { $0.screen == targetScreen }) {
            workspace.screens[screenWSIndex].windowSets.append(newWindowSet)
        } else {
            // Create new screen workspace if it doesn't exist
            let newScreenWS = ScreenWorkspace(screen: targetScreen, sets: [newWindowSet])
            workspace.screens.append(newScreenWS)
        }
        
        // Expand the window on the new screen if auto-expand is enabled
        if shouldAutoExpandNewWindows() {
            log("📐 Auto-expanding window to fit target screen boundaries with layout: \(defaultLayout)...")
            newWindowSet.expandWindows()
        } else {
            log("📐 Auto-expand disabled, window keeps its current size")
        }
        
        // Double-check: if expandWindows() didn't work, expand manually
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
            let currentFrame = axWindow.frame()
            let targetFrame = targetScreen.adjustedFrame()
            
            if !targetFrame.contains(currentFrame) || currentFrame.size != targetFrame.size {
                log("⚠️ Window not properly expanded, forcing manual expansion")
                log("📐 Current frame: \(NSStringFromRect(currentFrame))")
                log("📐 Target frame: \(NSStringFromRect(targetFrame))")
                
                // Force expand to full target screen
                move(window: axWindow.axElementRef, to: targetFrame)
            } else {
            }
        }
        
        // Focus the moved window
        axWindow.raise()
        axWindow.focus()
        moveCursorToCenter(of: axWindow)
        
        // Show confirmation if enabled in settings
        let showThrowNotifications = UserDefaults.standard.object(forKey: "showThrowNotifications") as? Bool ?? true
        if showThrowNotifications {
            FloatingWindowHelper.showFloatingWindow(
                text: "Moved to Screen \(screenNumber)", 
                position: .center, 
                duration: 1.5
            )
        }
        
    }
    
    // MARK: - App Management
    
    func focusApp(_ bundleID: String) async {
        
        // Set flag to indicate we're programmatically focusing
        isProgrammaticFocus = true
        
        guard let (windowSet, targetWindow) = getNextWindowSetToFocus(for: bundleID) else {
            // No windows found - try to launch the app
            launchApp(bundleID: bundleID)
            isProgrammaticFocus = false
            return
        }
        
        // Expand all windows in the current WindowSet according to its layout (if auto-expand is enabled)
        if shouldAutoExpandNewWindows() {
            windowSet.expandWindows()
        }
    
            await windowSet.raiseAllWindows(excluding: targetWindow)
        
        if let targetWindow = targetWindow {
            // First raise the window to ensure it's on top, especially important 
            // when cycling between windows of the same app in a split layout
            targetWindow.raise()
            // Then focus it
            targetWindow.focus()
            moveCursorToCenter(of: targetWindow)
        }
        
        // Reset the flag after a short delay to allow the focus events to fire
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) { [weak self] in
            self?.isProgrammaticFocus = false
        }
    }
    
    /// Returns the next WindowSet that should be focused for a given bundle ID and the target window within it
    /// - Parameter bundleID: The bundle identifier of the app
    /// - Returns: A tuple containing the WindowSet to focus and the target window, or nil if no windows exist
    private func getNextWindowSetToFocus(for bundleID: String) -> (WindowSet, AXWindow?)? {
        let windowSets = windowSets(for: bundleID)
        
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
        } else {
            // Continue cycling through the same app
                // Ensure bundleIDCycleIndex is within bounds
            if bundleIDCycleIndex >= windowSets.count {
                bundleIDCycleIndex = 0
            }
            
            let currentSet = windowSets[bundleIDCycleIndex]
            let bundleWindowsInCurrentSet = currentSet.windows.filter { window in
                guard let app = NSRunningApplication(processIdentifier: window.pid()) else { return false }
                return app.bundleIdentifier == bundleID
            }
            
            // Check if we need to move to the next window or WindowSet
            
            if currentFocusedWindowSetID == currentSet.id {
                // We're trying to cycle within the same WindowSet
                if bundleWindowsInCurrentSet.count > 1 {
                    // Multiple windows from this app in the set
                    let nextWindowIndex = currentWindowIndexInActiveSet + 1
                    if nextWindowIndex < bundleWindowsInCurrentSet.count {
                        // Move to next window within the same WindowSet
                        currentWindowIndexInActiveSet = nextWindowIndex
                    } else {
                        // We've reached the end of windows in this WindowSet, move to next WindowSet
                        bundleIDCycleIndex = (bundleIDCycleIndex + 1) % windowSets.count
                        windowIndexWithinSet = 0
                        currentWindowIndexInActiveSet = 0
                        currentFocusedWindowSetID = nil // Reset so we start fresh in the new WindowSet
                    }
                } else if bundleWindowsInCurrentSet.count == 1 {
                    // Only one window from this app in the set
                    // Check if we have more than one WindowSet with this app
                    if windowSets.count > 1 {
                        // Move to the next WindowSet that contains this app
                        bundleIDCycleIndex = (bundleIDCycleIndex + 1) % windowSets.count
                        windowIndexWithinSet = 0
                        currentWindowIndexInActiveSet = 0
                    } else {
                        // Only one WindowSet and only one window - stay on current window
                        // Don't change anything, will re-focus the same window
                    }
                }
            } else {
                // Not in the same WindowSet, move to next WindowSet
                bundleIDCycleIndex = (bundleIDCycleIndex + 1) % windowSets.count
                windowIndexWithinSet = 0
                currentWindowIndexInActiveSet = 0
            }
        }
        
        // Ensure bundleIDCycleIndex is still within bounds before final access
        if bundleIDCycleIndex >= windowSets.count {
            bundleIDCycleIndex = 0
        }
        
        let currentSet = windowSets[bundleIDCycleIndex]
        
        // Find the target window from the bundle within the current WindowSet
        let bundleWindowsInSet = currentSet.windows.filter { window in
            guard let app = NSRunningApplication(processIdentifier: window.pid()) else { return false }
            return app.bundleIdentifier == bundleID
        }
        
        
        // Use the new cycling index for window selection
        let targetWindow: AXWindow?
        if currentFocusedWindowSetID == currentSet.id && bundleWindowsInSet.count > currentWindowIndexInActiveSet {
            // We're continuing to cycle within the same WindowSet
            targetWindow = bundleWindowsInSet[currentWindowIndexInActiveSet]
        } else {
            // First time focusing this WindowSet or starting fresh
            targetWindow = bundleWindowsInSet.first
            // Find the actual index of this window in the bundle's windows
            if let target = targetWindow,
               let actualIndex = bundleWindowsInSet.firstIndex(where: { $0.cgID() == target.cgID() }) {
                currentWindowIndexInActiveSet = actualIndex
            } else {
                currentWindowIndexInActiveSet = 0
            }
        }
        
        // Update the focused WindowSet ID
        currentFocusedWindowSetID = currentSet.id
        
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
           
           let defaultLayout = getDefaultLayoutMode()
           let newWindowSet = WindowSet(layout: defaultLayout, windows: [axWindow], screenID: screen.screenID())
           
           // Add the new WindowSet to the appropriate screen workspace
           if let screenWSIndex = workspace.screens.firstIndex(where: { $0.screen == screen }) {
               workspace.screens[screenWSIndex].windowSets.append(newWindowSet)
           }
           
           // Expand the original WindowSet (now with one less window) and focus the previous window
           windowSet.expandWindows()
           
           // Focus the window that was before the removed window in the original layout
           windowToFocus.raise()
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
       
       func increaseMainPanelSize() {
           log("⬆️ increaseMainPanelSize() called")
           
           // Use the current WindowSet if available, otherwise find it from the focused window
           var targetWindowSet: WindowSet?
           
           if let currentWindowSet = currentWindowSet {
               targetWindowSet = currentWindowSet
           } else {
               // Try to find the WindowSet containing the current focused window
               guard let focusedWindow = frontmostWindow() else {
                   log("❌ No focused window found")
                   return
               }
               
               let axWindow = AXWindow(axElement: focusedWindow)
               if let (windowSet, _, _) = findWindowSetContaining(axWindow) {
                   targetWindowSet = windowSet
               }
           }
           
           guard let windowSet = targetWindowSet else {
               log("❌ No WindowSet found to adjust")
               return
           }
           
           // Only adjust if there are multiple windows
           guard windowSet.windows.count > 1 else {
               log("ℹ️ Cannot adjust main panel size with only one window")
               return
           }
           
           // Calculate reasonable max based on window count
           // Allow main panel to take up to 70% of total space
           let screen = AMScreen.availableScreens.first { $0.screenID() == windowSet.screenID }
           let screenFrame = screen?.adjustedFrame() ?? CGRect(x: 0, y: 0, width: 1920, height: 1080)
           let dimension = windowSet.layout == .wide ? screenFrame.width : screenFrame.height
           let maxAdjustment = dimension * 0.7 - (dimension / CGFloat(windowSet.windows.count))
           
           // Increase by 40 pixels, but respect the maximum
           let newAdjustment = min(windowSet.mainPanelSizeAdjustment + 40, maxAdjustment)
           
           if newAdjustment == windowSet.mainPanelSizeAdjustment {
               log("⚠️ Main panel is already at maximum size")
               // Show floating notification about max
               let showLayoutIndicator = UserDefaults.standard.object(forKey: "showLayoutIndicator") as? Bool ?? true
               if showLayoutIndicator {
                   FloatingWindowHelper.showFloatingWindow(
                       text: "Main Panel: MAX",
                       position: .center,
                       duration: 1.5
                   )
               }
               return
           }
           
           windowSet.mainPanelSizeAdjustment = newAdjustment
           log("📏 Main panel size adjustment is now: \(windowSet.mainPanelSizeAdjustment)px")
           
           // Re-expand windows with the new adjustment
           windowSet.expandWindows()
           
           // Show floating notification if enabled
           let showLayoutIndicator = UserDefaults.standard.object(forKey: "showLayoutIndicator") as? Bool ?? true
           if showLayoutIndicator {
               let adjustmentText = windowSet.mainPanelSizeAdjustment >= 0 ? "+\(Int(windowSet.mainPanelSizeAdjustment))" : "\(Int(windowSet.mainPanelSizeAdjustment))"
               FloatingWindowHelper.showFloatingWindow(
                   text: "Main Panel: \(adjustmentText)px",
                   position: .center,
                   duration: 1.5
               )
           }
       }
       
       func decreaseMainPanelSize() {
           log("⬇️ decreaseMainPanelSize() called")
           
           // Use the current WindowSet if available, otherwise find it from the focused window
           var targetWindowSet: WindowSet?
           
           if let currentWindowSet = currentWindowSet {
               targetWindowSet = currentWindowSet
           } else {
               // Try to find the WindowSet containing the current focused window
               guard let focusedWindow = frontmostWindow() else {
                   log("❌ No focused window found")
                   return
               }
               
               let axWindow = AXWindow(axElement: focusedWindow)
               if let (windowSet, _, _) = findWindowSetContaining(axWindow) {
                   targetWindowSet = windowSet
               }
           }
           
           guard let windowSet = targetWindowSet else {
               log("❌ No WindowSet found to adjust")
               return
           }
           
           // Only adjust if there are multiple windows
           guard windowSet.windows.count > 1 else {
               log("ℹ️ Cannot adjust main panel size with only one window")
               return
           }
           
           // Calculate reasonable min based on window count
           // Prevent main panel from being smaller than 30% of equal space
           let screen = AMScreen.availableScreens.first { $0.screenID() == windowSet.screenID }
           let screenFrame = screen?.adjustedFrame() ?? CGRect(x: 0, y: 0, width: 1920, height: 1080)
           let dimension = windowSet.layout == .wide ? screenFrame.width : screenFrame.height
           let equalSpace = dimension / CGFloat(windowSet.windows.count)
           let minAdjustment = equalSpace * 0.3 - equalSpace // This gives us -70% of equal space
           
           // Decrease by 40 pixels, but respect the minimum
           let newAdjustment = max(windowSet.mainPanelSizeAdjustment - 40, minAdjustment)
           
           if newAdjustment == windowSet.mainPanelSizeAdjustment {
               log("⚠️ Main panel is already at minimum size")
               // Show floating notification about min
               let showLayoutIndicator = UserDefaults.standard.object(forKey: "showLayoutIndicator") as? Bool ?? true
               if showLayoutIndicator {
                   FloatingWindowHelper.showFloatingWindow(
                       text: "Main Panel: MIN",
                       position: .center,
                       duration: 1.5
                   )
               }
               return
           }
           
           windowSet.mainPanelSizeAdjustment = newAdjustment
           log("📏 Main panel size adjustment is now: \(windowSet.mainPanelSizeAdjustment)px")
           
           // Re-expand windows with the new adjustment
           windowSet.expandWindows()
           
           // Show floating notification if enabled
           let showLayoutIndicator = UserDefaults.standard.object(forKey: "showLayoutIndicator") as? Bool ?? true
           if showLayoutIndicator {
               let adjustmentText = windowSet.mainPanelSizeAdjustment >= 0 ? "+\(Int(windowSet.mainPanelSizeAdjustment))" : "\(Int(windowSet.mainPanelSizeAdjustment))"
               FloatingWindowHelper.showFloatingWindow(
                   text: "Main Panel: \(adjustmentText)px",
                   position: .center,
                   duration: 1.5
               )
           }
       }
       
       func expandCurrentLayout() {
           log("🔲 expandCurrentLayout() called")
           
           // Use the current WindowSet if available, otherwise find it from the focused window
           var targetWindowSet: WindowSet?
           
           if let currentWindowSet = currentWindowSet {
               targetWindowSet = currentWindowSet
           } else {
               // Try to find the WindowSet containing the current focused window
               guard let focusedWindow = frontmostWindow() else {
                   log("❌ No focused window found")
                   return
               }
               
               let axWindow = AXWindow(axElement: focusedWindow)
               if let (windowSet, _, _) = findWindowSetContaining(axWindow) {
                   targetWindowSet = windowSet
                   currentWindowSet = windowSet
               }
           }
           
           guard let windowSet = targetWindowSet else {
               log("❌ No WindowSet found to expand")
               return
           }
           
           log("📐 Current layout: \(windowSet.layout) for WindowSet with \(windowSet.windows.count) window(s)")
           
           // If the layout is floating, change it to wide first
           if windowSet.layout == .floating {
               log("🔄 Changing layout from floating to wide before expanding")
               windowSet.layout = .wide
           }
           
           // Expand the windows in the current WindowSet
           windowSet.expandWindows()
           
           log("✅ Windows expanded according to \(windowSet.layout) layout")
           
           // Show floating notification if enabled
           let showLayoutIndicator = UserDefaults.standard.object(forKey: "showLayoutIndicator") as? Bool ?? true
           if showLayoutIndicator {
               let layoutText = "\(windowSet.layout)".capitalized
               FloatingWindowHelper.showFloatingWindow(
                   text: "Expanded: \(layoutText)",
                   position: .center,
                   duration: 1.5
               )
           }
       }
       
       // MARK: - Window Positioning
       
       private func positionSingleWindow(to position: String) {
           // Get the currently focused window
           guard let focusedWindow = frontmostWindow() else {
               log("❌ No focused window found")
               return
           }
           
           let axWindow = AXWindow(axElement: focusedWindow)
           
           // Find the WindowSet containing this window
           guard let (windowSet, _, _) = findWindowSetContaining(axWindow) else {
               log("❌ Window not found in any WindowSet")
               return
           }
           
           // Check if WindowSet has only one window
           if windowSet.windows.count > 1 {
               log("⚠️ Cannot position window - WindowSet has \(windowSet.windows.count) windows")
               let showLayoutIndicator = UserDefaults.standard.object(forKey: "showLayoutIndicator") as? Bool ?? true
               if showLayoutIndicator {
                   FloatingWindowHelper.showFloatingWindow(
                       text: "Cannot position: \(windowSet.windows.count) windows in layout",
                       position: .center,
                       duration: 2.0
                   )
               }
               return
           }
           
           // Change layout to floating
           if windowSet.layout != .floating {
               log("🔄 Changing layout to floating for window positioning")
               windowSet.layout = .floating
           }
           
           // Get the screen frame
           guard let nsScreen = axWindow.snapScreen()?.screen else {
               log("❌ Could not determine screen for window")
               return
           }
           let screen = AMScreen(screen: nsScreen)
           let screenFrame = screen.adjustedFrame()
           
           // Calculate the target frame based on position
           var targetFrame: CGRect
           let halfWidth = screenFrame.width / 2
           let halfHeight = screenFrame.height / 2
           
           switch position {
           case "left":
               targetFrame = CGRect(
                   x: screenFrame.minX,
                   y: screenFrame.minY,
                   width: halfWidth,
                   height: screenFrame.height
               )
           case "right":
               targetFrame = CGRect(
                   x: screenFrame.minX + halfWidth,
                   y: screenFrame.minY,
                   width: halfWidth,
                   height: screenFrame.height
               )
           case "top":
               // TODO: not quite working. Fix this
               targetFrame = CGRect(
                   x: screenFrame.minX,
                   y: screenFrame.minY,
                   width: screenFrame.width,
                   height: halfHeight
               )
           case "bottom":
               // TODO: not quite working. Fix this
               targetFrame = CGRect(
                   x: screenFrame.minX,
                   y: screenFrame.minY + halfHeight,
                   width: screenFrame.width,
                   height: halfHeight
               )
           case "topLeft":
               // TODO: not quite working. Fix this
               targetFrame = CGRect(
                   x: screenFrame.minX,
                   y: screenFrame.minY,
                   width: halfWidth,
                   height: halfHeight
               )
           case "topRight":
               // TODO: not quite working. Fix this
               targetFrame = CGRect(
                   x: screenFrame.minX + halfWidth,
                   y: screenFrame.minY,
                   width: halfWidth,
                   height: halfHeight
               )
           case "bottomLeft":
               // TODO: not quite working. Fix this
               targetFrame = CGRect(
                   x: screenFrame.minX,
                   y: screenFrame.minY + halfHeight,
                   width: halfWidth,
                   height: halfHeight
               )
           case "bottomRight":
               // TODO: not quite working. Fix this
               targetFrame = CGRect(
                   x: screenFrame.minX + halfWidth,
                   y: screenFrame.minY + halfHeight,
                   width: halfWidth,
                   height: halfHeight
               )
           case "center":
               let centerWidth = screenFrame.width * 0.6  // 60% of screen width
               let centerHeight = screenFrame.height * 0.6  // 60% of screen height
               targetFrame = CGRect(
                   x: screenFrame.minX + (screenFrame.width - centerWidth) / 2,
                   y: screenFrame.minY + (screenFrame.height - centerHeight) / 2,
                   width: centerWidth,
                   height: centerHeight
               )
           default:
               log("❌ Unknown position: \(position)")
               return
           }
           
           // Apply window margin from settings
           let windowMargin = CGFloat(UserDefaults.standard.object(forKey: "windowMargin") as? Double ?? 8.0)
           targetFrame = CGRect(
               x: targetFrame.minX + windowMargin,
               y: targetFrame.minY + windowMargin,
               width: targetFrame.width - (windowMargin * 2),
               height: targetFrame.height - (windowMargin * 2)
           )
           
           // Move the window
           move(window: axWindow.axElementRef, to: targetFrame)
           log("📐 Positioned window to \(position): \(NSStringFromRect(targetFrame))")
           
           // Show notification
           let showLayoutIndicator = UserDefaults.standard.object(forKey: "showLayoutIndicator") as? Bool ?? true
           if showLayoutIndicator {
               FloatingWindowHelper.showFloatingWindow(
                   text: "Window: \(position.capitalized)",
                   position: .center,
                   duration: 1.0
               )
           }
       }
       
       func positionWindowLeft() {
           log("⬅️ positionWindowLeft() called")
           positionSingleWindow(to: "left")
       }
       
       func positionWindowRight() {
           log("➡️ positionWindowRight() called")
           positionSingleWindow(to: "right")
       }
       
       func positionWindowTop() {
           log("⬆️ positionWindowTop() called")
           positionSingleWindow(to: "top")
       }
       
       func positionWindowBottom() {
           log("⬇️ positionWindowBottom() called")
           positionSingleWindow(to: "bottom")
       }
       
       func positionWindowTopLeft() {
           log("↖️ positionWindowTopLeft() called")
           positionSingleWindow(to: "topLeft")
       }
       
       func positionWindowTopRight() {
           log("↗️ positionWindowTopRight() called")
           positionSingleWindow(to: "topRight")
       }
       
       func positionWindowBottomLeft() {
           log("↙️ positionWindowBottomLeft() called")
           positionSingleWindow(to: "bottomLeft")
       }
       
       func positionWindowBottomRight() {
           log("↘️ positionWindowBottomRight() called")
           positionSingleWindow(to: "bottomRight")
       }
       
       func positionWindowCenter() {
           log("🎯 positionWindowCenter() called")
           positionSingleWindow(to: "center")
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
        
        // Set up application-specific AX observers for window creation
        setupApplicationObservers()
    }
    
    // MARK: - Screen Change Observer
    
    private func setupScreenChangeObserver() {
        // Listen for screen configuration changes
        NotificationCenter.default.addObserver(
            self,
            selector: #selector(screenParametersDidChange(_:)),
            name: NSApplication.didChangeScreenParametersNotification,
            object: nil
        )
    }
    
    @objc private func screenParametersDidChange(_ notification: Notification) {
        log("🖥️ Screen configuration changed, remapping windows...")
        
        // Store current window sets before updating screens
        var orphanedWindowSets: [WindowSet] = []
        let previousScreenIDs = Set(workspace.screens.compactMap { $0.screen.screenID() })
        
        // Get the new screens
        let newScreens = AMScreen.availableScreens
        let newScreenIDs = Set(newScreens.compactMap { $0.screenID() })
        
        // Find removed screen IDs
        let removedScreenIDs = previousScreenIDs.subtracting(newScreenIDs)
        
        if !removedScreenIDs.isEmpty {
            log("📤 Screens removed: \(removedScreenIDs)")
            
            // Collect all window sets from removed screens
            for screenWS in workspace.screens {
                if let screenID = screenWS.screen.screenID(), removedScreenIDs.contains(screenID) {
                    orphanedWindowSets.append(contentsOf: screenWS.windowSets)
                }
            }
        }
        
        // Update workspace with new screens
        workspace.refreshScreens()
        
        // Remap orphaned windows to their new screens
        if !orphanedWindowSets.isEmpty {
            log("🔄 Remapping \(orphanedWindowSets.count) orphaned WindowSets...")
            
            for windowSet in orphanedWindowSets {
                // For each window in the set, find its current screen
                for window in windowSet.windows {
                    // Get the window's current screen based on its frame
                    if let currentScreen = window.snapScreen() {
                        // Find or create the screen workspace
                        if let screenIndex = workspace.screens.firstIndex(where: { $0.screen == currentScreen }) {
                            // Create a new WindowSet for this window on its new screen
                            let newSet = WindowSet(
                                layout: windowSet.layout,
                                windows: [window],
                                screenID: currentScreen.screenID()
                            )
                            workspace.screens[screenIndex].windowSets.append(newSet)
                            
                            log("✅ Remapped window '\(window.title() ?? "<untitled>")' to screen \(currentScreen.screenID() ?? "unknown")")
                            
                            // Expand the window if auto-expand is enabled
                            if shouldAutoExpandNewWindows() {
                                newSet.expandWindows(on: currentScreen, bringToFront: false)
                            }
                        }
                    } else {
                        log("⚠️ Could not determine screen for window '\(window.title() ?? "<untitled>")'")
                    }
                }
            }
        }
        
        // Refresh all existing windows to ensure proper positioning
        for screenWS in workspace.screens {
            for windowSet in screenWS.windowSets {
                // Verify the windowSet's screenID matches the current screen
                if windowSet.screenID != screenWS.screen.screenID() {
                    log("🔧 Updating WindowSet screen ID from \(windowSet.screenID ?? "nil") to \(screenWS.screen.screenID() ?? "nil")")
                    windowSet.screenID = screenWS.screen.screenID()
                }
                
                // Re-expand windows to ensure proper positioning
                if shouldAutoExpandNewWindows() {
                    windowSet.expandWindows(on: screenWS.screen, bringToFront: false)
                }
            }
        }
        
        log("✅ Screen remapping complete")
    }
    
    @objc private func applicationDidLaunch(_ notification: Notification) {
        guard let app = notification.userInfo?[NSWorkspace.applicationUserInfoKey] as? NSRunningApplication else {
            return
        }
        
        log("🚀 Application launched: \(app.localizedName ?? "Unknown") (\(app.bundleIdentifier ?? "no bundle"))")
        
        // Set up observer for the new app
        if let bundleID = app.bundleIdentifier, app.isManageable == .manageable {
            setupObserver(for: app)
        }
        
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
        
        // Remove observer for the terminated app
        removeObserver(for: app)
        
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
        
        // Don't reset cycling if we're programmatically focusing via hotkey
        if isProgrammaticFocus {
            return
        }
        
        // Reset cycling if a different app was activated manually (not via our hotkey)
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
                                
                                // Find the window index within the bundle's windows in this WindowSet
                                let bundleWindowsInSet = windowSet.windows.filter { win in
                                    guard let app = NSRunningApplication(processIdentifier: win.pid()) else { return false }
                                    return app.bundleIdentifier == bundleID
                                }
                                
                                if let windowIndex = bundleWindowsInSet.firstIndex(where: { $0.cgID() == axWindow.cgID() }) {
                                    currentWindowIndexInActiveSet = windowIndex
                                    windowIndexWithinSet = windowIndex
                                } else {
                                    currentWindowIndexInActiveSet = 0
                                    windowIndexWithinSet = 0
                                }
                                
                                // Update the focused WindowSet ID
                                currentFocusedWindowSetID = windowSet.id
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
        let defaultLayout = getDefaultLayoutMode()
        let newSet = WindowSet(layout: defaultLayout, windows: [window], screenID: screenWS.screen.screenID())
        screenWS.windowSets.append(newSet)
        
        // Auto-expand the window if the setting is enabled (without bringing to front during initialization)
        if shouldAutoExpandNewWindows() {
            newSet.expandWindows(on: screenWS.screen, bringToFront: false)
        }
    }
    
    /// Returns all WindowSets that contain at least one window belonging to the given bundle ID, sorted consistently.
    private func windowSets(for bundleID: String) -> [WindowSet] {
        var matchingSets: [WindowSet] = []
        var seenWindowIDs: Set<CGWindowID> = []

        for screenWS in workspace.screens {
            for set in screenWS.windowSets {
                // Check if this WindowSet contains any windows from the requested bundle
                let bundleWindows = set.windows.filter { win in
                    guard let app = NSRunningApplication(processIdentifier: win.pid()) else {
                        return false
                    }
                    return app.bundleIdentifier == bundleID
                }

                if !bundleWindows.isEmpty {
                    // Check if this WindowSet contains any new windows we haven't seen
                    let hasNewWindows = bundleWindows.contains { window in
                        let windowID = window.cgID()
                        return !seenWindowIDs.contains(windowID)
                    }
                    
                    if hasNewWindows {
                        matchingSets.append(set)
                        // Track the window IDs we've seen
                        for window in bundleWindows {
                            seenWindowIDs.insert(window.cgID())
                        }
                    }
                }
            }
        }

        
        return matchingSets
    }
    
    // MARK: - Application Window Observers
    
    private var applicationObservers: [pid_t: AXObserver] = [:]
    
    private func setupApplicationObservers() {
        // Set up observers for all currently running applications
        for app in NSWorkspace.shared.runningApplications {
            if let bundleID = app.bundleIdentifier, app.isManageable == .manageable {
                setupObserver(for: app)
            }
        }
    }
    
    private func setupObserver(for app: NSRunningApplication) {
        guard let bundleID = app.bundleIdentifier else { return }
        
        let pid = app.processIdentifier
        
        // Skip if we already have an observer for this app
        guard applicationObservers[pid] == nil else { return }
        
        // Create application element
        let appElement = AXUIElementCreateApplication(pid)
        
        var observer: AXObserver?
        let result = AXObserverCreate(pid, { observer, element, notification, userData in
            guard let userData = userData else { return }
            let manager = Unmanaged<SimpleWindowManager>.fromOpaque(userData).takeUnretainedValue()
            
            let notificationName = notification as String
            if notificationName == kAXCreatedNotification as String {
                DispatchQueue.main.async {
                    manager.handleWindowCreated(element)
                }
            }
        }, &observer)
        
        guard result == .success, let observer = observer else {
            log("❌ Failed to create AX observer for \(app.localizedName ?? bundleID)")
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
            log("✅ Window observer setup successful for \(app.localizedName ?? bundleID)")
        } else {
            log("❌ Failed to add window creation observer for \(app.localizedName ?? bundleID)")
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
            log("🗑️ Removed window observer for \(app.localizedName ?? app.bundleIdentifier ?? "Unknown")")
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
        
        log("🪟 New window created for \(app.localizedName ?? "Unknown") (\(bundleID))")
        
        // Create AXWindow wrapper
        let axWindow = AXWindow(axElement: windowElement)
        
        // Find the appropriate screen for this window
        guard let nsScreen: NSScreen = axWindow.screen() else {
            log("❌ Could not determine screen for new window")
            return
        }
        
        let amScreen = AMScreen(screen: nsScreen)
        
        // Find or create screen workspace
        var screenWS: ScreenWorkspace
        if let existingIndex = workspace.screens.firstIndex(where: { $0.screen == amScreen }) {
            screenWS = workspace.screens[existingIndex]
        } else {
            screenWS = ScreenWorkspace(screen: amScreen, sets: [])
            workspace.screens.append(screenWS)
        }
        
        // Create a new WindowSet for this window
        let defaultLayout = getDefaultLayoutMode()
        let newWindowSet = WindowSet(layout: defaultLayout, windows: [axWindow], screenID: amScreen.screenID())
        
        // Add to appropriate screen workspace
        if let screenIndex = workspace.screens.firstIndex(where: { $0.screen == amScreen }) {
            workspace.screens[screenIndex].windowSets.append(newWindowSet)
        }
        
        // Auto-expand the new window if enabled
        if shouldAutoExpandNewWindows() {
            newWindowSet.expandWindows(on: amScreen, bringToFront: false)
        }
        
        log("✅ Added new window to workspace - now tracking \(workspace.screens.flatMap { $0.windowSets }.count) WindowSets")
    }
    
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
