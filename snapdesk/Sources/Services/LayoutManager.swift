//
//  LayoutManager.swift
//  snapdesk
//
//  Created by Pedro Knup on 05/09/2025.
//

import Foundation
import AppKit

// MARK: - Directional Window State

enum HorizontalAnchor {
    case none
    case left
    case right
}

enum VerticalAnchor {
    case none
    case top
    case bottom
}

enum DirectionalMovement {
    case left
    case right
    case up
    case down
}

struct DirectionalWindowState {
    var horizontalFraction: CGFloat = 1.0
    var verticalFraction: CGFloat = 1.0
    var horizontalAnchor: HorizontalAnchor = .none
    var verticalAnchor: VerticalAnchor = .none

    static let minimumFraction: CGFloat = 0.125  // 1/8 of screen

    var isDefault: Bool {
        return horizontalFraction == 1.0 && verticalFraction == 1.0 &&
               horizontalAnchor == .none && verticalAnchor == .none
    }

    mutating func reset() {
        horizontalFraction = 1.0
        verticalFraction = 1.0
        horizontalAnchor = .none
        verticalAnchor = .none
    }

    mutating func resetHorizontal() {
        horizontalFraction = 1.0
        horizontalAnchor = .none
    }

    mutating func resetVertical() {
        verticalFraction = 1.0
        verticalAnchor = .none
    }

    mutating func subdivideHorizontal() {
        if horizontalFraction > DirectionalWindowState.minimumFraction {
            horizontalFraction /= 2.0
        }
    }

    mutating func subdivideVertical() {
        if verticalFraction > DirectionalWindowState.minimumFraction {
            verticalFraction /= 2.0
        }
    }
}

protocol LayoutManagerDelegate: AnyObject {
    var workspace: WorkspaceModel { get set }
}

class LayoutManager {

    private weak var delegate: LayoutManagerDelegate?

    // Directional state per window (keyed by CGWindowID)
    private var directionalStates: [CGWindowID: DirectionalWindowState] = [:]

    init(delegate: LayoutManagerDelegate) {
        self.delegate = delegate
    }

    // MARK: - Directional State Access

    private func getDirectionalState(for windowID: CGWindowID) -> DirectionalWindowState {
        return directionalStates[windowID] ?? DirectionalWindowState()
    }

    private func setDirectionalState(_ state: DirectionalWindowState, for windowID: CGWindowID) {
        directionalStates[windowID] = state
    }

    func resetDirectionalState(for windowID: CGWindowID) {
        directionalStates.removeValue(forKey: windowID)
    }

    func resetAllDirectionalStates() {
        directionalStates.removeAll()
    }
    
    // MARK: - Layout Management
    
    /// Toggles the layout for the given WindowSet
    func toggleLayout(for windowSet: WindowSet) {
        log("🔄 Toggling layout for WindowSet with \(windowSet.windows.count) windows")
        windowSet.toggleLayout()
    }
    
    /// Expands the current layout for the given WindowSet
    func expandLayout(for windowSet: WindowSet) {
        log("🔲 Expanding layout for WindowSet")
        log("📐 Current layout: \(windowSet.layout) for WindowSet with \(windowSet.windows.count) window(s)")

        // Reset directional state for all windows in this WindowSet
        for window in windowSet.windows {
            resetDirectionalState(for: window.cgID())
        }

        // If the layout is floating, change it to wide first
        if windowSet.layout == .floating {
            log("🔄 Changing layout from floating to wide before expanding")
            windowSet.layout = .wide
        }

        // Expand the windows in the current WindowSet
        windowSet.expandWindows()

        log("✅ Windows expanded according to \(windowSet.layout) layout")

        // Layout indicator removed
    }
    
    // MARK: - Panel Size Management

