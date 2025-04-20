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
            let key = Key(string: generalShortcut.shortcut.key) ?? .zero
            let modifiers = parseModifiers(generalShortcut.shortcut.modifiers)
            
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
            default:
                continue
            }
            
            hotKeys.append(hotKey)
        }
        
        // Setup app shortcuts
        for appShortcut in config.appShortcuts {
            let key = Key(string: appShortcut.shortcut.key) ?? .zero
            let modifiers = parseModifiers(appShortcut.shortcut.modifiers)
            
            let hotKey = HotKey(key: key, modifiers: modifiers)
            hotKey.keyDownHandler = { [weak self] in
                // Check if we're recording a shortcut before executing
                guard !HotkeyManager.isRecordingShortcut else { return }
                self?.windowController.focusApp(appShortcut.bundleIdentifier)
            }
            hotKeys.append(hotKey)
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
