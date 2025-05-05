//
//  WindowController.swift
//  snapdesk
//
//  Created by Pedro Knup on 18/04/2025.
//

class WindowController: ObservableObject {
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
    
    // Add new property to store window identifiers
    private var windowIdentifiers: [SIWindow: String] = [:] // Window → unique ID
    
    // Add new property to store window focus history
    private var windowFocusHistory: [String] = [] // Array of window IDs in focus order
    private let maxHistorySize = 10 // Maximum number of windows to keep in history
    
    // Add new property to store screen information
    private struct ScreenInfo {
        let screen: NSScreen
        let frame: CGRect
        let visibleFrame: CGRect
        let scaleFactor: CGFloat
        let displayID: CGDirectDisplayID
    }
    
    private var screenInfoMap: [NSScreen: ScreenInfo] = [:]
    
    private func updateScreenMap() {
        screenInfoMap.removeAll()
        
        for screen in NSScreen.screens {
            let frame = screen.frame
            let visibleFrame = screen.visibleFrame
            let scaleFactor = screen.backingScaleFactor
            let displayID = screen.deviceDescription[NSDeviceDescriptionKey("NSScreenNumber")] as? CGDirectDisplayID ?? 0
            
            let info = ScreenInfo(
                screen: screen,
                frame: frame,
                visibleFrame: visibleFrame,
                scaleFactor: scaleFactor,
                displayID: displayID
            )
            
            screenInfoMap[screen] = info
            log("📺 Screen mapped - ID: \(displayID), Frame: \(frame), Visible: \(visibleFrame), Scale: \(scaleFactor)")
        }
    }
    
    private func findBestScreenForWindow(_ window: SIWindow) -> NSScreen? {
        let windowFrame = window.frame()
        
        // First try to find a screen that contains the window's center point
        let windowCenter = CGPoint(
            x: windowFrame.midX,
            y: windowFrame.midY
        )
        
        for (screen, info) in screenInfoMap {
            if info.frame.contains(windowCenter) {
                //log("🎯 Found screen for window center: \(window.title() ?? "<no title>") → Screen \(info.displayID)")
                return screen
            }
        }
        
        // If no screen contains the center, find the screen with the most overlap
        var bestScreen: NSScreen?
        var maxOverlap: CGFloat = 0
        
        for (screen, info) in screenInfoMap {
            let intersection = windowFrame.intersection(info.frame)
            let overlap = intersection.width * intersection.height
            
            if overlap > maxOverlap {
                maxOverlap = overlap
                bestScreen = screen
            }
        }
        
        if let screen = bestScreen {
            log("📐 Found best overlapping screen for window: \(window.title() ?? "<no title>") → Screen \(screenInfoMap[screen]?.displayID ?? 0)")
        }
        
        return bestScreen
    }
    
    func screenForWindow(_ window: SIWindow) -> NSScreen? {
        // Update screen map if empty
        if screenInfoMap.isEmpty {
            updateScreenMap()
        }
        
        let element = window.axElement().takeUnretainedValue()
        
        // If we already have a mapping, use it
        if let existingScreen = windowScreenMap[element] {
            return existingScreen
        }
        
        // Find the best screen for this window
        if let screen = findBestScreenForWindow(window) {
            windowScreenMap[element] = screen
            return screen
        }
        
        // Fallback to main screen if no better option found
        let mainScreen = NSScreen.main ?? NSScreen.screens.first!
        windowScreenMap[element] = mainScreen
        return mainScreen
    }
    