    /// Returns the relevant screen dimension for panel size adjustment based on layout type
    /// - Returns: `.horizontal` for layouts that stack windows side-by-side (width adjustment),
    ///            `.vertical` for layouts that stack windows top-to-bottom (height adjustment),
    ///            or `nil` for layouts that don't support panel size adjustment
    private func panelDimensionType(for layout: LayoutKind) -> UnconstrainedDimension? {
        switch layout {
        case .wide, .horizontal_stack:
            return .horizontal
        case .tall, .vertical_stack:
            return .vertical
        case .fullscreen, .floating:
            return nil
        }
    }

    /// Increases the main panel size for the given WindowSet
    func increaseMainPanelSize(for windowSet: WindowSet) {
        log("⬆️ Increasing main panel size")

        // Only adjust if there are multiple windows
        guard windowSet.windows.count > 1 else {
            log("ℹ️ Cannot adjust main panel size with only one window")
            return
        }

        // Check if this layout supports panel size adjustment
        guard let dimensionType = panelDimensionType(for: windowSet.layout) else {
            log("ℹ️ Layout \(windowSet.layout) does not support panel size adjustment")
            return
        }

        // Calculate reasonable max based on window count
        // Allow main panel to take up to 70% of total space
        let screen = AMScreen.availableScreens.first { $0.screenID() == windowSet.screenID }
        let screenFrame = screen?.adjustedFrame() ?? CGRect(x: 0, y: 0, width: 1920, height: 1080)
        let dimension = dimensionType == .horizontal ? screenFrame.width : screenFrame.height
        let maxAdjustment = dimension * 0.7 - (dimension / CGFloat(windowSet.windows.count))
        
        // Increase by 40 pixels, but respect the maximum
        let newAdjustment = min(windowSet.mainPanelSizeAdjustment + 40, maxAdjustment)
        
        if newAdjustment == windowSet.mainPanelSizeAdjustment {
            log("⚠️ Main panel is already at maximum size")
            showMainPanelSizeNotification(text: "Main Panel: MAX")
            return
        }
        
        windowSet.mainPanelSizeAdjustment = newAdjustment
        log("📏 Main panel size adjustment is now: \(windowSet.mainPanelSizeAdjustment)px")
        
        // Re-expand windows with the new adjustment
        windowSet.expandWindows()
        
        // Show floating notification if enabled
        let adjustmentText = windowSet.mainPanelSizeAdjustment >= 0 ? "+\(Int(windowSet.mainPanelSizeAdjustment))" : "\(Int(windowSet.mainPanelSizeAdjustment))"
        showMainPanelSizeNotification(text: "Main Panel: \(adjustmentText)px")
    }
    
    /// Decreases the main panel size for the given WindowSet
    func decreaseMainPanelSize(for windowSet: WindowSet) {
        log("⬇️ Decreasing main panel size")

        // Only adjust if there are multiple windows
        guard windowSet.windows.count > 1 else {
            log("ℹ️ Cannot adjust main panel size with only one window")
            return
        }

        // Check if this layout supports panel size adjustment
        guard let dimensionType = panelDimensionType(for: windowSet.layout) else {
            log("ℹ️ Layout \(windowSet.layout) does not support panel size adjustment")
            return
        }

        // Calculate reasonable min based on window count
        // Prevent main panel from being smaller than 30% of equal space
        let screen = AMScreen.availableScreens.first { $0.screenID() == windowSet.screenID }
        let screenFrame = screen?.adjustedFrame() ?? CGRect(x: 0, y: 0, width: 1920, height: 1080)
        let dimension = dimensionType == .horizontal ? screenFrame.width : screenFrame.height
        let equalSpace = dimension / CGFloat(windowSet.windows.count)
        let minAdjustment = equalSpace * 0.3 - equalSpace // This gives us -70% of equal space
        
        // Decrease by 40 pixels, but respect the minimum
        let newAdjustment = max(windowSet.mainPanelSizeAdjustment - 40, minAdjustment)
        
        if newAdjustment == windowSet.mainPanelSizeAdjustment {
            log("⚠️ Main panel is already at minimum size")
            showMainPanelSizeNotification(text: "Main Panel: MIN")
            return
        }
        
        windowSet.mainPanelSizeAdjustment = newAdjustment
        log("📏 Main panel size adjustment is now: \(windowSet.mainPanelSizeAdjustment)px")
        
        // Re-expand windows with the new adjustment
        windowSet.expandWindows()
        
        // Show floating notification if enabled
        let adjustmentText = windowSet.mainPanelSizeAdjustment >= 0 ? "+\(Int(windowSet.mainPanelSizeAdjustment))" : "\(Int(windowSet.mainPanelSizeAdjustment))"
        showMainPanelSizeNotification(text: "Main Panel: \(adjustmentText)px")
    }
    
