//
//  Workspace.swift
//  snapdesk
//
//  Created by Pedro Knup on 27/08/2025.
//

import Foundation

struct WorkspaceModel {
    var screens: [ScreenWorkspace]

    init() {
        self.screens = AMScreen.availableScreens.map { ScreenWorkspace(screen: $0) }
    }


    mutating func refreshScreens() {
        // Get new screens
        let newScreens = AMScreen.availableScreens
        var updatedScreens: [ScreenWorkspace] = []
        
        // For each new screen, try to preserve existing window sets
        for screen in newScreens {
            if let existingScreenWS = screens.first(where: { $0.screen.screenID() == screen.screenID() }) {
                // Screen still exists - preserve its window sets but update the screen reference
                var updated = existingScreenWS
                updated.screen = screen
                updatedScreens.append(updated)
            } else {
                // New screen - create empty workspace
                updatedScreens.append(ScreenWorkspace(screen: screen))
            }
        }
        
        self.screens = updatedScreens
    }

    func screen(for amScreen: AMScreen) -> ScreenWorkspace? {
        return screens.first { $0.screen == amScreen }
    }

    /// Returns all WindowSets across all screens
    func allWindowSets() -> [WindowSet] {
        return screens.flatMap { $0.windowSets }
    }

    /// Returns all windows across all screens
    func allWindows() -> [AXWindow] {
        return screens.flatMap { screenWS in
            screenWS.windowSets.flatMap { $0.windows }
        }
    }

    /// Returns the total count of windows across all screens
    func windowCount() -> Int {
        return screens.reduce(0) { count, screenWS in
            count + screenWS.windowSets.reduce(0) { $0 + $1.windows.count }
        }
    }

    /// Returns the total count of WindowSets across all screens
    func windowSetCount() -> Int {
        return screens.reduce(0) { $0 + $1.windowSets.count }
    }
}
