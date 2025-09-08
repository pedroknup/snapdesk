//
//  SimpleWindowManager.swift
//  snapdesk
//
//  Created by Pedro Knup on 27/08/2025.
//

import Foundation
import AppKit

class SimpleWindowManager: WindowManaging {
    
    var workspace: WorkspaceModel
    
    // Managers
    private var cyclingManager: CyclingManager!
    private var layoutManager: LayoutManager!
    private var appLifecycleManager: AppLifecycleManager
    
    init() {
        // Initialize workspace first
        var ws = snapdesk.WorkspaceModel()
        self.workspace = ws
        
        // Initialize app lifecycle manager first since it doesn't depend on delegates
        self.appLifecycleManager = AppLifecycleManager()
        
        // Now that self is initialized, create the managers with delegate pattern
        self.cyclingManager = CyclingManager(delegate: self)
        self.layoutManager = LayoutManager(delegate: self)
        
        // Set ourselves as the delegate for app lifecycle events
        self.appLifecycleManager.delegate = self

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

    // MARK: - App Management
    
    func focusApp(_ bundleID: String) async {
        // Set flag to indicate we're programmatically focusing
        appLifecycleManager.setProgrammaticFocus(true)
        
        guard let (windowSet, targetWindow) = cyclingManager.getNextWindowSetToFocus(for: bundleID) else {
            // No windows found - try to launch the app
            appLifecycleManager.launchApp(bundleID: bundleID)
            appLifecycleManager.setProgrammaticFocus(false)
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
            let focusSucceeded = targetWindow.focus()
            
            if !focusSucceeded {
                log("⚠️ Failed to focus target window - likely no longer exists. Removing from layout and trying next window.")
                
                // Remove the dead window from its WindowSet
                removeDeadWindow(targetWindow, from: windowSet, bundleID: bundleID)
                
                // Try to find and focus the next available window of the same app
                await focusNextAvailableWindow(for: bundleID, excluding: targetWindow)
                
                // Reset the programmatic focus flag and return early
                appLifecycleManager.setProgrammaticFocus(false)
                return
            } else {
                moveCursorToCenter(of: targetWindow)
            }
        }
        
        // Reset the flag after a longer delay to allow the focus events to fire,
        // especially important for cross-screen window transitions which take longer
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) { [weak self] in
            self?.appLifecycleManager.setProgrammaticFocus(false)
        }
    }
    
    func addWindowToLayout(_ bundleID: String) {
        log("➕ addWindowToLayout called for bundleID: \(bundleID)")
        
        // Try to use the current WindowSet from cycling first
        if let currentWindowSet = cyclingManager.getCurrentWindowSet {
            log("🎯 Using current WindowSet from cycling manager")
            log("📊 Current WindowSet info: \(currentWindowSet.windows.count) windows on screen \(currentWindowSet.screenID ?? "nil")")
            layoutManager.addWindowToLayout(currentWindowSet: currentWindowSet, bundleID: bundleID)
            return
        }
        
        // If no current WindowSet from cycling, find the focused window and use its WindowSet as target
        guard let focusedWindowElement = frontmostWindow() else {
            log("❌ No focused window found - cannot determine target WindowSet")
            return
        }
        
        let focusedWindow = AXWindow(axElement: focusedWindowElement)
        log("🎯 Found focused window: '\(focusedWindow.title() ?? "untitled")'")
        
        // Find the WindowSet containing the focused window
        guard let (targetWindowSet, _, _) = findWindowSetContaining(focusedWindow) else {
            log("❌ Focused window not found in any WindowSet")
            return
        }
        
        log("🎯 Using WindowSet containing focused window as target")
        log("📊 Target WindowSet info: \(targetWindowSet.windows.count) windows on screen \(targetWindowSet.screenID ?? "nil")")
        layoutManager.addWindowToLayout(currentWindowSet: targetWindowSet, bundleID: bundleID)
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
        layoutManager.throwWindow(axWindow, toScreen: screenNumber)
        
        // Focus the moved window
        axWindow.raise()
        axWindow.focus()
        moveCursorToCenter(of: axWindow)
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
        
        if let windowToFocus = layoutManager.removeCurrentWindowFromLayout(currentWindow: axWindow) {
            // Focus the window that was before the removed window in the original layout
            windowToFocus.raise()
            windowToFocus.focus()
            moveCursorToCenter(of: windowToFocus)
        }
    }
      
