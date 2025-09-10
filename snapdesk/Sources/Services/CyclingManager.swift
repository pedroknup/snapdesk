//
//  CyclingManager.swift
//  snapdesk
//
//  Created by Pedro Knup on 05/09/2025.
//

import Foundation
import AppKit

protocol CyclingManagerDelegate: AnyObject {
    var workspace: WorkspaceModel { get }
}

class CyclingManager {
    
    private var currentBundleIDCycling: String?
    private var bundleIDCycleIndex: Int = 0
    private var windowIndexWithinSet: Int = 0
    private var currentWindowSet: WindowSet?
    
    // New state for tracking the current focus within the active WindowSet
    private var currentFocusedWindowSetID: UUID?
    private var currentWindowIndexInActiveSet: Int = 0
    
    // Custom cycling order for apps (independent of WindowSets)
    private var customWindowOrder: [String: [CGWindowID]] = [:]
    
    // Track current cycling index for each app using custom order
    private var appCyclingIndex: [String: Int] = [:]
    
    private weak var delegate: CyclingManagerDelegate?
    
    init(delegate: CyclingManagerDelegate) {
        self.delegate = delegate
    }
    
    // MARK: - Public Interface
    
    /// Updates the window order for cycling when a window is moved up or down
    /// - Parameters:
    ///   - bundleID: The bundle identifier of the app
    ///   - windowID: The window ID being moved
    ///   - direction: The direction to move (up = -1, down = +1)
    func moveWindowInCyclingOrder(for bundleID: String, windowID: CGWindowID, direction: Int) -> [CGWindowID]? {
        var windowOrder = getOrCreateWindowOrder(for: bundleID)
        
        guard windowOrder.count > 1 else {
            return windowOrder
        }
        
        guard let currentIndex = windowOrder.firstIndex(of: windowID) else {
            // Window not found, refresh order and retry
            guard let delegate = delegate else { return nil }
            
            let windowExists = delegate.workspace.screens.contains { screenWS in
                screenWS.windowSets.contains { windowSet in
                    windowSet.windows.contains { $0.cgID() == windowID }
                }
            }
            
            if !windowExists {
                customWindowOrder.removeValue(forKey: bundleID)
                return moveWindowInCyclingOrder(for: bundleID, windowID: windowID, direction: direction)
            }
            
            return nil
        }
        
        let newIndex = max(0, min(windowOrder.count - 1, currentIndex + direction))
        
        if newIndex == currentIndex {
            return windowOrder // Already at boundary
        }
        
        // Reorder
        windowOrder.remove(at: currentIndex)
        windowOrder.insert(windowID, at: newIndex)
        
        customWindowOrder[bundleID] = windowOrder
        appCyclingIndex[bundleID] = nil
        
        log("🔄 Reordered \(bundleID): \(windowOrder)")
        return windowOrder
    }
    
    /// Gets the custom window order for an app, or creates one from the workspace
    private func getOrCreateWindowOrder(for bundleID: String) -> [CGWindowID] {
        if let existingOrder = customWindowOrder[bundleID] {
            // Validate existing order against current workspace
            guard let delegate = delegate else { return existingOrder }
            
            var currentWindowIDs: Set<CGWindowID> = Set()
            for screenWS in delegate.workspace.screens {
                for windowSet in screenWS.windowSets {
                    for window in windowSet.windows {
                        if let app = NSRunningApplication(processIdentifier: window.pid()),
                           app.bundleIdentifier == bundleID {
                            currentWindowIDs.insert(window.cgID())
                        }
                    }
                }
            }
            
            let existingSet = Set(existingOrder)
            
            // Instead of completely recreating on any change, preserve existing order
            // and only add new windows or remove dead ones
            if existingSet != currentWindowIDs {
                var updatedOrder = existingOrder
                
                // Remove dead windows from the order
                updatedOrder.removeAll { windowID in
                    !currentWindowIDs.contains(windowID)
                }
                
                // Add new windows to the end of the order
                for windowID in currentWindowIDs {
                    if !existingSet.contains(windowID) {
                        updatedOrder.append(windowID)
                        log("➕ Added new window \(windowID) to custom order for \(bundleID)")
                    }
                }
                
                customWindowOrder[bundleID] = updatedOrder
                return updatedOrder
            }
            
            return existingOrder // Order is still valid
        }
        
        // Create new order from workspace
        guard let delegate = delegate else { return [] }
        var windowIDs: [CGWindowID] = []
        var seenIDs: Set<CGWindowID> = []
        
        for screenWorkspace in delegate.workspace.screens {
            for windowSet in screenWorkspace.windowSets {
                for window in windowSet.windows {
                    if let app = NSRunningApplication(processIdentifier: window.pid()),
                       app.bundleIdentifier == bundleID {
                        let windowID = window.cgID()
                        if !seenIDs.contains(windowID) {
                            seenIDs.insert(windowID)
                            windowIDs.append(windowID)
                        }
                    }
                }
            }
        }
        
        customWindowOrder[bundleID] = windowIDs
        return windowIDs
    }
    
