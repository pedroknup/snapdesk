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

class HotkeyManager {
    var hotKeys: [HotKey] = []
    let windowController: WindowController
    private let configManager = ConfigurationManager.shared
    
    // Static property to track if shortcuts are being recorded
    static var isRecordingShortcut = false
    
    // Static method to pause all hotkeys
    static func pauseAllHotkeys() {
        isRecordingShortcut = true
        log("⏸ Pausing all hotkeys for shortcut recording")
    }
    
    // Static method to resume all hotkeys
    static func resumeAllHotkeys() {
        isRecordingShortcut = false
        log("▶️ Resuming all hotkeys after shortcut recording")
    }

    init(controller: WindowController) {
        self.windowController = controller
        setupBindings()
    }

    func setupBindings() {
        // Load configuration or use defaults
        let config = configManager.loadConfig() ?? configManager.getDefaultConfig()
        
        // Setup general shortcuts
        for generalShortcut in config.generalShortcuts {
            // Skip if shortcut is nil
            guard let shortcut = generalShortcut.shortcut else { continue }
            
            let key = Key(string: shortcut.key) ?? .zero
            let modifiers = parseModifiers(shortcut.modifiers)
            
            let hotKey = HotKey(key: key, modifiers: modifiers)
            
            switch generalShortcut.name {
            case "Toggle Full Screen layout for the current screen":
                hotKey.keyDownHandler = { [weak self] in
                    // Check if we're recording a shortcut before executing
                    guard !HotkeyManager.isRecordingShortcut else { return }
                    self?.windowController.toggleFullScreen()
                }
            case "Remove current window from layout":
                hotKey.keyDownHandler = { [weak self] in
                    // Check if we're recording a shortcut before executing
                    guard !HotkeyManager.isRecordingShortcut else { return }
                    self?.windowController.removeCurrentWindowFromLayout()
                }
            // Focus Screen shortcuts
            case "Focus Screen 1", "Focus Screen 2", "Focus Screen 3", "Focus Screen 4", "Focus Screen 5", "Focus Screen 6":
                hotKey.keyDownHandler = { [weak self] in
                    guard !HotkeyManager.isRecordingShortcut else { return }
                    if let screenNumber = Int(generalShortcut.name.split(separator: " ").last ?? "0") {
                        self?.windowController.focusScreen(screenNumber)
                    }
                }
            // Throw to Screen shortcuts
            case "Throw to Screen 1", "Throw to Screen 2", "Throw to Screen 3", "Throw to Screen 4", "Throw to Screen 5", "Throw to Screen 6":
                hotKey.keyDownHandler = { [weak self] in
                    guard !HotkeyManager.isRecordingShortcut else { return }
                    if let screenNumber = Int(generalShortcut.name.split(separator: " ").last ?? "0") {
                        self?.windowController.throwToScreen(screenNumber)
                    }
                }
            // Layout management shortcuts
            case "Throw app to current layout modifier":
                hotKey.keyDownHandler = { [weak self] in
                    guard !HotkeyManager.isRecordingShortcut else { return }
                    self?.windowController.throwToCurrentLayout()
                }
            case "Increase main panel count":
                hotKey.keyDownHandler = { [weak self] in
                    guard !HotkeyManager.isRecordingShortcut else { return }
                    self?.windowController.increaseMainPanelCount()
                }
            case "Decrease main panel count":
                hotKey.keyDownHandler = { [weak self] in
                    guard !HotkeyManager.isRecordingShortcut else { return }
                    self?.windowController.decreaseMainPanelCount()
                }
            case "Cycle current layout windows clockwise":
                hotKey.keyDownHandler = { [weak self] in
                    guard !HotkeyManager.isRecordingShortcut else { return }
                    self?.windowController.cycleWindowsClockwise()
                }
            case "Cycle current layout windows counterclockwise":
                hotKey.keyDownHandler = { [weak self] in
                    guard !HotkeyManager.isRecordingShortcut else { return }
                    self?.windowController.cycleWindowsCounterclockwise()
                }
            default:
                continue
            }
            
            hotKeys.append(hotKey)
        }
        
        // Setup app shortcuts
        for appShortcut in config.appShortcuts {
            // Skip if shortcut is nil
            guard let shortcut = appShortcut.shortcut, !shortcut.key.isEmpty else { continue }
            
            let key = Key(string: shortcut.key)!
            let modifiers = parseModifiers(shortcut.modifiers)
            
            // Create regular focus shortcut
            let focusHotKey = HotKey(key: key, modifiers: modifiers)
            focusHotKey.keyDownHandler = { [weak self] in
                guard !HotkeyManager.isRecordingShortcut else { return }
                self?.windowController.focusApp(appShortcut.bundleIdentifier)
            }
            hotKeys.append(focusHotKey)
            
            // Create throw shortcut with shift modifier
            var throwModifiers = modifiers
            throwModifiers.insert(.shift)
            let throwHotKey = HotKey(key: key, modifiers: throwModifiers)
            throwHotKey.keyDownHandler = { [weak self] in
                guard !HotkeyManager.isRecordingShortcut else { return }
                log("Throw shortcut triggered for \(appShortcut.bundleIdentifier)")
                self?.windowController.addWindowToLayout(appShortcut.bundleIdentifier)
            }
            hotKeys.append(throwHotKey)
        }
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
}
