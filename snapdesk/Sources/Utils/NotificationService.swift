//
//  NotificationService.swift
//  snapdesk
//

import Cocoa

enum FloatingPosition {
    case center
    case topLeft
    case topRight
    case bottomLeft
    case bottomRight
}

class NotificationService {
    private static var state: NotificationState { NotificationState.shared }

    static func showFloatingWindow(text: String, position: FloatingPosition = .center, duration: TimeInterval = 2.0, fontSize: CGFloat = 16) {
        showFloatingWindow(attributedText: NSAttributedString(string: text), position: position, duration: duration, fontSize: fontSize)
    }

    static func showFloatingWindow(attributedText: NSAttributedString, position: FloatingPosition = .center, duration: TimeInterval = 2.0, fontSize: CGFloat = 16) {
        showFloatingWindow(attributedText: attributedText, images: [], position: position, duration: duration, fontSize: fontSize)
    }

    static func showFloatingWindow(attributedText: NSAttributedString, images: [(NSImage, String)] = [], position: FloatingPosition = .center, duration: TimeInterval = 2.0, fontSize: CGFloat = 16) {
        let settingsDuration = UserDefaults.standard.object(forKey: "notificationDuration") as? Double ?? duration
        let settingsPosition = UserDefaults.standard.string(forKey: "notificationPosition") ?? "center"

        let actualPosition: FloatingPosition
        switch settingsPosition {
        case "topLeft": actualPosition = .topLeft
        case "topRight": actualPosition = .topRight
        case "bottomLeft": actualPosition = .bottomLeft
        case "bottomRight": actualPosition = .bottomRight
        default: actualPosition = .center
        }

        if let activePopup = state.activePopupWindow, activePopup.isVisible {
            reuseActivePopup(window: activePopup, attributedText: attributedText, images: images, position: actualPosition, fontSize: fontSize, duration: settingsDuration)
        } else {
            let window = NotificationWindowFactory.createWindow(attributedText: attributedText, images: images, position: actualPosition, fontSize: fontSize)
            state.addActiveWindow(window)
            state.setActivePopupWindow(window)

            window.level = NSWindow.Level(rawValue: Int(CGWindowLevelForKey(.floatingWindow)))
            window.makeKeyAndOrderFront(nil)

            schedulePopupClose(window: window, duration: settingsDuration)
        }
    }

    static func showAllLayoutsGrid(currentLayout: LayoutKind, position: FloatingPosition = .center, duration: TimeInterval = 1.5) {
        let layouts: [LayoutKind] = [.tall, .wide, .vertical_stack, .horizontal_stack, .fullscreen, .floating]
        let layoutNames = ["Tall", "Wide", "V.Stack", "H.Stack", "Full", "Float"]

        if let activePopup = state.activePopupWindow, activePopup.isVisible {
            reuseActivePopupForLayoutGrid(window: activePopup, layouts: layouts, layoutNames: layoutNames, currentLayout: currentLayout, position: position, duration: duration)
        } else {
            let window = LayoutSelectorView.createLayoutGridWindow(layouts: layouts, layoutNames: layoutNames, currentLayout: currentLayout, position: position)
            state.addActiveWindow(window)
            state.setActivePopupWindow(window)

            window.level = NSWindow.Level(rawValue: Int(CGWindowLevelForKey(.floatingWindow)))
            window.makeKeyAndOrderFront(nil)

            schedulePopupClose(window: window, duration: duration)
        }
    }

    static func hideAllFloatingWindows() {
        for window in state.activeWindows {
            hideWindow(window)
        }
    }

    static func showMultipleDemo() {
        showFloatingWindow(text: "First Window", position: .center, duration: 4.0)

        DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
            showFloatingWindow(text: "Second Window", position: .topRight, duration: 3.5)
        }

        DispatchQueue.main.asyncAfter(deadline: .now() + 1.0) {
            showFloatingWindow(text: "Third Window", position: .bottomLeft, duration: 3.0)
        }
    }

    private static func reuseActivePopup(window: NSWindow, attributedText: NSAttributedString, images: [(NSImage, String)], position: FloatingPosition, fontSize: CGFloat, duration: TimeInterval) {
        state.invalidateTimer()
        window.alphaValue = 1.0
        NotificationWindowFactory.updateWindowContent(window: window, attributedText: attributedText, images: images, position: position, fontSize: fontSize)
        schedulePopupClose(window: window, duration: duration)
    }

    private static func reuseActivePopupForLayoutGrid(window: NSWindow, layouts: [LayoutKind], layoutNames: [String], currentLayout: LayoutKind, position: FloatingPosition, duration: TimeInterval) {
        state.invalidateTimer()
        window.alphaValue = 1.0
        LayoutSelectorView.updateLayoutGridContent(window: window, layouts: layouts, layoutNames: layoutNames, currentLayout: currentLayout, position: position)
        schedulePopupClose(window: window, duration: duration)
    }

    private static func schedulePopupClose(window: NSWindow, duration: TimeInterval) {
        state.invalidateTimer()
        let timer = Timer.scheduledTimer(withTimeInterval: duration, repeats: false) { _ in
            closePopup(window)
        }
        state.setPopupTimer(timer)
    }

    private static func closePopup(_ window: NSWindow) {
        state.invalidateTimer()

        if state.activePopupWindow == window {
            state.clearActivePopupWindow()
        }

        hideWindow(window)
    }

    private static func hideWindow(_ window: NSWindow) {
        NSAnimationContext.runAnimationGroup({ context in
            context.duration = 0.3
            window.animator().alphaValue = 0.0
        }, completionHandler: {
            window.orderOut(nil)
            state.removeActiveWindow(window)
        })
    }
}
