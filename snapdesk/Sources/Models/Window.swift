//
//  Window.swift
//  Amethyst
//
//  Created by Ian Ynda-Hummel on 3/10/19.
//  Copyright © 2019 Ian Ynda-Hummel. All rights reserved.
//

import Foundation
import Silica

// swiftlint:disable identifier_name
 @_silgen_name("GetProcessForPID") @discardableResult
 func GetProcessForPID(_ pid: pid_t, _ psn: inout ProcessSerialNumber) -> OSStatus

 @_silgen_name("_SLPSSetFrontProcessWithOptions") @discardableResult
 func _SLPSSetFrontProcessWithOptions(_ psn: inout ProcessSerialNumber, _ wid: UInt32, _ mode: UInt32) -> CGError

 @_silgen_name("SLPSPostEventRecordTo") @discardableResult
 func SLPSPostEventRecordTo(_ psn: inout ProcessSerialNumber, _ bytes: inout UInt8) -> CGError

 let kCPSUserGenerated: UInt32 = 0x200
// swiftlint:enable identifier_name

/// Generic protocol for objects acting as windows in the system.
protocol WindowType: Equatable {
    associatedtype Screen: ScreenType
    associatedtype WindowID: Codable, Hashable

    /// Returns the currently focused window of its type.
    static func currentlyFocused() -> Self?

    /**
     Attempt to initialize a window based on a Silica element.
     
     Many of the accessibility APIs handle elements directly, so we need a way to convert those elements into a general window type. This is not necessarily meaningful in all cases — tests, for example, may provide window types that do not correspond to actual elements.
     
     - Parameters:
        - element: The element representing a window.
     */
    init?(element: SIAccessibilityElement?)

    /// Returns an opaque unique identifier for the window.
    func id() -> WindowID

    /// Returns the window's ID in the underlying window system.
    func cgID() -> CGWindowID

    /// Returns the window's current frame.
    func frame() -> CGRect

    /// Returns the screen, if any, that the window is currently on.
    func snapScreen() -> Screen?

    /**
     Sets the frame of the window with an error threshold for what constitutes a new frame.
     
     The tolerance for error is necessary as for performance reasons we avoid performing unnecessary frame assignments, but some windows (e.g., Terminal's windows) have some constraints on their size such that `frame` and `window.frame()` will differ by some small amount even if `frame` has been applied before. We want to treat that frame as equivalent if it is close enough so that we get the performance benefit.
     
     - Parameters:
         - frame: The frame to apply.
         - threshold: The error tolerance for what constitutes a new frame.
     */

    func setFrame(_ frame: CGRect, withThreshold threshold: CGSize)

    /// Whether or not the window is currently holding focus.
    func isFocused() -> Bool

    /// The process ID of the process that owns the window.
    func pid() -> pid_t

    /**
     The title of the window.
     
     - Note: Windows do not necessarily have titles so this can be `nil`.
     */
    func title() -> String?

    /// Whether or not the window should actually be managed by Amethyst.
    func shouldBeManaged() -> Bool

    /// Whether or not the window should float by default.
    func shouldFloat() -> Bool

    /// Whether or not the window is currently active.
    func isActive() -> Bool

    /**
     Focuses the window.
     
     - Returns:
     `true` if the window was successfully focused, `false` otherwise.
     */
    @discardableResult func focus() -> Bool

    @discardableResult func minimize() -> Bool

    /**
     Moves the window to a screen.
     
     This method takes into account the dimensions of the screen to ensure that the window actually fits onto it.
     
     - Parameters:
        - screen: The screen to move the window to.
     */
    func moveScaled(to screen: Screen)

    /// Whether or not the window is currently on any screen.
    func isOnScreen() -> Bool

    /**
     Moves the window to a space.
     
     - Parameters:
        - space: The index of the space.
     */
    func move(toSpace space: UInt)

    /**
     Moves the window to the space at an index.
     
     - Parameters:
        - space: The index of the space
     */
    func move(toSpaceAtIndex space: UInt)

    /**
     Moves the window to a space.
     
     - Parameters:
         - spaceID: The id of the space.
     */
    func move(toSpace spaceID: CGSSpaceID)
}

enum WindowDecodingError: Error {
    case idNotFound
}

/**
 Final subclass of the Silica `SIWindow`.
 
 A final class is necessary for satisfying the `focusedWindow()` requirement in the `WindowType` protocol. Otherwise, as `SIWindow` is not final, the type system does not know how to constrain `Self`.
 */
final class AXWindow: SIWindow {}

/**
 Identifier for `AXWindow` objects.
 
 - Note:
 Decoding for this object is very inefficient. Use it sparingly.
 */
final class AXWindowID: Hashable, Codable {
    /// Coding keys.
    private enum CodingKeys: String, CodingKey {
        /// The pid of the process that owns the window.
        case pid

        /// The CoreGraphics id for the window.
        case windowID
    }

    private let window: AXWindow