    // MARK: - Window Management
    
    /// Adds a window to the current layout from other WindowSets of the same app
    func addWindowToLayout(currentWindowSet: WindowSet, bundleID: String) {
        log("➕ Adding window to layout for bundleID: \(bundleID)")
        log("🎯 Current WindowSet: \(currentWindowSet.windows.count) window(s) on screen \(currentWindowSet.screenID ?? "nil")")
        
        // Find all WindowSets that contain windows from this bundle
        let allWindowSets = windowSets(for: bundleID)
        log("📊 Found \(allWindowSets.count) WindowSets for \(bundleID)")
        
        // Debug: Log each WindowSet and its screen
        for (index, windowSet) in allWindowSets.enumerated() {
            let windowTitles = windowSet.windows.compactMap { $0.title() }.joined(separator: ", ")
            log("   WindowSet \(index): \(windowSet.windows.count) window(s) on screen \(windowSet.screenID ?? "nil") - [\(windowTitles)]")
        }
        
        // Find a window from this bundle that's NOT in the current WindowSet
        var windowToAdd: AXWindow? = nil
        var sourceWindowSet: WindowSet? = nil
        
        for windowSet in allWindowSets {
            log("🔍 Checking WindowSet with ID: \(windowSet.id)")
            
            // Skip the current WindowSet
            if windowSet.id == currentWindowSet.id {
                log("   ⏭️ Skipping current WindowSet")
                continue
            }
            
            log("   🔍 Searching \(windowSet.windows.count) window(s) for bundle \(bundleID)")
            
            // Find windows in this set that belong to the bundle
            for window in windowSet.windows {
                guard let app = NSRunningApplication(processIdentifier: window.pid()),
                      app.bundleIdentifier == bundleID else { 
                    log("      ❌ Window '\(window.title() ?? "untitled")' doesn't match bundle")
                    continue 
                }
                
                log("      ✅ Found matching window: '\(window.title() ?? "untitled")'")
                // Found a window to add
                windowToAdd = window
                sourceWindowSet = windowSet
                break
            }
            
            if windowToAdd != nil {
                log("🎯 Selected window to add: '\(windowToAdd?.title() ?? "untitled")'")
                break
            }
        }
        
        guard let windowToAdd = windowToAdd else {
            log("❌ No window found from bundle \(bundleID) outside current WindowSet")
            return
        }
        
        log("🔄 Adding window '\(windowToAdd.title() ?? "<untitled>")' to current WindowSet")
        
        // Log detailed info about the cross-screen transfer
        let windowCurrentFrame = windowToAdd.frame()
        let windowCurrentScreen = windowToAdd.snapScreen()
        log("📍 Window current position: \(NSStringFromRect(windowCurrentFrame)) on screen: \(windowCurrentScreen?.screenID() ?? "unknown")")
        log("🎯 Target WindowSet is on screen: \(currentWindowSet.screenID ?? "nil")")
        
        // Add the window to the current WindowSet
        currentWindowSet.windows.append(windowToAdd)
        
        // Remove the window from its original WindowSet and clean up empty sets
        removeWindowFromOriginalWindowSet(windowToAdd, bundleID: bundleID)
        
        // If the window is on a different screen than the target WindowSet, move it immediately
        if let windowScreen = windowToAdd.snapScreen()?.screenID(),
           let targetScreenID = currentWindowSet.screenID,
           windowScreen != targetScreenID {
            log("🔄 Window is on different screen (\(windowScreen)) than target (\(targetScreenID)), moving it...")
            
            // Get the target screen
            if let targetScreen = AMScreen.availableScreens.first(where: { $0.screenID() == targetScreenID }) {
                let targetFrame = targetScreen.adjustedFrame()
                log("📐 Moving window to target screen frame: \(NSStringFromRect(targetFrame))")
                move(window: windowToAdd.axElementRef, to: targetFrame)
                
                // Small delay to ensure the move completed before expanding
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) { [weak self] in
                    log("🔧 Cross-screen move completed, now expanding windows...")
                    currentWindowSet.expandWindows()
                    
                    // Focus the newly added window after the layout is complete
                    windowToAdd.raise()
                    windowToAdd.focus()
                    self?.moveCursorToCenter(of: windowToAdd)
                    
                    log("✅ Cross-screen window addition completed")
                }
                
                // Skip the immediate expandWindows call since we'll do it after the delay
                return
            } else {
                log("❌ Could not find target screen with ID: \(targetScreenID)")
            }
        }
        