    /// Gets the current cycling order for an app
    func getWindowCyclingOrder(for bundleID: String) -> [CGWindowID] {
        return getOrCreateWindowOrder(for: bundleID)
    }
    
    /// Returns the next WindowSet that should be focused for a given bundle ID and the target window within it
    func getNextWindowSetToFocus(for bundleID: String) -> (WindowSet, AXWindow?)? {
        guard let delegate = delegate else { return nil }
        let windowSets = windowSets(for: bundleID, in: delegate.workspace)
        guard !windowSets.isEmpty else { return nil }
        
        let customOrder = getWindowCyclingOrder(for: bundleID)
        guard !customOrder.isEmpty else { return nil }
        
        // Determine target window
        let targetWindowID: CGWindowID
        if currentBundleIDCycling != bundleID {
            // First time cycling this app
            appCyclingIndex[bundleID] = 0
            currentBundleIDCycling = bundleID
            targetWindowID = customOrder[0]
        } else {
            // Continue cycling
            let currentIndex = appCyclingIndex[bundleID] ?? 0
            let nextIndex = (currentIndex + 1) % customOrder.count
            appCyclingIndex[bundleID] = nextIndex
            targetWindowID = customOrder[nextIndex]
        }
        
        // Find WindowSet containing target window
        for screenWS in delegate.workspace.screens {
            for windowSet in screenWS.windowSets {
                if let window = windowSet.windows.first(where: { $0.cgID() == targetWindowID }) {
                    currentFocusedWindowSetID = windowSet.id
                    currentWindowSet = windowSet
                    return (windowSet, window)
                }
            }
        }
        
        return nil
    }
    
    /// Updates cycling state when focus changes externally (not via cycling)
    func updateCyclingStateFromFocus(window: AXWindow) {
        guard let delegate = delegate else { return }
        
        // Find WindowSet containing the focused window
        for screenWS in delegate.workspace.screens {
            for windowSet in screenWS.windowSets {
                if windowSet.windows.contains(where: { $0.cgID() == window.cgID() }) {
                    if currentWindowSet?.id != windowSet.id {
                        currentWindowSet = windowSet
                        currentFocusedWindowSetID = windowSet.id
                        
                        // Update cycling state for the app
                        if let app = NSRunningApplication(processIdentifier: window.pid()),
                           let bundleID = app.bundleIdentifier {
                            
                            if currentBundleIDCycling != bundleID {
                                currentBundleIDCycling = bundleID
                                bundleIDCycleIndex = 0
                            }
                            
                            // Update indices to match current focus
                            let windowSets = windowSets(for: bundleID, in: delegate.workspace)
                            if let setIndex = windowSets.firstIndex(where: { $0.id == windowSet.id }) {
                                bundleIDCycleIndex = setIndex
                                
                                let bundleWindowsInSet = windowSet.windows.filter { win in
                                    guard let app = NSRunningApplication(processIdentifier: win.pid()) else { return false }
                                    return app.bundleIdentifier == bundleID
                                }
                                
                                if let windowIndex = bundleWindowsInSet.firstIndex(where: { $0.cgID() == window.cgID() }) {
                                    currentWindowIndexInActiveSet = windowIndex
                                    windowIndexWithinSet = windowIndex
                                } else {
                                    currentWindowIndexInActiveSet = 0
                                    windowIndexWithinSet = 0
                                }
                            }
                        }
                    }
                    return
                }
            }
        }
    }
    
    /// Resets cycling state for the given bundle ID
    func resetCycling(for bundleID: String? = nil) {
        if let bundleID = bundleID {
            // Only reset if it matches the current cycling bundle
            if bundleID == currentBundleIDCycling {
                resetAllCyclingState()
            }
            // Also reset the specific app's cycling index
            appCyclingIndex[bundleID] = nil
        } else {
            // Reset all cycling state
            resetAllCyclingState()
        }
    }
    
    /// Gets the current window set if available
    var getCurrentWindowSet: WindowSet? {
        return currentWindowSet
    }
    
    // MARK: - Private Methods
    
    private func resetAllCyclingState() {
        currentBundleIDCycling = nil
        bundleIDCycleIndex = 0
        windowIndexWithinSet = 0
        currentWindowSet = nil
        currentFocusedWindowSetID = nil
        currentWindowIndexInActiveSet = 0
        appCyclingIndex.removeAll()
    }
    
    /// Returns all WindowSets that contain at least one window belonging to the given bundle ID, sorted consistently.
    private func windowSets(for bundleID: String, in workspace: WorkspaceModel) -> [WindowSet] {
        var matchingSets: [WindowSet] = []
        var seenWindowIDs: Set<CGWindowID> = []

        for (screenIndex, screenWS) in workspace.screens.enumerated() {
            for (setIndex, set) in screenWS.windowSets.enumerated() {
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
