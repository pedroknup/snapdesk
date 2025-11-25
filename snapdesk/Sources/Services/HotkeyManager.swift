//
//  HotkeyManager.swift
//  snapdesk
//
//  Created by Pedro Knup on 18/04/2025.
//

import HotKey
import Carbon
import Foundation
import AppKit

// Type for defining key code.
typealias AMKeyCode = Int

// Type for defining modifier flags.
typealias AMModifierFlags = NSEvent.ModifierFlags

// Specific key code defined to be invalid.
private let AMKeyCodeInvalid: AMKeyCode = 0xFF

typealias HotKeyHandler = () -> Void

// Protocol that defines how hotkeys are registered
protocol HotKeyRegistrar {
    func registerHotKey(with key: String?, modifiers: AMModifierFlags?, handler: @escaping HotKeyHandler, defaultsKey: String, override: Bool)
}

// Protocol that defines the window management methods we need
protocol WindowManaging: AnyObject {
    func toggleFullScreen()
    func removeCurrentWindowFromLayout()
    func toggleLayoutForCurrentWindowSet()
    func focusScreen(_ screenNumber: Int)
    func throwToScreen(_ screenNumber: Int)
    func throwFrontmostWindow(toScreen index: Int)
    func throwToCurrentLayout()
    func increaseMainPanelSize()
    func decreaseMainPanelSize()
    func expandCurrentLayout()
    func focusApp(_ bundleID: String) async
    func cycleCurrentAppBackward() async
    func addWindowToLayout(_ bundleID: String)
    func showLayoutVisualization()
    
    // Window positioning commands
    func positionWindowLeft()
    func positionWindowRight()
    func positionWindowTop()
    func positionWindowBottom()
    func positionWindowTopLeft()
    func positionWindowTopRight()
    func positionWindowBottomLeft()
    func positionWindowBottomRight()
    func positionWindowCenter()
    
    // Window reordering commands
    func moveWindowUpInLayout()
    func moveWindowDownInLayout()
}

// Static storage for the active HotkeyManager instance (outside generic class)
private class HotkeyManagerStorage {
    static weak var activeInstance: AnyObject?
}

class HotkeyManager: NSObject, HotKeyRegistrar {
    private var hotKeys: [HotKey] = []
    private let windowManager: WindowManaging
    
    // Instance property to track if shortcuts are being recorded
    private var isRecordingShortcut = false
    
    // Static method to pause all hotkeys
    static func pauseAllHotkeys() {
        if let activeInstance = HotkeyManagerStorage.activeInstance as? HotkeyManager {
            activeInstance.isRecordingShortcut = true
        }
    }
    
    // Static method to resume all hotkeys
    static func resumeAllHotkeys() {
        if let activeInstance = HotkeyManagerStorage.activeInstance as? HotkeyManager {
            activeInstance.isRecordingShortcut = false
        }
    }

    private(set) lazy var stringToKeyCodes: [String: [AMKeyCode]] = {
        return self.constructKeyCodeMap()
    }()

    init(windowManager: WindowManaging) {
        self.windowManager = windowManager
        super.init()
        _ = constructKeyCodeMap()

        // Set this as the active instance for static method access
        HotkeyManagerStorage.activeInstance = self
    }

