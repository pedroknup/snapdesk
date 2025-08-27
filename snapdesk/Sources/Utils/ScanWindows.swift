//
//  ScanWindows.swift
//  snapdesk
//
//  Created by Pedro Knup on 27/08/2025.
//

import Foundation
import Cocoa
import ApplicationServices
import Silica

/// Return all visible, on-screen windows as AXUIElements
func scanWindows() -> [(window: AXWindow, screen: AMScreen)] {
    var results: [(AXWindow, AMScreen)] = []

    let options: CGWindowListOption = [.optionOnScreenOnly, .excludeDesktopElements]
    guard let cgWindows = CGWindowListCopyWindowInfo(options, kCGNullWindowID) as? [[String: AnyObject]] else {
        return results
    }

    for info in cgWindows {
        guard
            let pid = info[kCGWindowOwnerPID as String] as? pid_t,
            let boundsDict = info[kCGWindowBounds as String] as? [String: CGFloat]
        else { continue }

        let bounds = CGRect(
            x: boundsDict["X"] ?? 0,
            y: boundsDict["Y"] ?? 0,
            width: boundsDict["Width"] ?? 0,
            height: boundsDict["Height"] ?? 0
        )
        if bounds.isEmpty { continue }

        guard let app = SIApplication(pid: pid) else { continue }
        let siWindows = app.snapWindows()

        for siWin in siWindows {
            if let axWin = AXWindow(element: siWin),
               axWin.shouldBeManaged(),
               axWin.frame().intersects(bounds),
               let screen = AMScreen.availableScreens.first(where: { $0.frame().intersects(bounds) }) {
                results.append((axWin, screen))
            }
        }

    }

    return results
}
