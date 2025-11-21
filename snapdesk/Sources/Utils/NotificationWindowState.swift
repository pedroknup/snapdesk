//
//  NotificationWindowState.swift
//  snapdesk
//
//  Created by Pedro Knup on 21/11/2025.
//

import Cocoa

class NotificationWindowState {
    static let shared = NotificationWindowState()

    private(set) var activeWindows: [NSWindow] = []
    private(set) var activePopupWindow: NSWindow?
    private(set) var popupTimer: Timer?

    private init() {}

    func addActiveWindow(_ window: NSWindow) {
        activeWindows.append(window)
    }

    func setActivePopupWindow(_ window: NSWindow?) {
        activePopupWindow = window
    }

    func setPopupTimer(_ timer: Timer?) {
        popupTimer?.invalidate()
        popupTimer = timer
    }

    func clearActivePopupWindow() {
        activePopupWindow = nil
    }

    func removeActiveWindow(_ window: NSWindow) {
        activeWindows.removeAll { $0 == window }
    }

    func invalidateTimer() {
        popupTimer?.invalidate()
        popupTimer = nil
    }
}