    func setUpWithWindowController(_ windowManager: WindowManaging) async {
        
        // Remove current window from layout
        constructCommandWithCommandKey("remove-current-window-from-layout") { [weak self] in
            guard !(self?.isRecordingShortcut ?? false) else { return }
            self?.windowManager.removeCurrentWindowFromLayout()
        }
        
        // Toggle layout for current WindowSet
        constructCommandWithCommandKey("toggle-layout-current-windowset") { [weak self] in
            guard !(self?.isRecordingShortcut ?? false) else { return }
            self?.windowManager.toggleLayoutForCurrentWindowSet()
        }
        
        // Show layout visualization
        constructCommandWithCommandKey("show-layout-visualization") { [weak self] in
            guard !(self?.isRecordingShortcut ?? false) else { return }
            self?.windowManager.showLayoutVisualization()
        }
        
        // Focus Screen shortcuts (1-6)
        (1...6).forEach { screenNumber in
            let commandKey = "focus-screen-\(screenNumber)"
            self.constructCommandWithCommandKey(commandKey) { [weak self] in
                guard !(self?.isRecordingShortcut ?? false) else { return }
                self?.windowManager.focusScreen(screenNumber)
            }
        }
        
        // Throw to Screen shortcuts (1-6)
        (1...6).forEach { screenNumber in
            let commandKey = "throw-screen-\(screenNumber)"
            self.constructCommandWithCommandKey(commandKey) { [weak self] in
                guard !(self?.isRecordingShortcut ?? false) else { return }
                self?.windowManager.throwToScreen(screenNumber)
            }
        }
        
        // Layout management shortcuts
        constructCommandWithCommandKey("throw-to-current-layout") { [weak self] in
            guard !(self?.isRecordingShortcut ?? false) else { return }
            self?.windowManager.throwToCurrentLayout()
        }
        
        constructCommandWithCommandKey("increase-main-panel-size") { [weak self] in
            guard !(self?.isRecordingShortcut ?? false) else { return }
            self?.windowManager.increaseMainPanelSize()
        }
        
        constructCommandWithCommandKey("decrease-main-panel-size") { [weak self] in
            guard !(self?.isRecordingShortcut ?? false) else { return }
            self?.windowManager.decreaseMainPanelSize()
        }
        
        // Expand current layout
        constructCommandWithCommandKey("expand-current-layout") { [weak self] in
            guard !(self?.isRecordingShortcut ?? false) else { return }
            self?.windowManager.expandCurrentLayout()
        }
        
        // Window positioning shortcuts
        constructCommandWithCommandKey("position-window-left") { [weak self] in
            guard !(self?.isRecordingShortcut ?? false) else { return }
            self?.windowManager.positionWindowLeft()
        }
        
        constructCommandWithCommandKey("position-window-right") { [weak self] in
            guard !(self?.isRecordingShortcut ?? false) else { return }
            self?.windowManager.positionWindowRight()
        }
        
        constructCommandWithCommandKey("position-window-top") { [weak self] in
            guard !(self?.isRecordingShortcut ?? false) else { return }
            self?.windowManager.positionWindowTop()
        }
        
        constructCommandWithCommandKey("position-window-bottom") { [weak self] in
            guard !(self?.isRecordingShortcut ?? false) else { return }
            self?.windowManager.positionWindowBottom()
        }
        
        constructCommandWithCommandKey("position-window-top-left") { [weak self] in
            guard !(self?.isRecordingShortcut ?? false) else { return }
            self?.windowManager.positionWindowTopLeft()
        }
        
        constructCommandWithCommandKey("position-window-top-right") { [weak self] in
            guard !(self?.isRecordingShortcut ?? false) else { return }
            self?.windowManager.positionWindowTopRight()
        }
        
        constructCommandWithCommandKey("position-window-bottom-left") { [weak self] in
            guard !(self?.isRecordingShortcut ?? false) else { return }
            self?.windowManager.positionWindowBottomLeft()
        }
        
        constructCommandWithCommandKey("position-window-bottom-right") { [weak self] in
            guard !(self?.isRecordingShortcut ?? false) else { return }
            self?.windowManager.positionWindowBottomRight()
        }
        
        constructCommandWithCommandKey("position-window-center") { [weak self] in
            guard !(self?.isRecordingShortcut ?? false) else { return }
            self?.windowManager.positionWindowCenter()
        }
        
        // Window reordering shortcuts
        constructCommandWithCommandKey("move-window-up-in-layout") { [weak self] in
            guard !(self?.isRecordingShortcut ?? false) else { return }
            self?.windowManager.moveWindowUpInLayout()
        }

        constructCommandWithCommandKey("move-window-down-in-layout") { [weak self] in
            guard !(self?.isRecordingShortcut ?? false) else { return }
            self?.windowManager.moveWindowDownInLayout()
        }

        // Global backward cycling shortcut
        constructCommandWithCommandKey("cycle-current-app-backward") { [weak self] in
            guard !(self?.isRecordingShortcut ?? false) else { return }
            Task {
                await self?.windowManager.cycleCurrentAppBackward()
            }
        }
        
        // Setup app shortcuts - we'll need to handle these dynamically
        await setupAppShortcuts()
    }
    