    func toggleLayoutForCurrentWindowSet() {
        log("🔄 toggleLayoutForCurrentWindowSet() called")
        
        // Use the current WindowSet if available, otherwise find it from the focused window
        var targetWindowSet: WindowSet?
        
        if let currentWindowSet = cyclingManager.getCurrentWindowSet {
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
            }
        }
        
        guard let windowSet = targetWindowSet else {
            log("❌ No WindowSet found to toggle layout")
            return
        }
        
        layoutManager.toggleLayout(for: windowSet)
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
        
        if let currentWindowSet = cyclingManager.getCurrentWindowSet {
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
        
        layoutManager.increaseMainPanelSize(for: windowSet)
    }
      
    func decreaseMainPanelSize() {
        log("⬇️ decreaseMainPanelSize() called")
        
        // Use the current WindowSet if available, otherwise find it from the focused window
        var targetWindowSet: WindowSet?
        
        if let currentWindowSet = cyclingManager.getCurrentWindowSet {
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
        
        layoutManager.decreaseMainPanelSize(for: windowSet)
    }
      
    func expandCurrentLayout() {
        log("🔲 expandCurrentLayout() called")
        
        // Use the current WindowSet if available, otherwise find it from the focused window
        var targetWindowSet: WindowSet?
        
        if let currentWindowSet = cyclingManager.getCurrentWindowSet {
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
            log("❌ No WindowSet found to expand")
            return
        }
        
        layoutManager.expandLayout(for: windowSet)
    }
      
    // MARK: - Layout Visualization
    
    func showLayoutVisualization() {
        showLayoutVisualization(duration: 3.0, isAutomatic: false)
    }
    
    private func showLayoutVisualization(duration: TimeInterval, isAutomatic: Bool) {
        // Check if automatic layout visualization is enabled (only for automatic triggers)
        if isAutomatic {
            let showAutoLayoutViz = UserDefaults.standard.object(forKey: "showAutoLayoutVisualization") as? Bool ?? true
            if !showAutoLayoutViz {
                return
            }
        }
        
        log("🎨 Showing layout visualization (\(isAutomatic ? "automatic" : "manual"))")
        
        // Ensure UI operations happen on main thread
        DispatchQueue.main.async { [weak self] in
            guard let self = self else { return }
            
            let attributedText = self.createLayoutVisualization()
            
            // Show the visualization using FloatingWindowHelper with larger font
            FloatingWindowHelper.showFloatingWindow(
                attributedText: attributedText,
                position: .center,
                duration: duration,
                fontSize: 14  // Larger, more readable font
            )
        }
    }
    
    private func showAutomaticLayoutVisualization() {
        // Use shorter duration for automatic displays
        showLayoutVisualization(duration: 1.5, isAutomatic: true)
    }
    
    private func createLayoutVisualization() -> NSAttributedString {
        // Get the currently focused window if any
        let focusedWindowID: CGWindowID? = {
            if let focusedElement = frontmostWindow() {
                let axWindow = AXWindow(axElement: focusedElement)
                return axWindow.cgID()
            }
            return nil
        }()
        
        // Get the current screen (where the focused window is)
        let currentScreenID: String? = {
            if let focusedElement = frontmostWindow() {
                let axWindow = AXWindow(axElement: focusedElement)
                return axWindow.snapScreen()?.screenID()
            }
            return nil
        }()
        
        // Ensure workspace access is on main thread to avoid concurrent access issues
        let workspaceCopy = workspace
        return LayoutVisualizationRenderer.renderLayoutVisualization(
            workspace: workspaceCopy,
            focusedWindowID: focusedWindowID,
            currentScreenID: currentScreenID
        )
    }

    // MARK: - Window Positioning
      
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
    
    // MARK: - Window Reordering
    
    func moveWindowUpInLayout() {
        log("⬆️ moveWindowUpInLayout() called - SHORTCUT TRIGGERED!")
        
        moveWindowInLayout(direction: .up)
    }
    
    func moveWindowDownInLayout() {
        log("⬇️ moveWindowDownInLayout() called - SHORTCUT TRIGGERED!")
        
        moveWindowInLayout(direction: .down)
    }
    
    private enum MoveDirection {
        case up, down
    }
    
    private func moveWindowInLayout(direction: MoveDirection) {
        // Ensure this runs on main thread for thread safety
        DispatchQueue.main.async { [weak self] in
            guard let self = self else { return }
            
            guard let focusedWindow = frontmostWindow() else {
                log("❌ No focused window found")
                FloatingWindowHelper.showFloatingWindow(
                    text: "No window focused",
                    position: .center,
                    duration: 1.5,
                    fontSize: 14
                )
                return
            }
            
            self.performWindowCyclingOrderChange(direction: direction, focusedWindow: focusedWindow)
        }
    }
    
    private func performWindowCyclingOrderChange(direction: MoveDirection, focusedWindow: AXUIElement) {
        let axWindow = AXWindow(axElement: focusedWindow)
        let focusedWindowID = axWindow.cgID()
        
        // Get the app for this window
        guard let app = NSRunningApplication(processIdentifier: axWindow.pid()),
              let bundleID = app.bundleIdentifier else {
            log("❌ Could not find app for focused window")
            FloatingWindowHelper.showFloatingWindow(
                text: "Could not identify app",
                position: .center,
                duration: 1.5,
                fontSize: 14
            )
            return
        }
        
        // Find all unique windows for this app (deduplicated by window ID)
        var seenWindowIDs: Set<CGWindowID> = []
        var appWindows: [AXWindow] = []
        for screenWorkspace in workspace.screens {
            for windowSet in screenWorkspace.windowSets {
                for window in windowSet.windows {
                    if let windowApp = NSRunningApplication(processIdentifier: window.pid()),
                       windowApp.bundleIdentifier == bundleID {
                        let windowID = window.cgID()
                        if !seenWindowIDs.contains(windowID) {
                            seenWindowIDs.insert(windowID)
                            appWindows.append(window)
                        }
                    }
                }
            }
        }
        
        log("🔍 Found \(appWindows.count) unique windows for \(bundleID)")
        for (index, window) in appWindows.enumerated() {
            let title = window.title() ?? "untitled"
            let windowID = window.cgID()
            let isFocused = windowID == focusedWindowID
            log("🔍   \(index): [\(windowID)] \(title) \(isFocused ? "← FOCUSED" : "")")
        }
        
        // Find current position in the app's window list
        guard let currentIndex = appWindows.firstIndex(where: { $0.cgID() == focusedWindowID }) else {
            log("❌ Could not find focused window in app's window list")
            return
        }
        
        log("🔍 Current window is at index \(currentIndex) out of \(appWindows.count)")
        
        let newIndex: Int
        switch direction {
        case .up:
            // Moving up in list means earlier in cycling order
            newIndex = max(0, currentIndex - 1)
            if newIndex == currentIndex {
                FloatingWindowHelper.showFloatingWindow(
                    text: "Window already first in cycling order",
                    position: .center,
                    duration: 1.5,
                    fontSize: 14
                )
                return
            }
        case .down:
            // Moving down in list means later in cycling order
            newIndex = min(appWindows.count - 1, currentIndex + 1)
            if newIndex == currentIndex {
                FloatingWindowHelper.showFloatingWindow(
                    text: "Window already last in cycling order",
                    position: .center,
                    duration: 1.5,
                    fontSize: 14
                )
                return
            }
        }
        
        log("🔄 Using CyclingManager to reorder windows")
        
        // Use the new cycling manager approach
        let moveDirection = direction == .up ? -1 : 1
        guard let newOrder = cyclingManager.moveWindowInCyclingOrder(
            for: bundleID, 
            windowID: focusedWindowID, 
            direction: moveDirection
        ) else {
            log("❌ Failed to update cycling order")
            return
        }
        
        // Find the new position
        let newPosition = newOrder.firstIndex(of: focusedWindowID) ?? 0
        let directionText = direction == .up ? "earlier" : "later"
        let positionText = "\(newPosition + 1) of \(newOrder.count)"
        
        log("✅ Moved window \(directionText) in cycling order to position \(positionText)")
        
        // Show feedback with the app's window list in the new order
        let appName = app.localizedName ?? bundleID
        var feedbackText = "\(appName) - Cycling Order:\n"
        feedbackText += "────────────────────\n"
        
        // Display windows in the new cycling order
        for (index, windowID) in newOrder.enumerated() {
            // Find the window object for this ID
            var windowTitle = "Unknown"
            for screenWorkspace in workspace.screens {
                for windowSet in screenWorkspace.windowSets {
                    if let window = windowSet.windows.first(where: { $0.cgID() == windowID }) {
                        let title = window.title() ?? "untitled"
                        let cleanTitle = title.replacingOccurrences(of: "✳", with: "").trimmingCharacters(in: .whitespaces)
                        windowTitle = cleanTitle.isEmpty ? "untitled" : cleanTitle
                        break
                    }
                }
            }
            
            let truncatedTitle = truncateString(windowTitle, maxLength: 30)
            let isCurrent = windowID == focusedWindowID
            let marker = isCurrent ? " ◀" : ""
            feedbackText += "\(index + 1). \(truncatedTitle)\(marker)\n"
        }
        
        log("📋 New cycling order for \(bundleID): \(newOrder)")
        
        FloatingWindowHelper.showFloatingWindow(
            text: feedbackText,
            position: .center,
            duration: 2.5,
            fontSize: 14
        )
    }
    
    private func truncateString(_ string: String, maxLength: Int) -> String {
        if string.count <= maxLength {
            return string
        }
        let endIndex = string.index(string.startIndex, offsetBy: maxLength - 3)
        return String(string[..<endIndex]) + "..."
    }
    
    // MARK: - Dead Window Handling
    
    /// Removes a dead window from its WindowSet and cleans up empty WindowSets
    private func removeDeadWindow(_ deadWindow: AXWindow, from windowSet: WindowSet, bundleID: String) {
        log("🗑️ Removing dead window '\(deadWindow.title() ?? "untitled")' from WindowSet")
        
        // Remove the window from the WindowSet
        if let windowIndex = windowSet.windows.firstIndex(where: { $0.cgID() == deadWindow.cgID() }) {
            windowSet.windows.remove(at: windowIndex)
            log("✅ Removed dead window from WindowSet. WindowSet now has \(windowSet.windows.count) windows")
            
            // If the WindowSet is now empty, remove it from the workspace
            if windowSet.windows.isEmpty {
                removeEmptyWindowSet(windowSet)
            }
            
            // Show automatic layout visualization after removal
            showAutomaticLayoutVisualization()
        } else {
            log("⚠️ Dead window not found in expected WindowSet")
        }
    }
    
    /// Attempts to focus the next available window of the same app
    private func focusNextAvailableWindow(for bundleID: String, excluding excludedWindow: AXWindow) async {
        log("🔄 Looking for next available window for bundle: \(bundleID)")
        
        // Get the next WindowSet and window from the cycling manager
        guard let (nextWindowSet, nextTargetWindow) = cyclingManager.getNextWindowSetToFocus(for: bundleID) else {
            log("❌ No more windows available for bundle: \(bundleID)")
            return
        }
        
        // Make sure we're not trying to focus the same dead window again
        if let nextWindow = nextTargetWindow, nextWindow.cgID() == excludedWindow.cgID() {
            log("⚠️ Next window is the same as excluded window, skipping")
            return
        }
        
        // Expand the windows in the WindowSet
        if shouldAutoExpandNewWindows() {
            nextWindowSet.expandWindows()
        }
        
        // Try to raise all windows except the target
        await nextWindowSet.raiseAllWindows(excluding: nextTargetWindow)
        
        // Focus the next available window
        if let nextWindow = nextTargetWindow {
            log("🎯 Attempting to focus next window: '\(nextWindow.title() ?? "untitled")'")
            nextWindow.raise()
            let focusSucceeded = nextWindow.focus()
            
            if focusSucceeded {
                log("✅ Successfully focused next window")
                moveCursorToCenter(of: nextWindow)
            } else {
                log("❌ Failed to focus next window - it may also be dead")
                // Could recursively call this method, but let's avoid infinite recursion for now
            }
        }
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

    // MARK: - Private Helper Methods
    
    private func positionSingleWindow(to position: String) {
        // Get the currently focused window
        guard let focusedWindow = frontmostWindow() else {
            log("❌ No focused window found")
            return
        }
        
        let axWindow = AXWindow(axElement: focusedWindow)
        layoutManager.positionSingleWindow(axWindow, to: position)
    }

    private func currentWindow() -> AXUIElement? {
         return frontmostWindow()
     }
    
    private func screenList() -> [NSScreen] {
        // Sort screens in a stable order (menu bar first)
        return NSScreen.screens
    }

    private func windowOnScreen(_ screen: NSScreen) -> AXUIElement? {
        // Super simple: if the frontmost window is already on this screen, return it
        if let w = currentWindow(),
           let f = windowFrame(of: w),
           f.intersects(screen.frame) {
            return w
        }
        return nil
    }
    
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
        
        // Show automatic layout visualization
        showAutomaticLayoutVisualization()
    }
}

// MARK: - Delegate Conformances

extension SimpleWindowManager: CyclingManagerDelegate, LayoutManagerDelegate {
    // Both protocols require workspace property which is already implemented
}

// MARK: - AppLifecycleDelegate Implementation

extension SimpleWindowManager: AppLifecycleDelegate {
    
