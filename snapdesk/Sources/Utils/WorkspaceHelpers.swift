//
//  WorkspaceHelpers.swift
//  snapdesk
//
//  Created by Pedro Knup on 21/11/2025.
//

import Foundation
import Cocoa

enum WorkspaceHelpers {
    /// Moves the mouse cursor to the center of the given window
    static func moveCursorToCenter(of window: AXWindow) {
        let windowFrame = window.frame()
        let centerPoint = NSPoint(
            x: windowFrame.midX,
            y: windowFrame.midY
        )

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
    static func findWindowSetContaining(_ window: AXWindow, in workspace: WorkspaceModel) -> (WindowSet, Int, Int)? {
        for (screenIndex, screenWS) in workspace.screens.enumerated() {
            for windowSet in screenWS.windowSets {
                if let windowIndex = windowSet.windows.firstIndex(where: { $0.cgID() == window.cgID() }) {
                    return (windowSet, windowIndex, screenIndex)
                }
            }
        }
        return nil
    }
}