    init() {
        // Initialize screen map
        updateScreenMap()
        
        // Set up screen change notification observer
        NotificationCenter.default.addObserver(
            self,
            selector: #selector(screenParametersDidChange),
            name: NSApplication.didChangeScreenParametersNotification,
            object: nil
        )
        
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
            self.scanAndTrackWindows()
        }
    }
    
    @objc private func screenParametersDidChange() {
        log("🔄 Screen parameters changed, updating screen map")
        updateScreenMap()
        
        // Reassign windows to screens
        for (element, _) in windowScreenMap {
            if let window = findWindowByElement(element) {
                if let screen = findBestScreenForWindow(window) {
                    windowScreenMap[element] = screen
                }
            }
        }
    }
    
    private func findWindowByElement(_ element: AXUIElement) -> SIWindow? {
        for (_, windows) in appWindows {
            for window in windows {
                if window.axElement().takeUnretainedValue() == element {
                    return window
                }
            }
        }
        return nil
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
            
            // Get all windows for this app
            guard let windows = appWindows[bundleID], !windows.isEmpty else {
                log("⚠️ No windows found for app in layout")
                return
            }
            
            // Get the window ID for the first window
            let windowId = getWindowIdentifier(windows[0])
            
            // Check if this window is part of a layout group
            if let groupID = appToGroup[windowId] {
                log("🔄 Found existing layout group: \(groupID)")
                log("Layout group details:")
                log("  - Windows in group: \(layoutGroups[groupID] ?? [])")
                log("  - Window positions: \(layoutWindowPositions[groupID] ?? [:])")
                
                // Get current index and cycle to next window only if this is the same app as last focused
                let currentIndex = currentWindowPerApp[bundleID] ?? 0
                let nextIndex: Int
                
                if let lastFocusedWindow = currentlyFocusedWindow,
                   let lastBundleID = findBundleID(for: lastFocusedWindow),
                   lastBundleID == bundleID {
                    // Same app - cycle to next window
                    nextIndex = (currentIndex + 1) % windows.count
                    currentWindowPerApp[bundleID] = nextIndex
                } else {
                    // Different app - focus first window
                    nextIndex = 0
                    currentWindowPerApp[bundleID] = 0
                }
                
                let targetWindow = windows[nextIndex]
                
                if let screen = screenForWindow(targetWindow) {
                    log("✅ Found screen for window: \(screen.frame)")
                    
                    // Show all windows in the layout
                    for (layoutBundleID, _) in layoutWindowPositions[groupID] ?? [:] {
                        if let windows = appWindows[layoutBundleID], let window = windows.first {
                            log("👁 Showing window in layout: \(window.title() ?? "<no title>")")
                            let axElement = window.axElement().takeUnretainedValue()
                            let visible: CFTypeRef = kCFBooleanFalse
                            AXUIElementSetAttributeValue(axElement, kAXHiddenAttribute as CFString, visible)
                        }
                    }
                    
                    // Only maximize to full screen if the screen is in full screen state
                    if screenFullScreenState[screen] ?? false {
                        maximizeToFullScreen(window: targetWindow, screen: screen)
                    } else {
                        // When cycling windows, just focus the target window without moving it
                        if let lastFocusedWindow = currentlyFocusedWindow,
                           let lastBundleID = findBundleID(for: lastFocusedWindow),
                           lastBundleID == bundleID {
                            // Just focus the window without moving it
                            targetWindow.focus()
                            centerCursorInWindow(targetWindow)
                            currentlyFocusedWindow = targetWindow
                            addWindowToFocusHistory(targetWindow)
                        } else {
                            // Different app - apply layout and focus
                            applyLayout(groupID: groupID, screen: screen, targetWindow: targetWindow)
                            targetWindow.focus()
                            centerCursorInWindow(targetWindow)
                            currentlyFocusedWindow = targetWindow
                            addWindowToFocusHistory(targetWindow)
                        }
                    }
                } else {
                    log("⚠️ Could not find screen for window, using default screen")
                    applyLayout(groupID: groupID)
                }
                return
            }
            
            log("ℹ️ No existing layout found for app")
            
            // Get current index and cycle to next window only if this is the same app as last focused
            let currentIndex = currentWindowPerApp[bundleID] ?? 0
            let nextIndex: Int
            
            if let lastFocusedWindow = currentlyFocusedWindow,
               let lastBundleID = findBundleID(for: lastFocusedWindow),
               lastBundleID == bundleID {
                // Same app - cycle to next window
                nextIndex = (currentIndex + 1) % windows.count
                currentWindowPerApp[bundleID] = nextIndex
            } else {
                // Different app - focus first window
                nextIndex = 0
                currentWindowPerApp[bundleID] = 0
            }
            
            let window = windows[nextIndex]
            
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
            addWindowToFocusHistory(window)
            log("✅ Focused window: \(window.title() ?? "<No Title>") for \(bundleID)")
        }
        
        
        func hideAllWindows(except visibleWindow: SIWindow?) {
//            log("🔒 Hiding all windows except: \(visibleWindow?.title() ?? "<none>")")
//            
//            for (_, windows) in appWindows {
//                for window in windows {
//                    guard window != visibleWindow else { continue }
//                    
//                    // Hide using AXHidden attribute
//                    let axElement = window.axElement().takeUnretainedValue()
//                    let hidden: CFTypeRef = kCFBooleanTrue
//                    let result = AXUIElementSetAttributeValue(axElement, kAXHiddenAttribute as CFString, hidden)
//                    
//                    if result != .success {
//                        log("⚠️ Failed to hide window: \(window.title() ?? "<no title>")")
//                    }
//                }
//            }
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
        
        private func addWindowToFocusHistory(_ window: SIWindow) {
            let windowId = getWindowIdentifier(window)
            
            // Remove window from history if it exists (to avoid duplicates)
            windowFocusHistory.removeAll { $0 == windowId }
            
            // Add window to the beginning of history
            windowFocusHistory.insert(windowId, at: 0)
            
            // Keep history size limited
            if windowFocusHistory.count > maxHistorySize {
                windowFocusHistory.removeLast()
            }
            
            log("📜 Window focus history updated:")
            for (index, id) in windowFocusHistory.enumerated() {
                if let window = findWindowByIdentifier(id) {
                    log("   \(index + 1). \(window.title() ?? "<No Title>") \(windowId)")
                }
            }
        }
        
        func getCurrentFocusedWindow() -> SIWindow? {
            for windows in appWindows.values {
                for window in windows {
                    if window.isFocused() {
                        // Update the currently focused window when found
                        if currentlyFocusedWindow != window {
                            currentlyFocusedWindow = window
                            addWindowToFocusHistory(window)
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
            
            // Get unique identifiers for both windows
            let currentWindowId = getWindowIdentifier(currentWindow)
            guard let newWindow = appWindows[newAppBundleID]?.first else {
                log("❌ Could not find window for new bundle ID")
                return
            }
            let newWindowId = getWindowIdentifier(newWindow)
            
            // Determine group ID - either use existing or create new
            let groupID = appToGroup[currentWindowId] ?? UUID().uuidString
            log("📦 Using groupID: \(groupID) (existing: \(appToGroup[currentWindowId] != nil))")
            
            // If this is a new layout (single window), initialize positions
            if layoutWindowPositions[groupID] == nil {
                layoutWindowPositions[groupID] = [currentWindowId: 0]
                layoutGroups[groupID] = [currentWindowId]
                log("🆕 Initialized new layout positions for group \(groupID)")
            }
            
            // Add new window to layout if not already present
            if !layoutGroups[groupID, default: []].contains(newWindowId) {
                // Add the new window ID to the group
                layoutGroups[groupID, default: []].append(newWindowId)
                
                // Get the next available position (should be 1 for the second window)
                let nextPosition = (layoutGroups[groupID]?.count ?? 1) - 1
                layoutWindowPositions[groupID]?[newWindowId] = nextPosition
                
                log("➕ Added new window to layout - Position: \(nextPosition), Total windows: \(layoutGroups[groupID]?.count ?? 0)")
            } else {
                log("ℹ️ Window already in layout")
            }
            
            // Update app to group mapping
            appToGroup[currentWindowId] = groupID
            appToGroup[newWindowId] = groupID
            log("📝 Updated app to group mapping - Current: \(currentWindowId), New: \(newWindowId) → \(groupID)")

            log("📐 Current layout state:")
            log("   - Group ID: \(groupID)")
            log("   - Windows: \(layoutGroups[groupID] ?? [])")
            log("   - Positions: \(layoutWindowPositions[groupID] ?? [:])")
            
            // Apply layout to all windows in the group
            applyLayout(groupID: groupID, screen: currentScreen)
        }
        
        func applyLayout(groupID: String, screen: NSScreen? = nil, targetWindow: SIWindow? = nil) {
            guard let windowIds = layoutGroups[groupID], !windowIds.isEmpty else { return }
            log("Layout groups: \(layoutGroups)")
            log("📐 Applying layout for group \(groupID)")
            log("   - Windows: \(windowIds)")
            log("   - Positions: \(layoutWindowPositions[groupID] ?? [:])")
            
            // Use provided screen or find the screen of the first window in the layout
            let targetScreen: NSScreen
            if let screen = screen {
                targetScreen = screen
                log("🎯 Using provided screen: \(screen.frame)")
            } else if let firstWindowId = windowIds.first,
                      let firstWindow = findWindowByIdentifier(firstWindowId),
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

            // First, hide all windows that aren't in this layout
            for (_, windows) in appWindows {
                for window in windows {
                    let windowId = getWindowIdentifier(window)
                    if !windowIds.contains(windowId) {
                        let axElement = window.axElement().takeUnretainedValue()
                        let hidden: CFTypeRef = kCFBooleanTrue
                        AXUIElementSetAttributeValue(axElement, kAXHiddenAttribute as CFString, hidden)
                    }
                }
            }

            // Then, show and position all windows in the layout
            let sortedPositions = layoutWindowPositions[groupID]?.sorted(by: { $0.value < $1.value }) ?? []
            for (windowId, position) in sortedPositions {
                guard let window = findWindowByIdentifier(windowId) else { continue }
                
                // Show the window
                let axElement = window.axElement().takeUnretainedValue()
                let visible: CFTypeRef = kCFBooleanFalse
                AXUIElementSetAttributeValue(axElement, kAXHiddenAttribute as CFString, visible)
                
                // Calculate position based on the window's index in the layout
                let xPosition = screenFrame.origin.x + (widthPerApp * CGFloat(position))
                
                let frame = CGRect(
                    x: xPosition,
                    y: screenFrame.origin.y,
                    width: widthPerApp,
                    height: screenFrame.height
                )
                
                log("🪟 Positioning window: \(window.title() ?? "<no title>")")
                log("   - Window ID: \(windowId)")
                log("   - Position: \(position)")
                log("   - X Position: \(xPosition)")
                log("   - Frame: \(frame)")
                log("   - Target Screen: \(targetScreen.frame)")

                // Update the window's screen mapping to the target screen
                windowScreenMap[axElement] = targetScreen

                // Set the frame and bring to front
                try? window.setFrame(frame)
                window.focus()
            }
            
            // Focus the target window if provided, otherwise use the first window
            if let targetWindow = targetWindow {
                log("✨ Focusing provided target window: \(targetWindow.title() ?? "<no title>")")
                targetWindow.focus()
                centerCursorInWindow(targetWindow)
                currentlyFocusedWindow = targetWindow
            } else if let firstWindowId = windowIds.first,
                      let firstWindow = findWindowByIdentifier(firstWindowId) {
                log("✨ Focusing first window in layout: \(firstWindow.title() ?? "<no title>")")
                firstWindow.focus()
                centerCursorInWindow(firstWindow)
                currentlyFocusedWindow = firstWindow
            }
        }
        
        private func findWindowByIdentifier(_ identifier: String) -> SIWindow? {
            for (window, id) in windowIdentifiers {
                if id == identifier {
                    return window
                }
            }
            return nil
        }
        
        private func getWindowIdentifier(_ window: SIWindow) -> String {
            if let existingId = windowIdentifiers[window] {
                return existingId
            }
            
            // Create a unique identifier using bundle ID and window properties
            let bundleID = findBundleID(for: window) ?? "unknown"
            let title = window.title() ?? "untitled"
            let pid = window.processIdentifier()
            let frame = window.frame()
            
            // Create a unique string combining window properties
            let uniqueId = "\(bundleID)_\(title)_\(pid)_\(frame.origin.x)_\(frame.origin.y)"
            windowIdentifiers[window] = uniqueId
            return uniqueId
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
        
        // Add new method to get focus history
        func getWindowFocusHistory() -> [String] {
            return windowFocusHistory
        }
        
        // Screen focus methods
        func focusScreen(_ screenNumber: Int) {
            guard let screen = NSScreen.screens[safe: screenNumber - 1] else {
                log("❌ Invalid screen number: \(screenNumber)")
                return
            }
            
            // Find the first window on this screen
            for (_, windows) in appWindows {
                for window in windows {
                    if screenForWindow(window) == screen {
                        window.focus()
                        centerCursorInWindow(window)
                        currentlyFocusedWindow = window
                        return
                    }
                }
            }
            
            log("ℹ️ No windows found on screen \(screenNumber)")
        }
        
        func throwToScreen(_ screenNumber: Int) {
            guard let currentWindow = currentlyFocusedWindow,
                  let targetScreen = NSScreen.screens[safe: screenNumber - 1] else {
                log("❌ No focused window or invalid screen number: \(screenNumber)")
                return
            }
            
            // Move the window to the target screen
            currentWindow.move(to: targetScreen)
            
            // Update the window's screen mapping
            let element = currentWindow.axElement().takeUnretainedValue()
            windowScreenMap[element] = targetScreen
            
            // Focus the window
            currentWindow.focus()
            centerCursorInWindow(currentWindow)
        }
        
        func throwToCurrentLayout() {
            guard let currentWindow = currentlyFocusedWindow,
                  let screen = screenForWindow(currentWindow) else {
                log("❌ No focused window or screen")
                return
            }
            
            // Get the bundle ID of the current window
            guard let bundleID = findBundleID(for: currentWindow) else {
                log("❌ Could not determine bundle ID for current window")
                return
            }
            
            // Add the window to the current layout
            addWindowToLayout(bundleID)
        }
        
        func increaseMainPanelCount() {
            guard let currentWindow = currentlyFocusedWindow,
                  let screen = screenForWindow(currentWindow),
                  let bundleID = findBundleID(for: currentWindow),
                  let groupID = appToGroup[bundleID] else {
                log("❌ No focused window or layout")
                return
            }
            
            // Get current positions
            var positions = layoutWindowPositions[groupID] ?? [:]
            let maxPosition = positions.values.max() ?? 0
            
            // Add a new position
            positions[bundleID] = maxPosition + 1
            layoutWindowPositions[groupID] = positions
            
            // Reapply the layout
            applyLayout(groupID: groupID, screen: screen, targetWindow: currentWindow)
        }
        
        func decreaseMainPanelCount() {
            guard let currentWindow = currentlyFocusedWindow,
                  let screen = screenForWindow(currentWindow),
                  let bundleID = findBundleID(for: currentWindow),
                  let groupID = appToGroup[bundleID] else {
                log("❌ No focused window or layout")
                return
            }
            
            // Get current positions
            var positions = layoutWindowPositions[groupID] ?? [:]
            let currentPosition = positions[bundleID] ?? 0
            
            // Only decrease if we're not the last window
            if currentPosition > 0 {
                positions[bundleID] = currentPosition - 1
                layoutWindowPositions[groupID] = positions
                
                // Reapply the layout
                applyLayout(groupID: groupID, screen: screen, targetWindow: currentWindow)
            }
        }
        
        func cycleWindowsClockwise() {
            guard let currentWindow = currentlyFocusedWindow,
                  let screen = screenForWindow(currentWindow),
                  let bundleID = findBundleID(for: currentWindow),
                  let groupID = appToGroup[bundleID] else {
                log("❌ No focused window or layout")
                return
            }
            
            // Get all windows in the layout
            guard let groupWindows = layoutGroups[groupID],
                  let positions = layoutWindowPositions[groupID] else {
                return
            }
            
            // Sort windows by position
            let sortedWindows = groupWindows.sorted { positions[$0] ?? 0 < positions[$1] ?? 0 }
            
            // Find current window's index
            guard let currentIndex = sortedWindows.firstIndex(of: bundleID) else { return }
            
            // Calculate next index (wrap around)
            let nextIndex = (currentIndex + 1) % sortedWindows.count
            let nextBundleID = sortedWindows[nextIndex]
            
            // Focus the next window
            if let nextWindow = appWindows[nextBundleID]?.first {
                nextWindow.focus()
                centerCursorInWindow(nextWindow)
                currentlyFocusedWindow = nextWindow
            }
        }
        
        func cycleWindowsCounterclockwise() {
            guard let currentWindow = currentlyFocusedWindow,
                  let screen = screenForWindow(currentWindow),
                  let bundleID = findBundleID(for: currentWindow),
                  let groupID = appToGroup[bundleID] else {
                log("❌ No focused window or layout")
                return
            }
            
            // Get all windows in the layout
            guard let groupWindows = layoutGroups[groupID],
                  let positions = layoutWindowPositions[groupID] else {
                return
            }
            
            // Sort windows by position
            let sortedWindows = groupWindows.sorted { positions[$0] ?? 0 < positions[$1] ?? 0 }
            
            // Find current window's index
            guard let currentIndex = sortedWindows.firstIndex(of: bundleID) else { return }
            
            // Calculate next index (wrap around)
            let nextIndex = (currentIndex - 1 + sortedWindows.count) % sortedWindows.count
            let nextBundleID = sortedWindows[nextIndex]
            
            // Focus the next window
            if let nextWindow = appWindows[nextBundleID]?.first {
                nextWindow.focus()
                centerCursorInWindow(nextWindow)
                currentlyFocusedWindow = nextWindow
            }
        }
    }


// Helper extension for safe array access
private extension Array {
    subscript(safe index: Int) -> Element? {
        indices.contains(index) ? self[index] : nil
    }
}