    private func setupAppShortcuts() async {
        let config = ConfigurationManager.shared.loadConfig() ?? ConfigurationManager.shared.getDefaultConfig()
        
        // Setup app shortcuts
        for appShortcut in config.appShortcuts {
            guard let shortcut = appShortcut.shortcut, !shortcut.key.isEmpty else { continue }

            let key = Key(string: shortcut.key) ?? .zero
            let modifiers = parseModifiers(shortcut.modifiers)

            // Create regular focus shortcut
            let focusHotKey = HotKey(key: key, modifiers: modifiers)
            focusHotKey.keyDownHandler = { [weak self] in
                guard !(self?.isRecordingShortcut ?? false) else { return }
                Task {
                    await self?.windowManager.focusApp(appShortcut.bundleIdentifier)
                }
            }
            hotKeys.append(focusHotKey)

            // Create throw shortcut with shift modifier
            var throwModifiers = modifiers
            throwModifiers.insert(.shift)
            let throwHotKey = HotKey(key: key, modifiers: throwModifiers)
            throwHotKey.keyDownHandler = { [weak self] in
                guard !(self?.isRecordingShortcut ?? false) else { return }
                self?.windowManager.addWindowToLayout(appShortcut.bundleIdentifier)
            }
            hotKeys.append(throwHotKey)
        }
    }
    
    // MARK: - Amethyst-style methods
    
    private func constructKeyCodeMap() -> [String: [AMKeyCode]] {
        var stringToKeyCodes: [String: [AMKeyCode]] = [:]

        // Generate unicode character keymapping from keyboard layout data.
        var currentKeyboard = TISCopyCurrentKeyboardInputSource().takeRetainedValue()
        var rawLayoutData = TISGetInputSourceProperty(currentKeyboard, kTISPropertyUnicodeKeyLayoutData)

        if rawLayoutData == nil {
            currentKeyboard = TISCopyCurrentASCIICapableKeyboardLayoutInputSource().takeUnretainedValue()
            rawLayoutData = TISGetInputSourceProperty(currentKeyboard, kTISPropertyUnicodeKeyLayoutData)
        }

        // Get the layout
        let layoutData = unsafeBitCast(rawLayoutData, to: CFData.self)
        let layout: UnsafePointer<UCKeyboardLayout> = unsafeBitCast(CFDataGetBytePtr(layoutData), to: UnsafePointer<UCKeyboardLayout>.self)

        var keysDown: UInt32 = 0
        var chars: [UniChar] = [0, 0, 0, 0]
        var realLength: Int = 0

        for keyCode in (0..<AMKeyCodeInvalid) {
            switch keyCode {
            case
            kVK_ANSI_Keypad0,
            kVK_ANSI_Keypad1,
            kVK_ANSI_Keypad2,
            kVK_ANSI_Keypad3,
            kVK_ANSI_Keypad4,
            kVK_ANSI_Keypad5,
            kVK_ANSI_Keypad6,
            kVK_ANSI_Keypad7,
            kVK_ANSI_Keypad8,
            kVK_ANSI_Keypad9:
                continue
            default:
                break
            }

            UCKeyTranslate(layout,
                           UInt16(keyCode),
                           UInt16(kUCKeyActionDisplay),
                           0,
                           UInt32(LMGetKbdType()),
                           UInt32(kUCKeyTranslateNoDeadKeysBit),
                           &keysDown,
                           chars.count,
                           &realLength,
                           &chars)

            let string = CFStringCreateWithCharacters(kCFAllocatorDefault, chars, realLength) as String

            if let keyCodes = stringToKeyCodes[string] {
                var mutableKeyCodes = keyCodes
                mutableKeyCodes.append(keyCode)
                stringToKeyCodes[string] = mutableKeyCodes
            } else {
                stringToKeyCodes[string] = [keyCode]
            }
        }

        // Add codes for non-printable characters
        stringToKeyCodes["space"] = [kVK_Space]
        stringToKeyCodes["enter"] = [kVK_Return]
        stringToKeyCodes["up"] = [kVK_UpArrow]
        stringToKeyCodes["right"] = [kVK_RightArrow]
        stringToKeyCodes["down"] = [kVK_DownArrow]
        stringToKeyCodes["left"] = [kVK_LeftArrow]
        stringToKeyCodes["delete"] = [kVK_Delete]

        return stringToKeyCodes
    }

