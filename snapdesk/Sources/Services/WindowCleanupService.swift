//
//  WindowCleanupService.swift
//  snapdesk
//
//  Created by Pedro Knup on 21/11/2025.
//

import Foundation
import AppKit

class WindowCleanupService {
    private weak var workspaceProvider: WorkspaceProvider?
    private let cyclingManager: CyclingManager

    init(workspaceProvider: WorkspaceProvider, cyclingManager: CyclingManager) {
        self.workspaceProvider = workspaceProvider
        self.cyclingManager = cyclingManager
    }

    // MARK: - Public API

    func removeDeadWindow(_ deadWindow: AXWindow, from windowSet: WindowSet, bundleID: String, onVisualize: @escaping () -> Void) {
        log("🗑️ Removing dead window '\(deadWindow.title() ?? "untitled")' from WindowSet")

        if let windowIndex = windowSet.windows.firstIndex(where: { $0.cgID() == deadWindow.cgID() }) {
            windowSet.windows.remove(at: windowIndex)
            log("✅ Removed dead window from WindowSet. WindowSet now has \(windowSet.windows.count) windows")

            if windowSet.windows.isEmpty {
                removeEmptyWindowSet(windowSet)
            }

            onVisualize()
        } else {
            log("⚠️ Dead window not found in expected WindowSet")
        }
    }

    func focusNextAvailableWindow(for bundleID: String, excluding excludedWindow: AXWindow, onTrackFocus: @escaping (AXWindow) -> Void) async {
        log("🔄 Looking for next available window for bundle: \(bundleID)")

        guard let (nextWindowSet, nextTargetWindow) = cyclingManager.getNextWindowSetToFocus(for: bundleID) else {
            log("❌ No more windows available for bundle: \(bundleID)")
            return
        }

        if let nextWindow = nextTargetWindow, nextWindow.cgID() == excludedWindow.cgID() {
            log("⚠️ Next window is the same as excluded window, skipping")
            return
        }

        if ConfigurationHelpers.shouldAutoExpandNewWindows() {
            nextWindowSet.expandWindows()
        }

        await nextWindowSet.raiseAllWindows(excluding: nextTargetWindow)

        if let nextWindow = nextTargetWindow {
            log("🎯 Attempting to focus next window: '\(nextWindow.title() ?? "untitled")'")
            nextWindow.raise()
            let focusSucceeded = nextWindow.focus()

            if focusSucceeded {
                onTrackFocus(nextWindow)
                log("✅ Successfully focused next window")
                WorkspaceHelpers.moveCursorToCenter(of: nextWindow)
            } else {
                log("❌ Failed to focus next window - it may also be dead")
            }
        }
    }

    // MARK: - Private Implementation

    private func removeEmptyWindowSet(_ windowSet: WindowSet) {
        guard var workspace = workspaceProvider?.workspace else { return }

        for screenIndex in workspace.screens.indices {
            if let setIndex = workspace.screens[screenIndex].windowSets.firstIndex(where: { $0.id == windowSet.id }) {
                workspace.screens[screenIndex].windowSets.remove(at: setIndex)
                log("🧹 Removed empty WindowSet from screen \(screenIndex)")
                workspaceProvider?.workspace = workspace
                break
            }
        }
    }
}