    func appDidLaunch(_ app: NSRunningApplication) {
        // Give the app a moment to create windows
        DispatchQueue.main.asyncAfter(deadline: .now() + 1.0) { [weak self] in
            self?.refreshWindows()
        }
    }
    
    func appDidTerminate(_ app: NSRunningApplication) {
        // Reset cycling if the terminated app was being cycled
        if let bundleID = app.bundleIdentifier {
            cyclingManager.resetCycling(for: bundleID)
        }
        
        refreshWindows()
    }
    
    func appDidActivate(_ app: NSRunningApplication) {
        // Reset cycling if a different app was activated manually (not via our hotkey)
        if let bundleID = app.bundleIdentifier {
            cyclingManager.resetCycling(for: bundleID)
        }
    }
    
    func windowDidCreate(_ window: AXWindow, for app: NSRunningApplication) {
        // Find the appropriate screen for this window
        guard let amScreen: AMScreen = window.snapScreen() else {
            log("❌ Could not determine screen for new window")
            return
        }
        
        
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
        let newWindowSet = WindowSet(layout: defaultLayout, windows: [window], screenID: amScreen.screenID())
        
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
    
    func windowDidBecomeKey() {
        updateCurrentWindowSetFromFocus()
    }
    
    func windowDidBecomeMain() {
        updateCurrentWindowSetFromFocus()
    }
    
    func screenParametersDidChange() {
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
    
    /// Efficiently updates currentWindowSet based on the current focus (called only when focus actually changes)
    private func updateCurrentWindowSetFromFocus() {
        guard let focusedWindow = frontmostWindow() else { return }
        let axWindow = AXWindow(axElement: focusedWindow)
        
        cyclingManager.updateCyclingStateFromFocus(window: axWindow)
    }
}