    /// Equality for window IDs is based on the underlying CoreGraphics id and the owning pid, which (mostly) uniquely identifies a window.
    static func == (lhs: AXWindowID, rhs: AXWindowID) -> Bool {
        return lhs.window.pid() == rhs.window.pid() && lhs.window.windowID() == rhs.window.windowID()
    }

    func hash(into hasher: inout Hasher) {
        hasher.combine(window.pid())
        hasher.combine(window.windowID())
    }

    fileprivate init(window: AXWindow) {
        self.window = window
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        let pid = try container.decode(pid_t.self, forKey: .pid)
        let windowID = try container.decode(CGWindowID.self, forKey: .windowID)

        guard let application = SIApplication(pid: pid) else {
            throw WindowDecodingError.idNotFound
        }

        let windows: [SIWindow] = application.windows()

        guard let window = windows.first(where: { $0.windowID() == windowID }) else {
            throw WindowDecodingError.idNotFound
        }

        self.window = AXWindow(axElement: window.axElementRef)
    }

    func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(window.pid(), forKey: .pid)
        try container.encode(window.windowID(), forKey: .windowID)
    }
}

/// Conformance of `AXWindow` as an Amethyst window.
extension AXWindow: WindowType {
    typealias Screen = AMScreen
    typealias WindowID = AXWindowID

    /**
     Returns the currently focused window.
     
     - Returns:
     The currently focused window as an `AXWindow`.
     */
    static func currentlyFocused() -> AXWindow? {
        return SIWindow.focused().flatMap { AXWindow(axElement: $0.axElementRef) }
    }

    /**
     The Silica initializer is not failable because it can always assume it has a reference to an ax element. The window type in general does not make that assumption and thus has a failable initializer. This just ports one into the other.
     
     - Parameters:
        - element: The element representing a window.
     */
    convenience init?(element: SIAccessibilityElement?) {
        guard let axElementRef = element?.axElementRef else {
            return nil
        }

        self.init(axElement: axElementRef)
    }

    func id() -> WindowID {
        return AXWindowID(window: self)
    }

    func cgID() -> CGWindowID {
        return windowID()
    }

    func snapScreen() -> AMScreen? {
        let nsScreen: NSScreen? = screen()
        return nsScreen.flatMap { AMScreen(screen: $0) }
    }

    func pid() -> pid_t {
        return processIdentifier()
    }

    /**
     Whether or not the window should actually be managed by Amethyst.
     
     In this case the window must be movable and be a standard window.
     */
    func shouldBeManaged() -> Bool {
        let windowTitle = title() ?? ""
        let windowPID = pid()

        guard isMovable() else {
            log("   🚫 shouldBeManaged: not movable - '\(windowTitle)'")
            return false
        }

        guard isResizable() else {
            log("   🚫 shouldBeManaged: not resizable - '\(windowTitle)'")
            return false
        }

        guard let subrole = string(forKey: kAXSubroleAttribute as CFString), subrole == kAXStandardWindowSubrole as String else {
            log("   🚫 shouldBeManaged: subrole not AXStandardWindow - '\(windowTitle)'")
            return false
        }

        // Additional filtering for proper manageable windows
        if isTemporaryWindow() {
            log("   🚫 shouldBeManaged: isTemporaryWindow - '\(windowTitle)'")
            return false
        }

        if isTooSmallToBeUseful() {
            let frame = self.frame()
            log("   🚫 shouldBeManaged: too small (\(frame.width)x\(frame.height)) - '\(windowTitle)'")
            return false
        }

        // Check if the app has shortcuts assigned - only manage windows from apps with shortcuts
        if let runningApp = NSRunningApplication(processIdentifier: windowPID),
           let bundleID = runningApp.bundleIdentifier {

            guard let config = ConfigurationManager.shared.loadConfig() else {
                log("❌ Failed to load configuration for window management")
                return false
            }

            // Check if this app has any shortcuts configured
            let hasAppShortcut = config.appShortcuts.contains { appShortcut in
                appShortcut.bundleIdentifier == bundleID && appShortcut.shortcut != nil
            }

            if hasAppShortcut {
                log("📝 Managing window: '\(windowTitle)' from \(bundleID)")
            } else {
                log("   🚫 shouldBeManaged: no shortcut configured for '\(bundleID)' - '\(windowTitle)'")
            }

            return hasAppShortcut
        }

        log("   🚫 shouldBeManaged: failed to get app/bundleID - '\(windowTitle)'")
        return false
    }
    
    
    /**
     Checks if this is a temporary window like tooltips, popups, or overlays.
     */
    private func isTemporaryWindow() -> Bool {
        let windowTitle = title() ?? ""
        let trimmedTitle = windowTitle.trimmingCharacters(in: .whitespacesAndNewlines)
        
        // Windows with empty or very short titles are often temporary UI elements
        if trimmedTitle.isEmpty || trimmedTitle.count <= 2 {
            return true
        }
        
        // Check for common temporary window patterns
        let temporaryPatterns = [
            "Tooltip",
            "ToolTip", 
            "tooltip",
            "Popup",
            "popup",
            "Menu",
            "ContextMenu",
            "Dropdown",
            "HUD",
            "Overlay",
            "Preview",
            "Quick Look",
            "Notification",
            "Alert",
            "Dialog",
            // Arc browser specific patterns
            "Space",
            "Tab Preview",
            "Link Preview",
            "Hover",
            "Float",
            // Common system UI elements
            "Status",
            "Info",
            "Help",
            // Single character or number titles (often temporary)
            "•", "…", "➤", "▶", "⏸", "⏹", "⏮", "⏭"
        ]
        
        for pattern in temporaryPatterns {
            if windowTitle.localizedCaseInsensitiveContains(pattern) {
                return true
            }
        }
        
        // Check for windows that are just numbers or single characters
        if trimmedTitle.count <= 3 && (trimmedTitle.rangeOfCharacter(from: CharacterSet.alphanumerics.inverted) != nil || trimmedTitle.allSatisfy { $0.isNumber }) {
            return true
        }
        
        // Check if title suggests this is a temporary Arc browser element
        if windowTitle.contains("Arc") {
            return true
        }
        
        return false
    }
    
