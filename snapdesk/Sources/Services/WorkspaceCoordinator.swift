//
//  WorkspaceCoordinator.swift
//  snapdesk
//

import Foundation
import AppKit

class WorkspaceCoordinator: WindowManaging, WorkspaceProvider {

    var workspace: WorkspaceModel

    // Managers
    private var cyclingManager: CyclingManager!
    private var layoutManager: LayoutManager!
    private var appLifecycleManager: AppLifecycleManager
    private var screenConfigHandler: ScreenConfigurationHandler!
    private var windowOrderManager: WindowOrderManager!
    private var windowCleanupService: WindowCleanupService!
    private var screenNavigationService: ScreenNavigationService!
    private var layoutVisualizationService: LayoutVisualizationService!
    private var windowRefreshService: WindowRefreshService!

    // Track last focused window per screen (keyed by screen ID)
    private var lastFocusedWindowPerScreen: [String: AXWindow] = [:]

    init() {
        // Initialize workspace first
        var ws = snapdesk.WorkspaceModel()
        self.workspace = ws
        
        // Initialize app lifecycle manager first since it doesn't depend on delegates
        self.appLifecycleManager = AppLifecycleManager()
        
        // Now that self is initialized, create the managers with delegate pattern
        self.cyclingManager = CyclingManager(delegate: self)
        self.layoutManager = LayoutManager(delegate: self)
        self.screenConfigHandler = ScreenConfigurationHandler(workspaceProvider: self)
        self.windowOrderManager = WindowOrderManager(workspaceProvider: self, cyclingManager: self.cyclingManager)
        self.windowCleanupService = WindowCleanupService(workspaceProvider: self, cyclingManager: self.cyclingManager)
        self.screenNavigationService = ScreenNavigationService(workspaceProvider: self, layoutManager: self.layoutManager, lastFocusedWindowPerScreen: self.lastFocusedWindowPerScreen)
        self.layoutVisualizationService = LayoutVisualizationService(workspaceProvider: self)
        self.windowRefreshService = WindowRefreshService(workspaceProvider: self)

        // Set ourselves as the delegate for app lifecycle events
        self.appLifecycleManager.delegate = self

        let discovered = scanWindows()
        let defaultLayout = ConfigurationHelpers.getDefaultLayoutMode()
        
        
        for (win, screen) in discovered {
            if let idx = workspace.screens.firstIndex(where: { $0.screen == screen }) {
                // Create a fresh WindowSet with the default layout
                let newSet = WindowSet(layout: defaultLayout, windows: [win], screenID: screen.screenID())
                workspace.screens[idx].windowSets.append(newSet)
                
                // Auto-expand the window if the setting is enabled (without bringing to front during startup)
                if ConfigurationHelpers.shouldAutoExpandNewWindows() {
                    newSet.expandWindows(on: screen, bringToFront: false)
                }
            }
        }
        
        // Final comprehensive pass: Ensure ALL windows are expanded if auto-expand is enabled
        if ConfigurationHelpers.shouldAutoExpandNewWindows() {
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
    // TODO: Extract to AppFocusService (handles app focusing, cycling, window tracking)

    func focusApp(_ bundleID: String) async {
        appLifecycleManager.setProgrammaticFocus(true)

        guard let (windowSet, targetWindow) = cyclingManager.getNextWindowSetToFocus(for: bundleID) else {
            appLifecycleManager.launchApp(bundleID: bundleID)
            appLifecycleManager.setProgrammaticFocus(false)
            return
        }

        await performWindowFocus(windowSet: windowSet, targetWindow: targetWindow, bundleID: bundleID)
    }

    func cycleCurrentAppBackward() async {
        guard let frontmostApp = NSWorkspace.shared.frontmostApplication,
              let bundleID = frontmostApp.bundleIdentifier else { return }
        await focusAppBackward(bundleID)
    }

    private func focusAppBackward(_ bundleID: String) async {
        appLifecycleManager.setProgrammaticFocus(true)

        guard let (windowSet, targetWindow) = cyclingManager.getPreviousWindowSetToFocus(for: bundleID) else {
            appLifecycleManager.setProgrammaticFocus(false)
            return
        }

        await performWindowFocus(windowSet: windowSet, targetWindow: targetWindow, bundleID: bundleID)
    }

    private func performWindowFocus(windowSet: WindowSet, targetWindow: AXWindow?, bundleID: String) async {
        guard let targetWindow = targetWindow else {
            appLifecycleManager.setProgrammaticFocus(false)
            return
        }

        let focusSucceeded = targetWindow.focus()
        if focusSucceeded {
            trackWindowFocus(targetWindow)
        }

        try? await Task.sleep(nanoseconds: 100_000_000)

        if !focusSucceeded {
            removeDeadWindow(targetWindow, from: windowSet, bundleID: bundleID)
            await focusNextAvailableWindow(for: bundleID, excluding: targetWindow)
            appLifecycleManager.setProgrammaticFocus(false)
            return
        }

        WorkspaceHelpers.moveCursorToCenter(of: targetWindow)

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
        guard let (targetWindowSet, _, _) = WorkspaceHelpers.findWindowSetContaining(focusedWindow, in: workspace) else {
            log("❌ Focused window not found in any WindowSet")
            return
        }
        
        log("🎯 Using WindowSet containing focused window as target")
        log("📊 Target WindowSet info: \(targetWindowSet.windows.count) windows on screen \(targetWindowSet.screenID ?? "nil")")
        layoutManager.addWindowToLayout(currentWindowSet: targetWindowSet, bundleID: bundleID)
    }
    
    // MARK: - Screen Management

    func toggleFullScreen() {
        screenNavigationService.toggleFullScreen()
    }

    func focusScreen(_ screenNumber: Int) {
        screenNavigationService.focusScreen(screenNumber) { [weak self] window in
            self?.trackWindowFocus(window)
        }
    }

    func throwToScreen(_ screenNumber: Int) {
        screenNavigationService.throwToScreen(screenNumber) { [weak self] window in
            self?.trackWindowFocus(window)
        }
    }

    // MARK: - WindowManaging methods

    func focusScreen(at index: Int) {
        screenNavigationService.focusScreenAt(index: index, screenList: screenList(), windowOnScreen: windowOnScreen)
    }

    func throwFrontmostWindow(toScreen index: Int) {
        screenNavigationService.throwFrontmostWindow(toScreen: index) { [weak self] window in
            self?.trackWindowFocus(window)
        }
    }

    func throwToCurrentLayout() {
        guard let window = frontmostWindow(),
              let screen = NSScreen.main else { return }

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
        guard let focusedWindow = frontmostWindow() else { return }
        let axWindow = AXWindow(axElement: focusedWindow)

        if let windowToFocus = layoutManager.removeCurrentWindowFromLayout(currentWindow: axWindow) {
            windowToFocus.raise()
            windowToFocus.focus()
            trackWindowFocus(windowToFocus)
            WorkspaceHelpers.moveCursorToCenter(of: windowToFocus)
        }
    }

    func toggleLayoutForCurrentWindowSet() {
        guard let windowSet = getCurrentWindowSet() else { return }
        layoutManager.toggleLayout(for: windowSet)
    }

    func toggleFullScreenLayout() {
        guard let window = frontmostWindow(),
              let screen = NSScreen.main else { return }
        let vf = screen.visibleFrame
        move(window: window, to: vf)
    }
      
    func increaseMainPanelSize() {
        guard let windowSet = getCurrentWindowSet() else { return }
        layoutManager.increaseMainPanelSize(for: windowSet)
    }

    func decreaseMainPanelSize() {
        guard let windowSet = getCurrentWindowSet() else { return }
        layoutManager.decreaseMainPanelSize(for: windowSet)
    }

    func expandCurrentLayout() {
        guard let windowSet = getCurrentWindowSet() else { return }
        layoutManager.expandLayout(for: windowSet)
    }
      
    // MARK: - Layout Visualization

    func showLayoutVisualization() {
        layoutVisualizationService.showLayoutVisualization()
    }

    private func showAutomaticLayoutVisualization() {
        layoutVisualizationService.showAutomaticLayoutVisualization()
    }

    // MARK: - Window Positioning

    func positionWindowLeft() {
        guard let w = frontmostWindow() else { return }
        layoutManager.positionSingleWindow(AXWindow(axElement: w), to: "left")
    }

    func positionWindowRight() {
        guard let w = frontmostWindow() else { return }
        layoutManager.positionSingleWindow(AXWindow(axElement: w), to: "right")
    }

    func positionWindowTop() {
        guard let w = frontmostWindow() else { return }
        layoutManager.positionSingleWindow(AXWindow(axElement: w), to: "top")
    }

    func positionWindowBottom() {
        guard let w = frontmostWindow() else { return }
        layoutManager.positionSingleWindow(AXWindow(axElement: w), to: "bottom")
    }

    func positionWindowTopLeft() {
        guard let w = frontmostWindow() else { return }
        layoutManager.positionSingleWindow(AXWindow(axElement: w), to: "topLeft")
    }

    func positionWindowTopRight() {
        guard let w = frontmostWindow() else { return }
        layoutManager.positionSingleWindow(AXWindow(axElement: w), to: "topRight")
    }

    func positionWindowBottomLeft() {
        guard let w = frontmostWindow() else { return }
        layoutManager.positionSingleWindow(AXWindow(axElement: w), to: "bottomLeft")
    }

    func positionWindowBottomRight() {
        guard let w = frontmostWindow() else { return }
        layoutManager.positionSingleWindow(AXWindow(axElement: w), to: "bottomRight")
    }

    func positionWindowCenter() {
        guard let w = frontmostWindow() else { return }
        layoutManager.positionSingleWindow(AXWindow(axElement: w), to: "center")
    }

    // MARK: - Directional Window Movement

    func moveWindowLeft() {
        guard let w = frontmostWindow() else { return }
        layoutManager.moveWindowDirectionally(AXWindow(axElement: w), direction: .left)
    }

    func moveWindowRight() {
        guard let w = frontmostWindow() else { return }
        layoutManager.moveWindowDirectionally(AXWindow(axElement: w), direction: .right)
    }

    func moveWindowUp() {
        guard let w = frontmostWindow() else { return }
        layoutManager.moveWindowDirectionally(AXWindow(axElement: w), direction: .up)
    }

    func moveWindowDown() {
        guard let w = frontmostWindow() else { return }
        layoutManager.moveWindowDirectionally(AXWindow(axElement: w), direction: .down)
    }
    
    // MARK: - Window Reordering

    func moveWindowUpInLayout() {
        windowOrderManager.moveWindowUpInLayout()
    }

    func moveWindowDownInLayout() {
        windowOrderManager.moveWindowDownInLayout()
    }
    
    // MARK: - Dead Window Handling

    private func removeDeadWindow(_ deadWindow: AXWindow, from windowSet: WindowSet, bundleID: String) {
        windowCleanupService.removeDeadWindow(deadWindow, from: windowSet, bundleID: bundleID) { [weak self] in
            self?.showAutomaticLayoutVisualization()
        }
    }

    private func focusNextAvailableWindow(for bundleID: String, excluding excludedWindow: AXWindow) async {
        await windowCleanupService.focusNextAvailableWindow(for: bundleID, excluding: excludedWindow) { [weak self] window in
            self?.trackWindowFocus(window)
        }
    }

    // MARK: - Private Helper Methods

    private func getCurrentWindowSet() -> WindowSet? {
        if let currentWindowSet = cyclingManager.getCurrentWindowSet {
            return currentWindowSet
        }

        guard let focusedWindow = frontmostWindow() else { return nil }
        let axWindow = AXWindow(axElement: focusedWindow)

        if let (windowSet, _, _) = WorkspaceHelpers.findWindowSetContaining(axWindow, in: workspace) {
            return windowSet
        }

        return nil
    }

    private func screenList() -> [NSScreen] {
        return NSScreen.screens
    }

    private func windowOnScreen(_ screen: NSScreen) -> AXUIElement? {
        if let w = frontmostWindow(),
           let f = windowFrame(of: w),
           f.intersects(screen.frame) {
            return w
        }
        return nil
    }

    private func trackWindowFocus(_ window: AXWindow) {
        let windowFrame = window.frame()
        if let screen = AMScreen.availableScreens.first(where: { $0.frame().intersects(windowFrame) }),
           let screenID = screen.screenID() {
            lastFocusedWindowPerScreen[screenID] = window
            // Sync with service (service keeps a copy for its operations)
            screenNavigationService = ScreenNavigationService(workspaceProvider: self, layoutManager: layoutManager, lastFocusedWindowPerScreen: lastFocusedWindowPerScreen)
        }
    }
    
    private func refreshWindows() {
        windowRefreshService.refreshWindows { [weak self] in
            self?.showAutomaticLayoutVisualization()
        }
    }
}

// MARK: - Delegate Conformances

extension WorkspaceCoordinator: CyclingManagerDelegate, LayoutManagerDelegate {
}

extension WorkspaceCoordinator: AppLifecycleDelegate {
    
    func appDidLaunch(_ app: NSRunningApplication) {
        DispatchQueue.main.asyncAfter(deadline: .now() + 1.0) { [weak self] in
            self?.refreshWindows()
        }
    }

    func appDidTerminate(_ app: NSRunningApplication) {
        if let bundleID = app.bundleIdentifier {
            cyclingManager.resetCycling(for: bundleID)
        }
        refreshWindows()
    }

    func appDidActivate(_ app: NSRunningApplication) {
        if let bundleID = app.bundleIdentifier {
            cyclingManager.resetCycling(for: bundleID)
        }
    }
    
    func windowDidCreate(_ window: AXWindow, for app: NSRunningApplication) {
        let windowID = window.windowID()
        let windowPID = window.pid()

        // Skip if window already exists
        for screen in workspace.screens {
            for windowSet in screen.windowSets {
                if windowSet.windows.contains(where: { $0.windowID() == windowID && $0.pid() == windowPID }) {
                    return
                }
            }
        }

        guard let amScreen: AMScreen = window.snapScreen() else { return }

        // Find or create screen workspace
        if workspace.screens.firstIndex(where: { $0.screen == amScreen }) == nil {
            workspace.screens.append(ScreenWorkspace(screen: amScreen, sets: []))
        }

        // Create and add new WindowSet
        let defaultLayout = ConfigurationHelpers.getDefaultLayoutMode()
        let newWindowSet = WindowSet(layout: defaultLayout, windows: [window], screenID: amScreen.screenID())

        if let screenIndex = workspace.screens.firstIndex(where: { $0.screen == amScreen }) {
            workspace.screens[screenIndex].windowSets.append(newWindowSet)

            if ConfigurationHelpers.shouldAutoExpandNewWindows() {
                newWindowSet.expandWindows(on: amScreen, bringToFront: false)
            }
        }
    }
    
    func windowDidBecomeKey() {
        updateCurrentWindowSetFromFocus()
    }
    
    func windowDidBecomeMain() {
        updateCurrentWindowSetFromFocus()
    }
    
    // MARK: - Screen Configuration Changes
    // Delegated to ScreenConfigurationHandler

    func screenParametersDidChange() {
        screenConfigHandler.handleScreenParametersChange()
    }
    
    /// Efficiently updates currentWindowSet based on the current focus (called only when focus actually changes)
    private func updateCurrentWindowSetFromFocus() {
        guard let focusedWindow = frontmostWindow() else { return }
        let axWindow = AXWindow(axElement: focusedWindow)
        
        cyclingManager.updateCyclingStateFromFocus(window: axWindow)
    }
}
