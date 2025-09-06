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
        log("❌ Failed to get window list from CGWindowListCopyWindowInfo")
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
            if let axWin = AXWindow(element: siWin) {
                let windowFrame = axWin.frame()
                let shouldManage = axWin.shouldBeManaged()
                let frameIntersects = windowFrame.intersects(bounds)
                // Try to find screen by bounds intersection first
                var screen = AMScreen.availableScreens.first(where: { $0.frame().intersects(bounds) })
                
                // If no screen found by intersection, try to find the closest screen by center point
                if screen == nil {
                    let windowCenter = CGPoint(x: bounds.midX, y: bounds.midY)
                    var closestScreen: AMScreen?
                    var closestDistance: CGFloat = .greatestFiniteMagnitude
                    
                    for candidateScreen in AMScreen.availableScreens {
                        let screenFrame = candidateScreen.frame()
                        let screenCenter = CGPoint(x: screenFrame.midX, y: screenFrame.midY)
                        let distance = sqrt(pow(windowCenter.x - screenCenter.x, 2) + pow(windowCenter.y - screenCenter.y, 2))
                        
                        if distance < closestDistance {
                            closestDistance = distance
                            closestScreen = candidateScreen
                        }
                    }
                    screen = closestScreen
                }
                
                if shouldManage && frameIntersects, let screen = screen {
                    results.append((axWin, screen))
                }
            }
        }

    }

    return results
}
