//
//  ScreenConfigurationHandler.swift
//  snapdesk
//
//  Created by Pedro Knup on 21/11/2025.
//

import Foundation
import Cocoa

protocol WorkspaceProvider: AnyObject {
    var workspace: WorkspaceModel { get set }
}

class ScreenConfigurationHandler {
    private weak var workspaceProvider: WorkspaceProvider?

    init(workspaceProvider: WorkspaceProvider) {
        self.workspaceProvider = workspaceProvider
    }

    func handleScreenParametersChange() {
        guard let provider = workspaceProvider else { return }
        var workspace = provider.workspace
        log("🖥️ Screen configuration changed, remapping windows...")

        // Store current window sets before updating screens
        var orphanedWindowSets: [WindowSet] = []
        let previousScreenIDs = Set(workspace.screens.compactMap { $0.screen.screenID() })

        // Get the new screens
        let newScreens = AMScreen.availableScreens
        let newScreenIDs = Set(newScreens.compactMap { $0.screenID() })

        // Log detailed screen information for debugging
        log("📊 Previous screen IDs: \(previousScreenIDs)")
        log("📊 New screen IDs: \(newScreenIDs)")
        log("📊 Previous screens count: \(workspace.screens.count), New screens count: \(newScreens.count)")

        // Log current screen details with stable IDs
        log("📺 PREVIOUS SCREENS:")
        for (index, screenWS) in workspace.screens.enumerated() {
            let frame = screenWS.screen.frame()
            let windowSetsCount = screenWS.windowSets.count
            let totalWindows = screenWS.windowSets.flatMap { $0.windows }.count
            let stableID = screenWS.screen.stableScreenID()
            log("   Screen \(index): ID=\(screenWS.screen.screenID() ?? "nil"), stable=\(stableID), frame=\(NSStringFromRect(frame)), \(windowSetsCount) sets, \(totalWindows) windows")
        }

        log("📺 NEW SCREENS:")
        for (index, screen) in newScreens.enumerated() {
            let frame = screen.frame()
            let stableID = screen.stableScreenID()
            log("   Screen \(index): ID=\(screen.screenID() ?? "nil"), stable=\(stableID), frame=\(NSStringFromRect(frame))")
        }

        // Find removed screen IDs
        let removedScreenIDs = previousScreenIDs.subtracting(newScreenIDs)
        let addedScreenIDs = newScreenIDs.subtracting(previousScreenIDs)

        if !removedScreenIDs.isEmpty {
            log("📤 Screens removed: \(removedScreenIDs)")

            // Collect all window sets from removed screens
            for screenWS in workspace.screens {
                if let screenID = screenWS.screen.screenID(), removedScreenIDs.contains(screenID) {
                    log("🔄 Collecting \(screenWS.windowSets.count) window sets from removed screen \(screenID)")
                    orphanedWindowSets.append(contentsOf: screenWS.windowSets)
                }
            }
        }

        if !addedScreenIDs.isEmpty {
            log("📥 Screens added: \(addedScreenIDs)")
        }

        // More sophisticated screen matching using frame information
        var actuallyRemovedScreens: [ScreenWorkspace] = []
        var screenMappings: [(ScreenWorkspace, AMScreen)] = []

        for oldScreenWS in workspace.screens {
            let oldFrame = oldScreenWS.screen.frame()

            // Try to find a new screen with the same frame (or very similar)
            if let matchingNewScreen = newScreens.first(where: { newScreen in
                let newFrame = newScreen.frame()
                return abs(oldFrame.origin.x - newFrame.origin.x) < 10 &&
                       abs(oldFrame.origin.y - newFrame.origin.y) < 10 &&
                       abs(oldFrame.width - newFrame.width) < 10 &&
                       abs(oldFrame.height - newFrame.height) < 10
            }) {
                // Found a matching screen by frame - this is likely the same physical screen
                screenMappings.append((oldScreenWS, matchingNewScreen))
                if oldScreenWS.screen.screenID() != matchingNewScreen.screenID() {
                    log("🔄 Screen ID changed but frame matched: \(oldScreenWS.screen.screenID() ?? "nil") -> \(matchingNewScreen.screenID() ?? "nil")")
                }
            } else {
                // No matching frame found - this screen was actually removed
                actuallyRemovedScreens.append(oldScreenWS)
                log("❌ Screen actually removed: \(oldScreenWS.screen.screenID() ?? "nil"), frame=\(NSStringFromRect(oldFrame))")
            }
        }

        // If we only have screen ID changes but frames match, this is likely just external monitor ID changes
        if actuallyRemovedScreens.isEmpty && !screenMappings.isEmpty {
            log("🔄 Detected screen ID changes but no physical screen changes - updating IDs only")

            // Update screen references without repositioning windows
            workspace.refreshScreens()

            // Update WindowSet screen IDs to match new screen IDs without moving windows
            for (oldScreenWS, newScreen) in screenMappings {
                if let newScreenIndex = workspace.screens.firstIndex(where: { $0.screen.screenID() == newScreen.screenID() }) {
                    // Update WindowSet screen IDs
                    for windowSet in oldScreenWS.windowSets {
                        windowSet.screenID = newScreen.screenID()
                    }

                    // Transfer window sets to the new screen workspace
                    workspace.screens[newScreenIndex].windowSets = oldScreenWS.windowSets
                }
            }

            log("✅ Updated screen IDs without repositioning windows")
            // WorkspaceModel is a struct: without this write-back every change
            // above (refreshed screens, transferred window sets) is discarded
            // and the live workspace keeps stale NSScreen references forever.
            provider.workspace = workspace
            return
        }

        // Check if this is just a spurious screen change event (no actual changes).
        // Also compare screen counts: screenID() is derived from the screen's frame,
        // so when a display detaches its stale frame resolves to the remaining
        // display's ID and the ID sets collide, masking a real change.
        if removedScreenIDs.isEmpty && addedScreenIDs.isEmpty && previousScreenIDs == newScreenIDs
            && workspace.screens.count == newScreens.count {
            log("⚠️ Screen parameters changed but no actual screen changes detected - skipping remapping")
            return
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

                            let windowFrame = window.frame()
                            log("✅ Remapped window '\(window.title() ?? "<untitled>")' from orphaned set to screen \(currentScreen.screenID() ?? "unknown"), frame=\(NSStringFromRect(windowFrame))")

                            // Expand the window if auto-expand is enabled
                            if ConfigurationHelpers.shouldAutoExpandNewWindows() {
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
                if ConfigurationHelpers.shouldAutoExpandNewWindows() {
                    windowSet.expandWindows(on: screenWS.screen, bringToFront: false)
                }
            }
        }

        log("✅ Screen remapping complete")

        // Write back the modified workspace
        provider.workspace = workspace
    }
}
