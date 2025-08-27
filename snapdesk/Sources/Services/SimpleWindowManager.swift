//
//  SimpleWindowManager.swift
//  snapdesk
//
//  Created by Pedro Knup on 27/08/2025.
//

import Foundation
import AppKit

class SimpleWindowManager: WindowManaging {
    private var workspace: WorkspaceModel

    init() {
        var ws = snapdesk.WorkspaceModel()

        let discovered = scanWindows()
        for (win, screen) in discovered {
            if let idx = ws.screens.firstIndex(where: { $0.screen == screen }) {
                // Create a fresh WindowSet just for this window
                let newSet = WindowSet(layout: .wide, windows: [win])
                ws.screens[idx].windowSets.append(newSet)
            }
        }

        self.workspace = ws

        print("Workspace initialized with \(ws.screens.count) screens and \(discovered.count) windows")

        for screenWS in ws.screens {
            let frame = screenWS.screen.frame()
            print("\n🖥️  Screen \(screenWS.screen.screenID() ?? "?") frame=\(NSStringFromRect(frame))")

            for (setIndex, set) in screenWS.windowSets.enumerated() {
                let windowCount = set.windows.count
                print("   ▾ WindowSet \(setIndex) [layout=\(set.layout)] — \(windowCount) window(s)")

                if set.windows.isEmpty {
                    print("      (no windows)")
                } else {
                    for (wIndex, w) in set.windows.enumerated() {
                        let title = w.title() ?? "<untitled>"
                        let rect  = NSStringFromRect(w.frame())
                        print("      [\(wIndex)] PID \(w.pid()) — \"\(title)\" frame=\(rect)")
                    }
                }
            }
        }
    }

    
    func addWindowToLayout(_ bundleID: String) {
        log("TODO: addWindowToLayout")
    }
    
    
    private func currentWindow() -> AXUIElement? {
         return frontmostWindow()
     }
    
    private func screenList() -> [NSScreen] {
        // Sort screens in a stable order (menu bar first)
        return NSScreen.screens
    }
    
    // MARK: - Screen Management
    
    func toggleFullScreen() {
        log("🖥 toggleFullScreen() called")
        // TODO: Implement full screen toggle functionality
    }
    
    func focusScreen(_ screenNumber: Int) {
        log("🎯 focusScreen(\(screenNumber)) called")
        // TODO: Implement screen focus functionality
    }
    
    func throwToScreen(_ screenNumber: Int) {
        log("📤 throwToScreen(\(screenNumber)) called")
        // TODO: Implement throw to screen functionality
    }
    
    // MARK: - App Management
    
    func focusApp(_ bundleID: String) {
        log("🎯 NEW focusApp(\(bundleID)) called")
        
//        // Find running application with bundle ID
//        guard let runningApp = NSRunningApplication.runningApplications(withBundleIdentifier: bundleID).first else {
//            log("❌ No running app found with bundle ID: \(bundleID)")
//            return
//        }
//        
//        // Activate the application
//        runningApp.activate(options: .activateIgnoringOtherApps)
//        log("✅ Activated app: \(bundleID)")
        let windowSets = windowSets(for: bundleID)
        log("Found WindowSets: \(windowSets)")
        
    }
    
    // MARK: - WindowManaging methods

       func focusScreen(at index: Int) {
           let screens = screenList()
           guard index < screens.count else { return }
           let targetScreen = screens[index]

           // Find a window on that screen and focus it
           if let window = windowOnScreen(targetScreen) {
               AXUIElementSetAttributeValue(window, kAXFocusedAttribute as CFString, kCFBooleanTrue)
           }
       }

       func throwFrontmostWindow(toScreen index: Int) {
           guard let window = currentWindow() else { return }
           let screens = screenList()
           guard index < screens.count else { return }

           let targetFrame = screens[index].visibleFrame.insetBy(dx: 8, dy: 8)
           move(window: window, to: targetFrame)
       }

       func throwToCurrentLayout() {
           guard let window = currentWindow(),
                 let screen = NSScreen.main else { return }

           // Example: tile full width, half height
           let vf = screen.visibleFrame
           let target = CGRect(x: vf.minX,
                               y: vf.midY,
                               width: vf.width,
                               height: vf.height/2)
           move(window: window, to: target)
       }

       func increaseMainPanelCount() {
           print("TODO: implement layout engine, increase main count")
       }

       func decreaseMainPanelCount() {
           print("TODO: implement layout engine, decrease main count")
       }

       func cycleWindowsClockwise() {
           print("TODO: cycle window focus clockwise")
       }

       func cycleWindowsCounterclockwise() {
           print("TODO: cycle window focus counterclockwise")
       }

       func removeCurrentWindowFromLayout() {
           print("TODO: track floating windows, exclude from tiling")
       }

       func toggleFullScreenLayout() {
           guard let window = currentWindow(),
                 let screen = NSScreen.main else { return }
           let vf = screen.visibleFrame
           move(window: window, to: vf)
       }

       // MARK: - Utilities

       private func windowOnScreen(_ screen: NSScreen) -> AXUIElement? {
           // Super simple: if the frontmost window is already on this screen, return it
           if let w = currentWindow(),
              let f = windowFrame(of: w),
              f.intersects(screen.frame) {
               return w
           }
           return nil
       }
    
    /// Returns all WindowSets that contain at least one window belonging to the given bundle ID.
    private func windowSets(for bundleID: String) -> [WindowSet] {
        var matchingSets: [WindowSet] = []

        for screenWS in workspace.screens {
            for set in screenWS.windowSets {
                let matches = set.windows.contains { win in
                    guard let app = NSRunningApplication(processIdentifier: win.pid()) else {
                        return false
                    }
                    return app.bundleIdentifier == bundleID
                }

                if matches {
                    matchingSets.append(set)
                }
            }
        }

        return matchingSets
    }
}
