//
//  HotkeyManager.swift
//  snapdesk
//
//  Created by Pedro Knup on 18/04/2025.
//

import HotKey
import Carbon
import Foundation

class HotkeyManager {
    var hotKeys: [HotKey] = []
    let windowController: WindowController

    init(controller: WindowController) {
        self.windowController = controller
        setupBindings()
    }

    func setupBindings() {
        let appShortcuts: [String: (Key, NSEvent.ModifierFlags)] = [
            "company.thebrowser.Browser": (.one, [.command, .option]),
            "com.googlecode.iterm2": (.six, [.command, .option]),
            "notion.id": (.three, [.command, .option]),
            "com.apple.dt.Xcode": (.f, [.command, .option]),
            "com.spotify.client": (.nine, [.command, .option])
        ]
        
        let appSplitShortcuts: [String: (Key, NSEvent.ModifierFlags)] = [
            "company.thebrowser.Browser": (.one, [.command, .option, .shift]),
            "notion.id": (.eight, [.command, .option, .shift]),
            "com.apple.dt.Xcode": (.three, [.command, .option, .shift])
        ]

        for (bundleID, (key, modifiers)) in appShortcuts { 
            let hotKey = HotKey(key: key, modifiers: modifiers)
            hotKey.keyDownHandler = { [weak self] in
                self?.windowController.focusApp(bundleID)
            }
            hotKeys.append(hotKey)
        }
        
        for (bundleID, (key, modifiers)) in appSplitShortcuts {
            let hotKey = HotKey(key: key, modifiers: modifiers)
            hotKey.keyDownHandler = { [weak self] in
                self?.windowController.addAppToSplit(bundleID)
            }
            hotKeys.append(hotKey)
        }
    }
    
    
}
