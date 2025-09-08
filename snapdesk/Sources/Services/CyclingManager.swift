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
        log("📝 Moving window \(windowID) in cycling order for \(bundleID) (direction: \(direction))")
        log("📝 Current customWindowOrder state: \(customWindowOrder)")
        
        // Get current window order or create it from workspace
        var windowOrder = getOrCreateWindowOrder(for: bundleID)
        log("📝 Initial window order: \(windowOrder)")
        
        guard windowOrder.count > 1 else {
            log("📝 Only \(windowOrder.count) window(s) for \(bundleID), no reordering possible")
            return windowOrder
        }
        
        guard let currentIndex = windowOrder.firstIndex(of: windowID) else {
            log("❌ Window \(windowID) not found in cycling order")
            log("📝 Searching for window \(windowID) in workspace...")
            
            // Debug: Check if window still exists in workspace
            guard let delegate = delegate else { 
                log("❌ No delegate available")
                return nil 
            }
            
            var foundWindow = false
            for screenWS in delegate.workspace.screens {
                for windowSet in screenWS.windowSets {
                    for window in windowSet.windows {
                        if window.cgID() == windowID {
                            foundWindow = true
                            log("✅ Found window \(windowID) in workspace")
                            break
                        }
                    }
                    if foundWindow { break }
                }
                if foundWindow { break }
            }
            
            if !foundWindow {
                log("❌ Window \(windowID) no longer exists in workspace")
                // Refresh the window order and try again
                customWindowOrder.removeValue(forKey: bundleID)
                windowOrder = getOrCreateWindowOrder(for: bundleID)
                log("📝 Refreshed window order: \(windowOrder)")
                
                guard let newCurrentIndex = windowOrder.firstIndex(of: windowID) else {
                    log("❌ Window \(windowID) still not found after refresh")
                    return nil
                }
                
                return moveWindowInCyclingOrder(for: bundleID, windowID: windowID, direction: direction)
            }
            
            return nil
        }
        
        let newIndex = max(0, min(windowOrder.count - 1, currentIndex + direction))
        log("📝 Current index: \(currentIndex), direction: \(direction), newIndex: \(newIndex), total windows: \(windowOrder.count)")
        
        if newIndex == currentIndex {
            log("📝 Window already at boundary (index \(currentIndex) of \(windowOrder.count)), no change needed")
            return windowOrder
        }
        
        // Move the window to the new position
        windowOrder.remove(at: currentIndex)
        windowOrder.insert(windowID, at: newIndex)
        
        // Save the new order
        customWindowOrder[bundleID] = windowOrder
        log("📝 Updated cycling order for \(bundleID): \(windowOrder)")
        log("📝 Updated customWindowOrder state: \(customWindowOrder)")
        
        // Reset the app's cycling index so it recalculates position
        appCyclingIndex[bundleID] = nil
        log("📝 Reset cycling index for \(bundleID)")
        
        return windowOrder
    }
    
    /// Gets the custom window order for an app, or creates one from the workspace
    private func getOrCreateWindowOrder(for bundleID: String) -> [CGWindowID] {
        log("📝 getOrCreateWindowOrder called for \(bundleID)")
        
        if let existingOrder = customWindowOrder[bundleID] {
            log("📝 Found existing order for \(bundleID): \(existingOrder)")
            
            // Verify that all windows in the existing order still exist
            guard let delegate = delegate else { 
                log("❌ No delegate, returning existing order")
                return existingOrder 
            }
            
            var currentWindowIDs: Set<CGWindowID> = []
            for screenWorkspace in delegate.workspace.screens {
                for windowSet in screenWorkspace.windowSets {
                    for window in windowSet.windows {
                        if let app = NSRunningApplication(processIdentifier: window.pid()),
                           app.bundleIdentifier == bundleID {
                            currentWindowIDs.insert(window.cgID())
                        }
                    }
                }
            }
            
            let existingSet = Set(existingOrder)
            let stillExist = existingSet.intersection(currentWindowIDs)
            let noLongerExist = existingSet.subtracting(currentWindowIDs)
            let newWindows = currentWindowIDs.subtracting(existingSet)
            
            log("📝 Window validation for \(bundleID):")
            log("📝   Still exist: \(stillExist)")
            log("📝   No longer exist: \(noLongerExist)")  
            log("📝   New windows: \(newWindows)")
            
            if noLongerExist.isEmpty && newWindows.isEmpty {
                log("📝 All windows still valid, returning existing order")
                return existingOrder
            } else {
                log("📝 Window set changed, recreating order")
                customWindowOrder.removeValue(forKey: bundleID)
                // Fall through to create new order
            }
        }
        
        // Create order from workspace
        guard let delegate = delegate else { 
            log("❌ No delegate available for creating order")
            return [] 
        }
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
        log("📝 Created initial cycling order for \(bundleID): \(windowIDs)")
        return windowIDs
    }
    
    /// Gets the current cycling order for an app
    func getWindowCyclingOrder(for bundleID: String) -> [CGWindowID] {
        return getOrCreateWindowOrder(for: bundleID)
    }
    
    /// Returns the next WindowSet that should be focused for a given bundle ID and the target window within it
    /// Uses the custom cycling order if available, falls back to WindowSet order
    /// - Parameter bundleID: The bundle identifier of the app
    /// - Returns: A tuple containing the WindowSet to focus and the target window, or nil if no windows exist
    func getNextWindowSetToFocus(for bundleID: String) -> (WindowSet, AXWindow?)? {
        guard let delegate = delegate else { return nil }
        let windowSets = windowSets(for: bundleID, in: delegate.workspace)
        
        guard !windowSets.isEmpty else {
            log("❌ No WindowSets found for bundle ID: \(bundleID)")
            return nil
        }
        
        // Get the custom cycling order for this app
        let customOrder = getWindowCyclingOrder(for: bundleID)
        log("🔄 Custom cycling order for \(bundleID): \(customOrder)")
        
        guard !customOrder.isEmpty else {
            log("❌ No windows in custom order for \(bundleID)")
            return nil
        }
        
        // Determine next window using simple cycling index
        var targetWindowID: CGWindowID?
        
        if currentBundleIDCycling != bundleID {
            // First time cycling this app, start with first window
            log("📝 First time cycling \(bundleID), starting with index 0")
            appCyclingIndex[bundleID] = 0
            currentBundleIDCycling = bundleID
            targetWindowID = customOrder[0]
        } else {
            // Continue cycling - move to next window in custom order
            let currentIndex = appCyclingIndex[bundleID] ?? 0
            let nextIndex = (currentIndex + 1) % customOrder.count
            appCyclingIndex[bundleID] = nextIndex
            targetWindowID = customOrder[nextIndex]
            log("📝 Cycling \(bundleID): moving from index \(currentIndex) to \(nextIndex), target window: \(targetWindowID!)")
        }
        
        guard let finalTargetWindowID = targetWindowID else {
            log("❌ No target window ID determined")
            return nil
        }
        
        // Find the WindowSet and AXWindow for the target window ID
        for screenWS in delegate.workspace.screens {
            for windowSet in screenWS.windowSets {
                for window in windowSet.windows {
                    if window.cgID() == finalTargetWindowID {
                        log("✅ Found target window \(finalTargetWindowID) in WindowSet \(windowSet.id)")
                        
                        // Update tracking state
                        currentFocusedWindowSetID = windowSet.id
                        currentWindowSet = windowSet
                        
                        return (windowSet, window)
                    }
                }
            }
        }
        
        log("❌ Target window \(finalTargetWindowID) not found in any WindowSet")
        return nil
    }
    
    /// Updates cycling state when focus changes externally (not via cycling)
    func updateCyclingStateFromFocus(window: AXWindow) {
        guard let delegate = delegate else { return }
        let workspace = delegate.workspace
        
        // Find which WindowSet contains this focused window
        for screenWS in workspace.screens {
            for windowSet in screenWS.windowSets {
                if windowSet.windows.contains(where: { $0.cgID() == window.cgID() }) {
                                
                    // Update currentWindowSet if it's different
                    if currentWindowSet?.id != windowSet.id {
                        currentWindowSet = windowSet
                        
                        // Update cycling state for the focused window's app
                        if let app = NSRunningApplication(processIdentifier: window.pid()),
                           let bundleID = app.bundleIdentifier {
                            
                            // If we switched to a different app, reset cycling
                            if currentBundleIDCycling != bundleID {
                                currentBundleIDCycling = bundleID
                                bundleIDCycleIndex = 0
                            }
                            
                            // Update the cycle index to match the focused WindowSet
                            let windowSets = windowSets(for: bundleID, in: workspace)
                            if let setIndex = windowSets.firstIndex(where: { $0.id == windowSet.id }) {
                                bundleIDCycleIndex = setIndex
                                
                                // Find the window index within the bundle's windows in this WindowSet
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