        // If the layout is floating, change it to wide for proper tiling
        if currentWindowSet.layout == .floating {
            log("🔄 Changing layout from floating to wide for proper window arrangement")
            currentWindowSet.layout = .wide
        }
        
        // Log the current state before expanding
        log("📊 Current WindowSet has \(currentWindowSet.windows.count) windows, layout: \(currentWindowSet.layout), screenID: \(currentWindowSet.screenID ?? "nil")")
        
        // Expand all windows in the updated WindowSet according to its layout
        log("🔧 Calling expandWindows() to reposition all windows...")
        currentWindowSet.expandWindows()
        
        // Verify the window was moved to the correct screen
        let windowNewFrame = windowToAdd.frame()
        let windowNewScreen = windowToAdd.snapScreen()
        log("📍 Window new position: \(NSStringFromRect(windowNewFrame)) on screen: \(windowNewScreen?.screenID() ?? "unknown")")
        
        if let targetScreen = AMScreen.availableScreens.first(where: { $0.screenID() == currentWindowSet.screenID }),
           !targetScreen.frame().intersects(windowNewFrame) {
            log("⚠️ WARNING: Window may not have been moved to target screen correctly!")
            log("🎯 Target screen frame: \(NSStringFromRect(targetScreen.frame()))")
        } else {
            log("✅ Window appears to be positioned correctly on target screen")
        }
        
        // Focus the newly added window
        windowToAdd.raise()
        windowToAdd.focus()
        moveCursorToCenter(of: windowToAdd)
        
