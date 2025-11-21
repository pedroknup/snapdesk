//
//  WindowRefreshService.swift
//  snapdesk
//
//  Created by Pedro Knup on 22/11/2025.
//

import Foundation
import AppKit

class WindowRefreshService {
    private weak var workspaceProvider: WorkspaceProvider?

    init(workspaceProvider: WorkspaceProvider) {
        self.workspaceProvider = workspaceProvider
    }

    // MARK: - Public API

    func refreshWindows(onVisualize: @escaping () -> Void) {
        log("🔄 Refreshing windows...")

        guard var workspace = workspaceProvider?.workspace else { return }

        let discovered = scanWindows()
        let discoveredWindowIDs = Set(discovered.map { $0.window.cgID() })
        var processedWindowIDs: Set<CGWindowID> = Set()

        // First pass: Remove dead windows from existing WindowSets
        for screenIndex in workspace.screens.indices {
            for setIndex in workspace.screens[screenIndex].windowSets.indices.reversed() {
                let windowSet = workspace.screens[screenIndex].windowSets[setIndex]

                windowSet.windows.removeAll { window in
                    let windowID = window.cgID()
                    let stillExists = discoveredWindowIDs.contains(windowID)
                    if !stillExists {
                        log("🗑️ Removing dead window \(windowID) from WindowSet")
                    }
                    return !stillExists
                }

                if windowSet.windows.isEmpty {
                    log("🧹 Removing empty WindowSet")
                    workspace.screens[screenIndex].windowSets.remove(at: setIndex)
                }
            }
        }

        // Second pass: Add new windows while preserving existing WindowSet structure
        for (window, screen) in discovered {
            let windowID = window.cgID()

            var foundInExistingSet = false
            for screenWS in workspace.screens {
                for windowSet in screenWS.windowSets {
                    if windowSet.windows.contains(where: { $0.cgID() == windowID }) {
                        foundInExistingSet = true
                        break
                    }
                }
                if foundInExistingSet { break }
            }

            if !foundInExistingSet {
                log("➕ Adding new window \(windowID) to workspace")
                if let screenIndex = workspace.screens.firstIndex(where: { $0.screen == screen }) {
                    addWindow(window, to: &workspace.screens[screenIndex], onVisualize: onVisualize)
                }
            }

            processedWindowIDs.insert(windowID)
        }

        workspaceProvider?.workspace = workspace
        log("✅ Window refresh complete. Processed \(processedWindowIDs.count) windows, preserving existing order")
    }

    // MARK: - Private Implementation

    private func addWindow(_ window: AXWindow, to screenWS: inout ScreenWorkspace, onVisualize: @escaping () -> Void) {
        let defaultLayout = ConfigurationHelpers.getDefaultLayoutMode()
        let newSet = WindowSet(layout: defaultLayout, windows: [window], screenID: screenWS.screen.screenID())
        screenWS.windowSets.append(newSet)

        if ConfigurationHelpers.shouldAutoExpandNewWindows() {
            newSet.expandWindows(on: screenWS.screen, bringToFront: false)
        }

        onVisualize()
    }
}