    private func constructCommandWithCommandKey(_ commandKey: String, handler: @escaping HotKeyHandler) {
        ConfigurationManager.shared.constructCommand(for: self, commandKey: commandKey, handler: handler)
    }
    
    // MARK: - HotKeyRegistrar Protocol
    
    func registerHotKey(with key: String?, modifiers: AMModifierFlags?, handler: @escaping HotKeyHandler, defaultsKey: String, override: Bool) {
        guard let keyString = key, let modifiers = modifiers, !keyString.isEmpty else {
            return
        }
        
        // Convert string to HotKey Key enum
        guard let hotKeyKey = Key(string: keyString) else {
            return
        }
        
        // Create and store the HotKey
        let hotKey = HotKey(key: hotKeyKey, modifiers: modifiers)
        hotKey.keyDownHandler = { [weak self] in
            guard !(self?.isRecordingShortcut ?? false) else { return }
            handler()
        }
        
        hotKeys.append(hotKey)
    }
    
    private func parseModifiers(_ modifierStrings: [String]) -> NSEvent.ModifierFlags {
        var modifiers: NSEvent.ModifierFlags = []
        
        for modifier in modifierStrings {
            switch modifier.lowercased() {
            case "command":
                modifiers.insert(.command)
            case "option":
                modifiers.insert(.option)
            case "shift":
                modifiers.insert(.shift)
            case "control":
                modifiers.insert(.control)
            default:
                break
            }
        }
        
        return modifiers
    }
    
    // MARK: - Command Key Mapping
    
    static func commandKeyToDisplayName() -> [String: String] {
        return [
            // Layout management
            "toggle-layout-current-windowset": "Toggle layout for current WindowSet",
            "show-layout-visualization": "Show layout visualization",
            "expand-current-layout": "Expand Windows",
            "remove-current-window-from-layout": "Remove current window from layout",
            "throw-to-current-layout": "Throw app to current layout modifier",
            
            // Panel size management
            "increase-main-panel-size": "Increase main panel size",
            "decrease-main-panel-size": "Decrease main panel size",
            
            // Window positioning
            "position-window-left": "Position Window Left",
            "position-window-right": "Position Window Right",
            "position-window-top": "Position Window Top",
            "position-window-bottom": "Position Window Bottom",
            "position-window-top-left": "Position Window Top Left",
            "position-window-top-right": "Position Window Top Right",
            "position-window-bottom-left": "Position Window Bottom Left",
            "position-window-bottom-right": "Position Window Bottom Right",
            "position-window-center": "Position Window Center",
            
            // Window reordering
            "move-window-up-in-layout": "Move Window Up in Layout",
            "move-window-down-in-layout": "Move Window Down in Layout",

            // App cycling
            "cycle-current-app-backward": "Cycle Current App Backward",
            
            // Screen focus
            "focus-screen-1": "Focus Screen 1",
            "focus-screen-2": "Focus Screen 2",
            "focus-screen-3": "Focus Screen 3",
            "focus-screen-4": "Focus Screen 4",
            "focus-screen-5": "Focus Screen 5",
            "focus-screen-6": "Focus Screen 6",
            
            // Throw to screen
            "throw-screen-1": "Throw to Screen 1",
            "throw-screen-2": "Throw to Screen 2",
            "throw-screen-3": "Throw to Screen 3",
            "throw-screen-4": "Throw to Screen 4",
            "throw-screen-5": "Throw to Screen 5",
            "throw-screen-6": "Throw to Screen 6"
        ]
    }
    
    // MARK: - Configuration Reload Support
    
    func reloadConfiguration() {
        // Clear existing hotkeys
        hotKeys.removeAll()

        // Reload general shortcuts
        Task {
            await setUpWithWindowController(windowManager)
        }
    }
}