        log("✅ Successfully added window to layout. WindowSet now has \(currentWindowSet.windows.count) windows")
    }
    
    /// Removes the current window from its layout
    func removeCurrentWindowFromLayout(currentWindow: AXWindow) -> AXWindow? {
        log("🗑️ Removing current window from layout")
        
        log("🎯 Removing window from layout: \(currentWindow.title() ?? "<untitled>")")
        
        // Find which WindowSet contains the focused window
        guard let (windowSet, windowIndex, screenIndex) = findWindowSetContaining(currentWindow) else {
            log("❌ Focused window not found in any WindowSet")
            return nil
        }
        
        // Check if the WindowSet has more than one window
        if windowSet.windows.count <= 1 {
            log("⚠️ WindowSet only has one window - nothing to remove from layout")
            return nil
        }
        
        log("📤 Removing window from WindowSet with \(windowSet.windows.count) windows")
        
        // Determine which window should be focused after removal (the previous one, or first if removing first)
        let windowToFocusIndex = windowIndex > 0 ? windowIndex - 1 : 0
        let windowToFocus = windowSet.windows[windowToFocusIndex]
        
        // Remove the window from the current WindowSet
        windowSet.windows.remove(at: windowIndex)
        
        // Create a new standalone WindowSet for the removed window
        guard let nsScreen: NSScreen = currentWindow.screen() else {
            log("❌ Could not determine screen for window")
            return nil
        }
        
        let screen = AMScreen(screen: nsScreen)
        
        let defaultLayout = getDefaultLayoutMode()
        let newWindowSet = WindowSet(layout: defaultLayout, windows: [currentWindow], screenID: screen.screenID())
        
        // Add the new WindowSet to the appropriate screen workspace
        guard let delegate = delegate else { return nil }
        if let screenWSIndex = delegate.workspace.screens.firstIndex(where: { $0.screen == screen }) {
            delegate.workspace.screens[screenWSIndex].windowSets.append(newWindowSet)
        }
        
        // Expand the original WindowSet (now with one less window) and focus the previous window
        windowSet.expandWindows()
        
        log("✅ Successfully removed window from layout. Original WindowSet now has \(windowSet.windows.count) windows, focused: \(windowToFocus.title() ?? "<untitled>")")
        
        return windowToFocus
    }
    
    // MARK: - Window Positioning
    
    /// Positions a single window to the specified position
    func positionSingleWindow(_ window: AXWindow, to position: String) {
        
        // Find the WindowSet containing this window
        guard let (windowSet, _, _) = findWindowSetContaining(window) else {
            log("❌ Window not found in any WindowSet")
            return
        }
        
        // Check if WindowSet has only one window
        if windowSet.windows.count > 1 {
            log("⚠️ Cannot position window - WindowSet has \(windowSet.windows.count) windows")
            // Layout indicator removed
            return
        }
        
        // Change layout to floating
        if windowSet.layout != .floating {
            log("🔄 Changing layout to floating for window positioning")
            windowSet.layout = .floating
        }
        
        // Get the screen frame
        guard let nsScreen = window.snapScreen()?.screen else {
            log("❌ Could not determine screen for window")
            return
        }
        let screen = AMScreen(screen: nsScreen)
        let screenFrame = screen.adjustedFrame()
        
        // Calculate the target frame based on position
        let targetFrame = calculateTargetFrame(for: position, on: screenFrame)
        
        // Apply window margin from settings
        let windowMargin = CGFloat(UserDefaults.standard.object(forKey: "windowMargin") as? Double ?? 8.0)
        let adjustedFrame = CGRect(
            x: targetFrame.minX + windowMargin,
            y: targetFrame.minY + windowMargin,
            width: targetFrame.width - (windowMargin * 2),
            height: targetFrame.height - (windowMargin * 2)
        )
        
        // Move the window
        move(window: window.axElementRef, to: adjustedFrame)
        log("📐 Positioned window to \(position): \(NSStringFromRect(adjustedFrame))")
        
        // Reset directional state when using fixed positioning
        resetDirectionalState(for: window.cgID())
    }

    // MARK: - Directional Window Positioning

    func moveWindowDirectionally(_ window: AXWindow, direction: DirectionalMovement) {
        guard let (windowSet, _, _) = findWindowSetContaining(window) else {
            log("❌ Window not found in any WindowSet")
            return
        }

        if windowSet.windows.count > 1 {
            log("⚠️ Cannot position window - WindowSet has \(windowSet.windows.count) windows")
            return
        }

        if windowSet.layout != .floating {
            log("🔄 Changing layout to floating for directional positioning")
            windowSet.layout = .floating
        }

        guard let nsScreen = window.snapScreen()?.screen else {
            log("❌ Could not determine screen for window")
            return
        }
        let screen = AMScreen(screen: nsScreen)
        let screenFrame = screen.adjustedFrame()

        let windowID = window.cgID()
        var state = getDirectionalState(for: windowID)

        let isInCorner = state.horizontalAnchor != .none && state.verticalAnchor != .none
        let hasHorizontalOnly = state.horizontalAnchor != .none && state.verticalAnchor == .none
        let hasVerticalOnly = state.verticalAnchor != .none && state.horizontalAnchor == .none

        switch direction {
        case .left:
            if isInCorner {
                // Any direction in corner: reset to that half
                state.reset()
                state.horizontalAnchor = .left
                state.horizontalFraction = 0.5
            } else if hasVerticalOnly {
                // Adjacent: form corner (e.g., top + left = top-left)
                state.horizontalAnchor = .left
                state.horizontalFraction = 0.5
            } else if hasHorizontalOnly {
                if state.horizontalAnchor == .left {
                    // Same direction: subdivide
                    state.subdivideHorizontal()
                } else {
                    // Opposite direction: reset to left half
                    state.reset()
                    state.horizontalAnchor = .left
                    state.horizontalFraction = 0.5
                }
            } else {
                // Fresh state: anchor left half
                state.horizontalAnchor = .left
                state.horizontalFraction = 0.5
            }

        case .right:
            if isInCorner {
                // Any direction in corner: reset to that half
                state.reset()
                state.horizontalAnchor = .right
                state.horizontalFraction = 0.5
            } else if hasVerticalOnly {
                // Adjacent: form corner (e.g., top + right = top-right)
                state.horizontalAnchor = .right
                state.horizontalFraction = 0.5
            } else if hasHorizontalOnly {
                if state.horizontalAnchor == .right {
                    // Same direction: subdivide
                    state.subdivideHorizontal()
                } else {
                    // Opposite direction: reset to right half
                    state.reset()
                    state.horizontalAnchor = .right
                    state.horizontalFraction = 0.5
                }
            } else {
                // Fresh state: anchor right half
                state.horizontalAnchor = .right
                state.horizontalFraction = 0.5
            }

        case .up:
            if isInCorner {
                // Any direction in corner: reset to that half
                state.reset()
                state.verticalAnchor = .top
                state.verticalFraction = 0.5
            } else if hasHorizontalOnly {
                // Adjacent: form corner (e.g., right + up = top-right)
                state.verticalAnchor = .top
                state.verticalFraction = 0.5
            } else if hasVerticalOnly {
                if state.verticalAnchor == .top {
                    // Same direction: subdivide
                    state.subdivideVertical()
                } else {
                    // Opposite direction: reset to top half
                    state.reset()
                    state.verticalAnchor = .top
                    state.verticalFraction = 0.5
                }
            } else {
                // Fresh state: anchor top half
                state.verticalAnchor = .top
                state.verticalFraction = 0.5
            }

        case .down:
            if isInCorner {
                // Any direction in corner: reset to that half
                state.reset()
                state.verticalAnchor = .bottom
                state.verticalFraction = 0.5
            } else if hasHorizontalOnly {
                // Adjacent: form corner (e.g., right + down = bottom-right)
                state.verticalAnchor = .bottom
                state.verticalFraction = 0.5
            } else if hasVerticalOnly {
                if state.verticalAnchor == .bottom {
                    // Same direction: subdivide
                    state.subdivideVertical()
                } else {
                    // Opposite direction: reset to bottom half
                    state.reset()
                    state.verticalAnchor = .bottom
                    state.verticalFraction = 0.5
                }
            } else {
                // Fresh state: anchor bottom half
                state.verticalAnchor = .bottom
                state.verticalFraction = 0.5
            }
        }

        setDirectionalState(state, for: windowID)

        let targetFrame = calculateDirectionalFrame(state: state, screenFrame: screenFrame)

        let windowMargin = CGFloat(UserDefaults.standard.object(forKey: "windowMargin") as? Double ?? 8.0)
        let adjustedFrame = CGRect(
            x: targetFrame.minX + windowMargin,
            y: targetFrame.minY + windowMargin,
            width: targetFrame.width - (windowMargin * 2),
            height: targetFrame.height - (windowMargin * 2)
        )

        move(window: window.axElementRef, to: adjustedFrame)
        log("📐 Directional move \(direction): h=\(state.horizontalFraction), v=\(state.verticalFraction)")
    }

    private func calculateDirectionalFrame(state: DirectionalWindowState, screenFrame: CGRect) -> CGRect {
        let width = screenFrame.width * state.horizontalFraction
        let height = screenFrame.height * state.verticalFraction

        let x: CGFloat
        switch state.horizontalAnchor {
        case .none:
            x = screenFrame.minX
        case .left:
            x = screenFrame.minX
        case .right:
            x = screenFrame.maxX - width
        }

        let y: CGFloat
        switch state.verticalAnchor {
        case .none:
            y = screenFrame.minY
        case .top:
            y = screenFrame.minY
        case .bottom:
            y = screenFrame.maxY - height
        }

        return CGRect(x: x, y: y, width: width, height: height)
    }

    /// Throws a window to the specified screen
    func throwWindow(_ window: AXWindow, toScreen screenNumber: Int) {
        
        // Get available screens (sorted consistently)
        let screens = AMScreen.availableScreens
        let screenIndex = screenNumber - 1  // Convert 1-based to 0-based index
        
        guard screenIndex >= 0 && screenIndex < screens.count else {
            log("Screen \(screenNumber) not available")

            return
        }
        
        let targetScreen = screens[screenIndex]
        
        // Find the current WindowSet containing this window
        if let (currentWindowSet, windowIndex, _) = findWindowSetContaining(window) {
            
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
        let newWindowSet = WindowSet(layout: defaultLayout, windows: [window], screenID: targetScreenID)
        
        log("📐 Created new WindowSet with screen ID: \(targetScreenID ?? "nil")")
        log("📐 Target screen frame: \(NSStringFromRect(targetScreen.adjustedFrame()))")
        
        // Add the new WindowSet to the target screen's workspace
        guard let delegate = delegate else { return }
        if let screenWSIndex = delegate.workspace.screens.firstIndex(where: { $0.screen == targetScreen }) {
            delegate.workspace.screens[screenWSIndex].windowSets.append(newWindowSet)
        } else {
            // Create new screen workspace if it doesn't exist
            let newScreenWS = ScreenWorkspace(screen: targetScreen, sets: [newWindowSet])
            delegate.workspace.screens.append(newScreenWS)
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
            let currentFrame = window.frame()
            let targetFrame = targetScreen.adjustedFrame()
            
            if !targetFrame.contains(currentFrame) || currentFrame.size != targetFrame.size {
                log("⚠️ Window not properly expanded, forcing manual expansion")
                log("📐 Current frame: \(NSStringFromRect(currentFrame))")
                log("📐 Target frame: \(NSStringFromRect(targetFrame))")
                
                // Force expand to full target screen
                move(window: window.axElementRef, to: targetFrame)
            }
        }
        
        // Confirmation notification removed
    }
    
    // MARK: - Private Helper Methods
    
    private func getDefaultLayoutMode() -> LayoutKind {
        return ConfigurationHelpers.getDefaultLayoutMode()
    }

    private func shouldAutoExpandNewWindows() -> Bool {
        return ConfigurationHelpers.shouldAutoExpandNewWindows()
    }
    
    private func showMainPanelSizeNotification(text: String) {
        // Notification removed
    }
    
    private func calculateTargetFrame(for position: String, on screenFrame: CGRect) -> CGRect {
        let halfWidth = screenFrame.width / 2
        let halfHeight = screenFrame.height / 2
        
        switch position {
        case "left":
            return CGRect(
                x: screenFrame.minX,
                y: screenFrame.minY,
                width: halfWidth,
                height: screenFrame.height
            )
        case "right":
            return CGRect(
                x: screenFrame.minX + halfWidth,
                y: screenFrame.minY,
                width: halfWidth,
                height: screenFrame.height
            )
        case "top":
            return CGRect(
                x: screenFrame.minX,
                y: screenFrame.minY,
                width: screenFrame.width,
                height: halfHeight
            )
        case "bottom":
            return CGRect(
                x: screenFrame.minX,
                y: screenFrame.minY + halfHeight,
                width: screenFrame.width,
                height: halfHeight
            )
        case "topLeft":
            return CGRect(
                x: screenFrame.minX,
                y: screenFrame.minY,
                width: halfWidth,
                height: halfHeight
            )
        case "topRight":
            return CGRect(
                x: screenFrame.minX + halfWidth,
                y: screenFrame.minY,
                width: halfWidth,
                height: halfHeight
            )
        case "bottomLeft":
            return CGRect(
                x: screenFrame.minX,
                y: screenFrame.minY + halfHeight,
                width: halfWidth,
                height: halfHeight
            )
        case "bottomRight":
            return CGRect(
                x: screenFrame.minX + halfWidth,
                y: screenFrame.minY + halfHeight,
                width: halfWidth,
                height: halfHeight
            )
        case "center":
            let centerWidth = screenFrame.width * 0.6  // 60% of screen width
            let centerHeight = screenFrame.height * 0.6  // 60% of screen height
            return CGRect(
                x: screenFrame.minX + (screenFrame.width - centerWidth) / 2,
                y: screenFrame.minY + (screenFrame.height - centerHeight) / 2,
                width: centerWidth,
                height: centerHeight
            )
        default:
            log("❌ Unknown position: \(position)")
            return screenFrame
        }
    }
    
    private func moveCursorToCenter(of window: AXWindow) {
        WorkspaceHelpers.moveCursorToCenter(of: window)
    }

    /// Finds the WindowSet containing the given window and returns the WindowSet, window index, and screen index
    private func findWindowSetContaining(_ window: AXWindow) -> (WindowSet, Int, Int)? {
        guard let delegate = delegate else { return nil }
        return WorkspaceHelpers.findWindowSetContaining(window, in: delegate.workspace)
    }
    
    /// Removes an empty WindowSet from the workspace
    private func removeEmptyWindowSet(_ windowSet: WindowSet) {
        guard let delegate = delegate else { return }
        
        for screenIndex in delegate.workspace.screens.indices {
            if let setIndex = delegate.workspace.screens[screenIndex].windowSets.firstIndex(where: { $0.id == windowSet.id }) {
                delegate.workspace.screens[screenIndex].windowSets.remove(at: setIndex)
                log("🧹 Removed empty WindowSet from screen \(screenIndex)")
                break
            }
        }
    }
    
    /// Removes a window from its original WindowSet and cleans up empty WindowSets
    private func removeWindowFromOriginalWindowSet(_ window: AXWindow, bundleID: String) {
        guard let delegate = delegate else { return }
        
        for screenIndex in delegate.workspace.screens.indices {
            for windowSetIndex in delegate.workspace.screens[screenIndex].windowSets.indices.reversed() {
                let windowSet = delegate.workspace.screens[screenIndex].windowSets[windowSetIndex]
                
                // Check if this WindowSet contains the window and belongs to the same app
                if let windowIndex = windowSet.windows.firstIndex(where: { $0.cgID() == window.cgID() }) {
                    // Remove the window from this WindowSet
                    windowSet.windows.remove(at: windowIndex)
                    log("🗑️ Removed window from original WindowSet")
                    
                    // If the WindowSet is now empty, remove it entirely
                    if windowSet.windows.isEmpty {
                        delegate.workspace.screens[screenIndex].windowSets.remove(at: windowSetIndex)
                        log("🧹 Removed empty WindowSet")
                    }
                    return
                }
            }
        }
    }
    
    /// Returns all WindowSets that contain at least one window belonging to the given bundle ID, sorted consistently.
    private func windowSets(for bundleID: String) -> [WindowSet] {
        guard let delegate = delegate else { return [] }
        
        var matchingSets: [WindowSet] = []
        var seenWindowIDs: Set<CGWindowID> = []

        for screenWS in delegate.workspace.screens {
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
}
