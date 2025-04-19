//
//  WindowController.swift
//  snapdesk
//
//  Created by Pedro Knup on 18/04/2025.
//

class WindowController {
    private var appWindows: [String: [SIWindow]] = [:] // BundleID → windows
    private var currentWindowPerApp: [String: Int] = [:] // BundleID → index
    // Maps AXUIElement to NSScreen
    private var windowScreenMap: [AXUIElement: NSScreen] = [:]
    
    // Each app gets assigned to a "layout group" by ID
    private var layoutGroups: [String: [String]] = [:]
    // groupID → array of bundle IDs in the layout (order = z-order)
    private(set) var currentlyFocusedWindow: SIWindow?
    var observers: [AXObserver] = []
    
    // Reverse mapping: app bundleID → groupID it's part of
    private var appToGroup: [String: String] = [:]
    
    // Store window positions within layouts
    private var layoutWindowPositions: [String: [String: Int]] = [:] // groupID → [bundleID: position]
    
    // Track full screen state per screen
    private var screenFullScreenState: [NSScreen: Bool] = [:] // screen → isFullScreen
    
    init() {
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
            self.scanAndTrackWindows()
        }
    }
    
    func screenForWindow(_ window: SIWindow) -> NSScreen? {
        let element = window.axElement().takeUnretainedValue()
        return windowScreenMap[element]
    }
    
    func prettyPrintWindows(_ appWindows: [String: [SIWindow]]) -> String {
        var output = "\n🪟 Window Summary:\n"
        
        
        for (bundleID, windows) in appWindows {
            output += "\n📦 App: \(bundleID)\n"
            
            for (index, window) in windows.enumerated() {
                let title = window.title() ?? "<No Title>"
                let pid = window.processIdentifier()
                let screen = screenForWindow(window)?.frame ?? .zero
                output += "   \(index + 1). \"\(title)\" (pid: \(pid)) on screen x:\(Int(screen.origin.x))\n"
            }
        }
        
        return output
    }
    
    
    func scanAndTrackWindows() {
        guard let apps = SIApplication.runningApplications() as? [SIApplication] else { return }
        
        var updated: [String: [SIWindow]] = [:]
        
        for app in SIApplication.runningApplications() as? [SIApplication] ?? [] {
            let element = app.axElementRef
            var value: CFTypeRef?
            let result = AXUIElementCopyAttributeValue(element, kAXWindowsAttribute as CFString, &value)
            
            log("AX result for \(app.title() ?? "Unknown"): \(result.rawValue)")
        }
        
        for app in apps {
            guard let bundleID = app.bundleIdentifier else { continue }
            let windows = app.windows()
                .filter {
                    $0.isStandard() &&
                    $0.frame().width > 0 &&
                    $0.frame().height > 0
                    }
                    
                    if !windows.isEmpty {
                        updated[bundleID] = windows
                        
                        
                        for window in windows {
                            let windowFrame = window.frame()
                            if let screen = NSScreen.screens.first(where: { $0.frame.intersects(windowFrame) }) {
                                let element = window.axElement().takeUnretainedValue()
                                windowScreenMap[element] = screen
                            }
                        }
                    }
                }
            
            appWindows = updated
            log(prettyPrintWindows(updated))
        }
    
        
        
        func toggleFullScreen() {
            guard let currentWindow = currentlyFocusedWindow,
                  let screen = screenForWindow(currentWindow) else {
                log("❌ No focused window or screen to toggle full screen")
                return
            }
            
            // Toggle full screen state for this screen
            let isCurrentlyFullScreen = screenFullScreenState[screen] ?? false
            screenFullScreenState[screen] = !isCurrentlyFullScreen
            log("🔄 Toggling full screen for screen: \(screen.frame), new state: \(!isCurrentlyFullScreen)")
            
            if !isCurrentlyFullScreen {
                maximizeToFullScreen(window: currentWindow, screen: screen)
            } else {
                // If window was in a layout, restore the layout
                if let bundleID = findBundleID(for: currentWindow),
                   let groupID = appToGroup[bundleID] {
                    applyLayout(groupID: groupID, screen: screen)
                }
            }
        }
        
        private func centerCursorInWindow(_ window: SIWindow) {
            let frame = window.frame()
            let centerX = frame.midX
            let centerY = frame.midY
            
            // Convert to screen coordinates
            let mouseLocation = CGPoint(x: centerX, y: centerY)
            CGEvent(mouseEventSource: nil, mouseType: .mouseMoved, mouseCursorPosition: mouseLocation, mouseButton: .left)?.post(tap: .cghidEventTap)
        }

        private func maximizeToFullScreen(window: SIWindow, screen: NSScreen) {
            log("🖥 Setting full screen for: \(window.title() ?? "<no title>") on screen: \(screen.frame)")
            let screenFrame = screen.visibleFrame
            let frame = CGRect(x: screenFrame.origin.x,
                              y: screenFrame.origin.y,
                              width: screenFrame.width,
                              height: screenFrame.height)
            try? window.setFrame(frame)
            window.focus()
            centerCursorInWindow(window)
            currentlyFocusedWindow = window
        }
        
        private func findBundleID(for window: SIWindow) -> String? {
            for (bundleID, windows) in appWindows {
                if windows.contains(where: { $0 == window }) {
                    return bundleID
                }
            }
            return nil
        }
        
        func focusApp(_ bundleID: String) {
            log("🎯 Attempting to focus app: \(bundleID)")
            log("Current windows for app: \(appWindows[bundleID] ?? [])")
            
            if let groupID = appToGroup[bundleID] {
                log("🔄 Found existing layout group: \(groupID)")
                log("Layout group details:")
                log("  - Windows in group: \(layoutGroups[groupID] ?? [])")
                log("  - Window positions: \(layoutWindowPositions[groupID] ?? [:])")
                
                // Get all windows for this app
                guard let windows = appWindows[bundleID], !windows.isEmpty else {
                    log("⚠️ No windows found for app in layout")
                    return
                }
                
                // Get current index and cycle to next window
                let currentIndex = currentWindowPerApp[bundleID] ?? 0
                let nextIndex = (currentIndex + 1) % windows.count
                currentWindowPerApp[bundleID] = nextIndex
                let window = windows[nextIndex]
                
                log("📋 Cycling to window index: \(nextIndex) of \(windows.count)")
                
                if let screen = screenForWindow(window) {
                    log("✅ Found screen for window: \(screen.frame)")
                    
                    // Hide all windows that aren't in this layout group
                    let layoutPositions = layoutWindowPositions[groupID] ?? [:]
                    for (otherBundleID, otherWindows) in appWindows {
                        if !layoutPositions.keys.contains(otherBundleID) {
                            for otherWindow in otherWindows {
                                log("🔒 Hiding window not in layout: \(otherWindow.title() ?? "<no title>")")
                                let axElement = otherWindow.axElement().takeUnretainedValue()
                                let hidden: CFTypeRef = kCFBooleanTrue
                                AXUIElementSetAttributeValue(axElement, kAXHiddenAttribute as CFString, hidden)
                            }
                        }
                    }
                    
                    // Show all windows in the layout
                    for (layoutBundleID, _) in layoutPositions {
                        if let windows = appWindows[layoutBundleID], let window = windows.first {
                            log("👁 Showing window in layout: \(window.title() ?? "<no title>")")
                            let axElement = window.axElement().takeUnretainedValue()
                            let visible: CFTypeRef = kCFBooleanFalse
                            AXUIElementSetAttributeValue(axElement, kAXHiddenAttribute as CFString, visible)
                        }
                    }
                    
                    if screenFullScreenState[screen] ?? false {
                        maximizeToFullScreen(window: window, screen: screen)
                    } else {
                        applyLayout(groupID: groupID, screen: screen, targetWindow: window)
                    }
                } else {
                    log("⚠️ Could not find screen for window, using default screen")
                    applyLayout(groupID: groupID)
                }
                return
            }
            
            log("ℹ️ No existing layout found for app")
            
            guard let windows = appWindows[bundleID], !windows.isEmpty else {
                log("🚀 No windows found, launching app")
                launchAppIfNeeded(bundleID)
                return
            }

            let currentIndex = currentWindowPerApp[bundleID] ?? 0
            let window = windows[currentIndex]
            log("📋 Cycling to window index: \(currentIndex) of \(windows.count)")

            // Cycle to next on repeated key press
            currentWindowPerApp[bundleID] = (currentIndex + 1) % windows.count

            // Hide all others *before* we focus/maximize the target window
            hideAllWindows(except: window)

            // Focus & maximize
            window.focus()
            centerCursorInWindow(window)
            if let screen = screenForWindow(window),
               screenFullScreenState[screen] ?? false {
                maximizeToFullScreen(window: window, screen: screen)
            } else {
                maximize(window: window)
            }
            
            // Update and log the focused window
            currentlyFocusedWindow = window
            log("✅ Focused window: \(window.title() ?? "<No Title>") for \(bundleID)")
        }
        
        
        func hideAllWindows(except visibleWindow: SIWindow?) {
            log("🔒 Hiding all windows except: \(visibleWindow?.title() ?? "<none>")")
            
            for (_, windows) in appWindows {
                for window in windows {
                    guard window != visibleWindow else { continue }
                    
                    // Hide using AXHidden attribute
                    let axElement = window.axElement().takeUnretainedValue()
                    let hidden: CFTypeRef = kCFBooleanTrue
                    let result = AXUIElementSetAttributeValue(axElement, kAXHiddenAttribute as CFString, hidden)
                    
                    if result != .success {
                        log("⚠️ Failed to hide window: \(window.title() ?? "<no title>")")
                    }
                }
            }
        }
        
        
        func launchAppIfNeeded(_ bundleID: String) {
            let ws = NSWorkspace.shared
            log("🚀 Launching app \(bundleID)")
            
            guard !ws.runningApplications.contains(where: { $0.bundleIdentifier == bundleID }) else {
                log("✅ App already running: \(bundleID)")
                return
            }
            
            guard let url = NSWorkspace.shared.urlForApplication(withBundleIdentifier: bundleID) else {
                log("❌ Could not find app URL for bundle ID: \(bundleID)")
                return
            }
            
            let config = NSWorkspace.OpenConfiguration()
            config.activates = true
            
            ws.openApplication(at: url, configuration: config) { app, error in
                if let error = error {
                    log("❌ Failed to launch app: \(error)")
                } else {
                    log("✅ App launched: \(bundleID)")
                }
            }
        }
        
        private func maximize(window: SIWindow) {
            guard let screen = NSScreen.screens.first(where: {
                $0.frame.intersects(window.frame())
            }) else { return }
            
            let screenFrame = screen.visibleFrame
            
            let position = CGPoint(x: screenFrame.origin.x, y: screenFrame.origin.y)
            let size = CGSize(width: screenFrame.width, height: screenFrame.height)
            
            window.setPosition(position)
            window.setSize(size)
        }
        
        func getCurrentFocusedWindow() -> SIWindow? {
            for windows in appWindows.values {
                for window in windows {
                    if window.isFocused() {
                        // Update the currently focused window when found
                        if currentlyFocusedWindow != window {
                            currentlyFocusedWindow = window
                            log("🔄 Window focus changed to: \(window.title() ?? "<No Title>")")
                        }
                        return window
                    }
                }
            }
            log("❌ No focused window found")
            return nil
        }
        
        
        func addWindowToLayout(_ newAppBundleID: String) {
            log("🔍 Starting addWindowToLayout for bundleID: \(newAppBundleID)")
            
            guard let currentWindow = currentlyFocusedWindow else {
                log("❌ No focused window found")
                return
            }
            log("✅ Found current window: \(currentWindow.title() ?? "<no title>")")

            // Get the bundle ID of the app owning this window
            var currentBundleID: String?
            for (bundleID, windows) in appWindows {
                if windows.contains(where: { $0 == currentWindow }) {
                    currentBundleID = bundleID
                    break
                }
            }

            guard let currentBundleID = currentBundleID else {
                log("❌ Could not determine bundle ID for current window")
                return
            }
            log("✅ Found current bundleID: \(currentBundleID)")
            
            // Get the screen where the current window is
            guard let currentScreen = screenForWindow(currentWindow) else {
                log("❌ Could not determine screen for current window")
                return
            }
            log("✅ Current window is on screen: \(currentScreen.frame)")
            
            // Determine group ID - either use existing or create new
            let groupID = appToGroup[currentBundleID] ?? UUID().uuidString
            log("📦 Using groupID: \(groupID) (existing: \(appToGroup[currentBundleID] != nil))")
            
            // If this is a new layout (single window), initialize positions
            if layoutWindowPositions[groupID] == nil {
                layoutWindowPositions[groupID] = [currentBundleID: 0]
                log("🆕 Initialized new layout positions for group \(groupID)")
            }
            
            // Add new window to layout if not already present
            if !layoutGroups[groupID, default: []].contains(newAppBundleID) {
                layoutGroups[groupID, default: []].append(newAppBundleID)
                // Assign position to new window
                let newPosition = layoutGroups[groupID]?.count ?? 1 - 1
                layoutWindowPositions[groupID]?[newAppBundleID] = newPosition
                log("➕ Added new window to layout - Position: \(newPosition), Total windows: \(layoutGroups[groupID]?.count ?? 0)")
            } else {
                log("ℹ️ Window already in layout")
            }
            
            // Update app to group mapping
            appToGroup[currentBundleID] = groupID
            appToGroup[newAppBundleID] = groupID
            log("📝 Updated app to group mapping - Current: \(currentBundleID), New: \(newAppBundleID) → \(groupID)")

            log("📐 Current layout state:")
            log("   - Group ID: \(groupID)")
            log("   - Windows: \(layoutGroups[groupID] ?? [])")
            log("   - Positions: \(layoutWindowPositions[groupID] ?? [:])")
            
            // Apply layout to all windows in the group
            applyLayout(groupID: groupID, screen: currentScreen)
        }
        
        func applyLayout(groupID: String, screen: NSScreen? = nil, targetWindow: SIWindow? = nil) {
            guard let bundleIDs = layoutGroups[groupID], !bundleIDs.isEmpty else { return }
            log("📐 Applying layout for group \(groupID)")
            log("   - Windows: \(bundleIDs)")
            log("   - Positions: \(layoutWindowPositions[groupID] ?? [:])")
            
            // Use provided screen or find the screen of the first window in the layout
            let targetScreen: NSScreen
            if let screen = screen {
                targetScreen = screen
                log("🎯 Using provided screen: \(screen.frame)")
            } else if let firstBundleID = bundleIDs.first,
                      let firstWindow = appWindows[firstBundleID]?.first,
                      let firstScreen = screenForWindow(firstWindow) {
                targetScreen = firstScreen
                log("🎯 Using screen of first window: \(firstScreen.frame)")
            } else {
                targetScreen = NSScreen.main ?? NSScreen.screens.first!
                log("⚠️ Falling back to main screen: \(targetScreen.frame)")
            }
            
            let screenFrame = targetScreen.visibleFrame
            let totalWindows = CGFloat(layoutWindowPositions[groupID]?.count ?? 0)
            let widthPerApp = screenFrame.width / totalWindows
            log("📏 Screen dimensions - Width: \(screenFrame.width), Total windows in layout: \(totalWindows), Width per window: \(widthPerApp)")

            // First, resize all windows in the layout
            for (bundleID, position) in layoutWindowPositions[groupID] ?? [:] {
                guard let windows = appWindows[bundleID], !windows.isEmpty else { continue }
                let window = windows.first!
                
                let frame = CGRect(x: screenFrame.origin.x + (widthPerApp * CGFloat(position)),
                                 y: screenFrame.origin.y,
                                 width: widthPerApp,
                                 height: screenFrame.height)
                
                log("🪟 Positioning window: \(window.title() ?? "<no title>")")
                log("   - Bundle ID: \(bundleID)")
                log("   - Position: \(position)")
                log("   - Frame: \(frame)")

                try? window.setFrame(frame)
            }
            
            // Bring all windows to front in order of position (0 first, then 1, etc.)
            log("🔄 Bringing windows to front")
            let sortedPositions = layoutWindowPositions[groupID]?.sorted(by: { $0.value < $1.value }) ?? []
            for (bundleID, _) in sortedPositions {
                if let windows = appWindows[bundleID], let window = windows.first {
                    log("   - Bringing to front: \(window.title() ?? "<no title>")")
                    window.focus()
                }
            }
            
            // Focus the target window if provided, otherwise use the first window
            if let targetWindow = targetWindow {
                log("✨ Focusing provided target window: \(targetWindow.title() ?? "<no title>")")
                targetWindow.focus()
                centerCursorInWindow(targetWindow)
                currentlyFocusedWindow = targetWindow
            } else if let targetBundleID = bundleIDs.first,
                      let targetWindow = appWindows[targetBundleID]?.first {
                log("✨ Focusing first window in layout: \(targetWindow.title() ?? "<no title>")")
                targetWindow.focus()
                centerCursorInWindow(targetWindow)
                currentlyFocusedWindow = targetWindow
            }
        }
        
        func removeCurrentWindowFromLayout() {
            guard let currentWindow = currentlyFocusedWindow else {
                log("❌ No focused window to remove from layout")
                return
            }
            
            // Find the bundle ID and group ID for the current window
            var currentBundleID: String?
            var currentGroupID: String?
            
            for (bundleID, windows) in appWindows {
                if windows.contains(where: { $0 == currentWindow }) {
                    currentBundleID = bundleID
                    currentGroupID = appToGroup[bundleID]
                    break
                }
            }
            
            guard let bundleID = currentBundleID,
                  let groupID = currentGroupID else {
                log("ℹ️ Window is not part of any layout")
                return
            }
            
            log("🔄 Removing window from layout - Bundle: \(bundleID), Group: \(groupID)")
            
            // Remove the window from the layout groups
            if var groupWindows = layoutGroups[groupID] {
                groupWindows.removeAll { $0 == bundleID }
                layoutGroups[groupID] = groupWindows
                
                // If this was the last window in the layout, clean up the layout
                if groupWindows.isEmpty {
                    log("🗑 Removing empty layout group: \(groupID)")
                    layoutGroups.removeValue(forKey: groupID)
                    layoutWindowPositions.removeValue(forKey: groupID)
                    appToGroup.removeValue(forKey: bundleID)
                    return
                }
                
                // Remove the window's position from the layout
                layoutWindowPositions[groupID]?.removeValue(forKey: bundleID)
                
                // Reassign positions to remaining windows
                var newPositions: [String: Int] = [:]
                for (index, remainingBundleID) in groupWindows.enumerated() {
                    newPositions[remainingBundleID] = index
                }
                layoutWindowPositions[groupID] = newPositions
                
                // Remove the window from app-to-group mapping
                appToGroup.removeValue(forKey: bundleID)
                
                // Get the screen of the current window for reapplying the layout
                if let screen = screenForWindow(currentWindow) {
                    // Find the next window to focus (first window in the remaining layout)
                    if let nextBundleID = groupWindows.first,
                       let nextWindow = appWindows[nextBundleID]?.first {
                        log("✨ Focusing next window in layout: \(nextWindow.title() ?? "<no title>")")
                        applyLayout(groupID: groupID, screen: screen, targetWindow: nextWindow)
                    }
                }
            }
        }
    }


