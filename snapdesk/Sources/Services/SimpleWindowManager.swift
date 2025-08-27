//
//  SimpleWindowManager.swift
//  snapdesk
//
//  Created by Pedro Knup on 27/08/2025.
//

import Foundation
import AppKit

class SimpleWindowManager: WindowManaging {
    
    private var currentBundleIDCycling: String?
    private var bundleIDCycleIndex: Int = 0
    private var workspace: WorkspaceModel

    init() {
        var ws = snapdesk.WorkspaceModel()

        let discovered = scanWindows()
        for (win, screen) in discovered {
            if let idx = ws.screens.firstIndex(where: { $0.screen == screen }) {
                // Create a fresh WindowSet just for this window
                let newSet = WindowSet(layout: .wide, windows: [win], screenID: screen.screenID())
                ws.screens[idx].windowSets.append(newSet)
            }
        }

        self.workspace = ws
        
        // Setup window observers
        setupWindowObservers()

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
        
        let windowSets = windowSets(for: bundleID)
        log("Found \(windowSets.count) WindowSets for \(bundleID)")
        
        if windowSets.isEmpty {
            // No windows found - try to launch the app
            log("🚀 No windows found for \(bundleID), attempting to launch app")
            launchApp(bundleID: bundleID)
            return
        }
        
        // Check if we're cycling through the same app
        if currentBundleIDCycling != bundleID {
            // Reset cycling for new app
            currentBundleIDCycling = bundleID
            bundleIDCycleIndex = 0
            log("🔄 Starting new cycle for \(bundleID) - available WindowSets: \(windowSets.count)")
        } else {
            // Continue cycling through the same app
            let newIndex = (bundleIDCycleIndex + 1) % windowSets.count
            bundleIDCycleIndex = newIndex
            log("🔄 Cycling to index \(bundleIDCycleIndex) for \(bundleID) (total: \(windowSets.count))")
        }
        
        // Focus the window from the current WindowSet
        let currentSet = windowSets[bundleIDCycleIndex]
        
        // Expand all windows in the current WindowSet according to its layout
        currentSet.expandWindows()
        
        if let firstWindow = currentSet.windows.first {
            log("🎯 Focusing window: \(firstWindow.title() ?? "<untitled>")")
            firstWindow.focus()
        }
    }
    
    private func launchApp(bundleID: String) {
        log("🚀 Launching app with bundle ID: \(bundleID)")
        
        // Try to launch the app using NSWorkspace
        let workspace = NSWorkspace.shared
        
        // First, try to find the app path by bundle identifier
        if let appURL = workspace.urlForApplication(withBundleIdentifier: bundleID) {
            log("📱 Found app at path: \(appURL.path)")
            
            workspace.openApplication(at: appURL, configuration: NSWorkspace.OpenConfiguration()) { runningApp, error in
                if let error = error {
                    log("❌ Failed to launch app: \(error.localizedDescription)")
                } else if let app = runningApp {
                    log("✅ Successfully launched: \(app.localizedName ?? "Unknown")")
                    
                    // Reset cycling state for the newly launched app
                    DispatchQueue.main.async {
                        self.currentBundleIDCycling = bundleID
                        self.bundleIDCycleIndex = 0
                        
                        // Give the app time to create windows, then refresh
                        DispatchQueue.main.asyncAfter(deadline: .now() + 1.5) {
                            self.refreshWindows()
                        }
                    }
                }
            }
        } else {
            log("❌ Could not find app with bundle ID: \(bundleID)")
        }
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
    
    /// Returns all WindowSets that contain at least one window belonging to the given bundle ID, sorted consistently.
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
    
    // MARK: - Window Observers
    
    private func setupWindowObservers() {
        // Add workspace notification observers for window lifecycle
        let workspaceNotificationCenter = NSWorkspace.shared.notificationCenter
        
        workspaceNotificationCenter.addObserver(
            self,
            selector: #selector(applicationDidLaunch(_:)),
            name: NSWorkspace.didLaunchApplicationNotification,
            object: nil
        )
        
        workspaceNotificationCenter.addObserver(
            self,
            selector: #selector(applicationDidTerminate(_:)),
            name: NSWorkspace.didTerminateApplicationNotification,
            object: nil
        )
        
        workspaceNotificationCenter.addObserver(
            self,
            selector: #selector(applicationDidActivate(_:)),
            name: NSWorkspace.didActivateApplicationNotification,
            object: nil
        )
    }
    
    @objc private func applicationDidLaunch(_ notification: Notification) {
        guard let app = notification.userInfo?[NSWorkspace.applicationUserInfoKey] as? NSRunningApplication else {
            return
        }
        
        log("🚀 Application launched: \(app.localizedName ?? "Unknown") (\(app.bundleIdentifier ?? "no bundle"))")
        
        // Give the app a moment to create windows
        DispatchQueue.main.asyncAfter(deadline: .now() + 1.0) { [weak self] in
            self?.refreshWindows()
        }
    }
    
    @objc private func applicationDidTerminate(_ notification: Notification) {
        guard let app = notification.userInfo?[NSWorkspace.applicationUserInfoKey] as? NSRunningApplication else {
            return
        }
        
        log("❌ Application terminated: \(app.localizedName ?? "Unknown") (\(app.bundleIdentifier ?? "no bundle"))")
        
        // Reset cycling if the terminated app was being cycled
        if let bundleID = app.bundleIdentifier, bundleID == currentBundleIDCycling {
            currentBundleIDCycling = nil
            bundleIDCycleIndex = 0
        }
        
        refreshWindows()
    }
    
    @objc private func applicationDidActivate(_ notification: Notification) {
        guard let app = notification.userInfo?[NSWorkspace.applicationUserInfoKey] as? NSRunningApplication else {
            return
        }
        
        log("🎯 Application activated: \(app.localizedName ?? "Unknown") (\(app.bundleIdentifier ?? "no bundle"))")
        
        // Reset cycling if a different app was activated manually
        if let bundleID = app.bundleIdentifier, bundleID != currentBundleIDCycling {
            currentBundleIDCycling = nil
            bundleIDCycleIndex = 0
        }
    }
    
    private func refreshWindows() {
        log("🔄 Refreshing windows...")
        
        // Clear existing window sets
        for i in workspace.screens.indices {
            workspace.screens[i].windowSets.removeAll()
        }
        
        // Rescan windows and rebuild window sets
        let discovered = scanWindows()
        for (win, screen) in discovered {
            if let idx = workspace.screens.firstIndex(where: { $0.screen == screen }) {
                addWindow(win, to: &workspace.screens[idx])
            }
        }
        
        log("✅ Window refresh complete. Total windows: \(discovered.count)")
    }
    
    private func addWindow(_ window: AXWindow, to screenWS: inout ScreenWorkspace) {
        // Create a separate WindowSet for each window to enable cycling
        let newSet = WindowSet(layout: .wide, windows: [window], screenID: screenWS.screen.screenID())
        screenWS.windowSets.append(newSet)
    }
    
    deinit {
        NSWorkspace.shared.notificationCenter.removeObserver(self)
    }
}
