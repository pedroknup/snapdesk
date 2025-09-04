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
}