    /**
     Checks if the window is too small to be useful for tiling.
     */
    private func isTooSmallToBeUseful() -> Bool {
        let frame = self.frame()
        
        // Filter out very small windows that are likely UI elements or tooltips
        let minimumWidth: CGFloat = 200
        let minimumHeight: CGFloat = 150
        
        return frame.width < minimumWidth || frame.height < minimumHeight
    }
    

    func shouldFloat() -> Bool {
        let frame = self.frame()

        if ConfigurationManager.shared.config.windowBehavior.floatSmallWindows && frame.size.width < 500 && frame.size.height < 500 {
            return true
        }

        return false
    }

    func isFocused() -> Bool {
        guard let focused = AXWindow.currentlyFocused() else {
            return false
        }

        return isEqual(to: focused)
    }

    /**
     Focuses the window.
     
     This handles focusing and also moves the cursor to the window's frame if mouse-follows-focus is enabled.
     
     - Returns:
     `true` if the window was successfully focused, `false` otherwise.
     
     - Description:
     What a mess. See: https://github.com/Hammerspoon/hammerspoon/issues/370#issuecomment-545545468
     */
    @discardableResult override func focus() -> Bool {
        let pid = self.pid()
        var wid = self.cgID()
        var psn = ProcessSerialNumber()
        let status = GetProcessForPID(pid, &psn)

        guard status == noErr else {
            return false
        }

        var cgStatus = _SLPSSetFrontProcessWithOptions(&psn, wid, kCPSUserGenerated)

        guard cgStatus == .success else {
            return false
        }

        for byte in [0x01, 0x02] {
            var bytes = [UInt8](repeating: 0, count: 0xf8)
            bytes[0x04] = 0xF8
            bytes[0x08] = UInt8(byte)
            bytes[0x3a] = 0x10
            memcpy(&bytes[0x3c], &wid, MemoryLayout<UInt32>.size)
            memset(&bytes[0x20], 0xFF, 0x10)
            cgStatus = bytes.withUnsafeMutableBufferPointer { pointer in
                return SLPSPostEventRecordTo(&psn, &pointer.baseAddress!.pointee)
            }
            guard cgStatus == .success else {
                return false
            }
        }

        guard super.raise() else {
            return false
        }

        guard ConfigurationManager.shared.config.windowBehavior.mouseFollowsFocus else {
            return true
        }

        let windowFrame = frame()
        let mouseCursorPoint = CGPoint(x: windowFrame.midX, y: windowFrame.midY)
        guard let mouseMoveEvent = CGEvent(mouseEventSource: nil, mouseType: .mouseMoved, mouseCursorPosition: mouseCursorPoint, mouseButton: .left) else {
            return true
        }
        mouseMoveEvent.flags = CGEventFlags(rawValue: 0)
        mouseMoveEvent.post(tap: CGEventTapLocation.cghidEventTap)

        return true
    }

    @discardableResult func minimize() -> Bool {
        super.minimize()
        return isWindowMinimized()
    }

    func moveScaled(to screen: Screen) {
        let screenFrame = screen.frameWithoutDockOrMenu()
        let currentFrame = frame()
        var scaledFrame = currentFrame

        if scaledFrame.width > screenFrame.width {
            scaledFrame.size.width = screenFrame.width
        }

        if scaledFrame.height > screenFrame.height {
            scaledFrame.size.height = screenFrame.height
        }

        if scaledFrame != currentFrame {
            setFrame(scaledFrame)
        }

        move(to: screen.screen)
    }

    func move(toSpaceAtIndex space: UInt) {
        super.move(toSpace: space)
    }

    func move(toSpace spaceID: CGSSpaceID) {
    }
}
