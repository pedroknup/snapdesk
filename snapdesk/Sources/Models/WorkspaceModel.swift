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
        // rebuild if display config changed
        self.screens = AMScreen.availableScreens.map { ScreenWorkspace(screen: $0) }
    }

    func screen(for amScreen: AMScreen) -> ScreenWorkspace? {
        return screens.first { $0.screen == amScreen }
    }
}
