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
    
    private weak var delegate: CyclingManagerDelegate?
    
    init(delegate: CyclingManagerDelegate) {
        self.delegate = delegate
    }
    
    // MARK: - Public Interface
    
    /// Returns the next WindowSet that should be focused for a given bundle ID and the target window within it
    /// - Parameter bundleID: The bundle identifier of the app
    /// - Returns: A tuple containing the WindowSet to focus and the target window, or nil if no windows exist
    func getNextWindowSetToFocus(for bundleID: String) -> (WindowSet, AXWindow?)? {
        guard let delegate = delegate else { return nil }
        let windowSets = windowSets(for: bundleID, in: delegate.workspace)
        
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
    }
    
    /// Returns all WindowSets that contain at least one window belonging to the given bundle ID, sorted consistently.
    private func windowSets(for bundleID: String, in workspace: WorkspaceModel) -> [WindowSet] {
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
}