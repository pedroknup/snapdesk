//
//  ScreenNavigationService.swift
//  snapdesk
//
//  Created by Pedro Knup on 21/11/2025.
//

import Foundation
import AppKit

class ScreenNavigationService {
    private weak var workspaceProvider: WorkspaceProvider?
    private let layoutManager: LayoutManager
    private var lastFocusedWindowPerScreen: [String: AXWindow]

    init(workspaceProvider: WorkspaceProvider, layoutManager: LayoutManager, lastFocusedWindowPerScreen: [String: AXWindow]) {
        self.workspaceProvider = workspaceProvider
        self.layoutManager = layoutManager
        self.lastFocusedWindowPerScreen = lastFocusedWindowPerScreen
    }

    // MARK: - Public API

    func toggleFullScreen() {
        log("🖥 toggleFullScreen() called")
        // TODO: Implement full screen toggle functionality
    }

    func focusScreen(_ screenNumber: Int, onTrackFocus: @escaping (AXWindow) -> Void) {
        log("🎯 focusScreen(\(screenNumber)) called")

        let screenIndex = screenNumber - 1
        let screens = AMScreen.availableScreens

        guard screenIndex < screens.count else {
            log("❌ Screen \(screenNumber) does not exist (only \(screens.count) screens available)")
            return
        }

        let targetScreen = screens[screenIndex]
        let targetScreenFrame = targetScreen.frame()

        guard let targetScreenID = targetScreen.screenID() else {
            log("❌ Could not get screen ID for screen \(screenNumber)")
            return
        }

        if let lastWindow = lastFocusedWindowPerScreen[targetScreenID] {
            let windowFrame = lastWindow.frame()
            if targetScreenFrame.intersects(windowFrame) {
                lastWindow.focus()
                lastWindow.raise()
                WorkspaceHelpers.moveCursorToCenter(of: lastWindow)
                onTrackFocus(lastWindow)
                log("✅ Restored last focused window '\(lastWindow.title() ?? "untitled")' on screen \(screenNumber)")
                return
            } else {
                lastFocusedWindowPerScreen.removeValue(forKey: targetScreenID)
            }
        }

        guard let workspace = workspaceProvider?.workspace else { return }

        if let screenWorkspace = workspace.screens.first(where: { $0.screen.screenID() == targetScreenID }) {
            var windowsOnScreen: [AXWindow] = []
            for windowSet in screenWorkspace.windowSets {
                windowsOnScreen.append(contentsOf: windowSet.windows)
            }

            if let firstWindow = windowsOnScreen.first {
                firstWindow.focus()
                firstWindow.raise()
                WorkspaceHelpers.moveCursorToCenter(of: firstWindow)
                onTrackFocus(firstWindow)
                log("✅ Focused window '\(firstWindow.title() ?? "untitled")' on screen \(screenNumber)")
                return
            }
        }

        log("⚠️ No manageable windows found on screen \(screenNumber)")
    }

    func throwToScreen(_ screenNumber: Int, onTrackFocus: @escaping (AXWindow) -> Void) {
        guard let focusedWindow = frontmostWindow() else {
            log("❌ No focused window found")
            return
        }

        let axWindow = AXWindow(axElement: focusedWindow)
        layoutManager.throwWindow(axWindow, toScreen: screenNumber)

        axWindow.raise()
        axWindow.focus()
        onTrackFocus(axWindow)
        WorkspaceHelpers.moveCursorToCenter(of: axWindow)
    }

    func focusScreenAt(index: Int, screenList: [NSScreen], windowOnScreen: (NSScreen) -> AXUIElement?) {
        guard index < screenList.count else { return }
        let targetScreen = screenList[index]

        if let window = windowOnScreen(targetScreen) {
            AXUIElementSetAttributeValue(window, kAXFocusedAttribute as CFString, kCFBooleanTrue)
        }
    }

    func throwFrontmostWindow(toScreen index: Int, onTrackFocus: @escaping (AXWindow) -> Void) {
        log("📤 throwFrontmostWindow(toScreen: \(index)) called")
        throwToScreen(index + 1, onTrackFocus: onTrackFocus)
    }

    func getLastFocusedWindowPerScreen() -> [String: AXWindow] {
        return lastFocusedWindowPerScreen
    }
}
