//
//  ScreenWorkspace.swift
//  snapdesk
//
//  Created by Pedro Knup on 27/08/2025.
//

import Foundation

struct ScreenWorkspace: Identifiable {
    let id: UUID = UUID()
    let screen: AMScreen

    /// Each screen can host multiple sets of windows (tiled, floating, etc.)
    var windowSets: [WindowSet]

    init(screen: AMScreen, sets: [WindowSet] = []) {
           self.screen = screen
           self.windowSets = sets
   }
}
