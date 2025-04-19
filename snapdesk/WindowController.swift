//
//  WindowController.swift
//  snapdesk
//
//  Created by Pedro Knup on 18/04/2025.
//

class WindowController {
    private var appWindows: [String: [SIWindow]] = [:] // BundleID → windows
    private var currentWindowPerApp: [String: Int] = [:] // BundleID → index
    // Maps AXUIElement to NSScreen
    private var windowScreenMap: [AXUIElement: NSScreen] = [:]

    // Each app gets assigned to a "layout group" by ID
    private var layoutGroups: [String: [String]] = [:]
    // groupID → array of bundle IDs in the layout (order = z-order)
    private(set) var currentlyFocusedWindow: SIWindow?
    var observers: [AXObserver] = []

    // Reverse mapping: app bundleID → groupID it's part of
    private var appToGroup: [String: String] = [:]
    
    init() {
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
             self.scanAndTrackWindows()
         }
    }
    
    func screenForWindow(_ window: SIWindow) -> NSScreen? {
        let element = window.axElement().takeUnretainedValue()
        return windowScreenMap[element]
    }
    
    func prettyPrintWindows(_ appWindows: [String: [SIWindow]]) -> String {
        var output = "\n🪟 Window Summary:\n"


        for (bundleID, windows) in appWindows {
            output += "\n📦 App: \(bundleID)\n"

            for (index, window) in windows.enumerated() {
                let title = window.title() ?? "<No Title>"
                let pid = window.processIdentifier()
                let screen = screenForWindow(window)?.frame ?? .zero
                output += "   \(index + 1). \"\(title)\" (pid: \(pid)) on screen x:\(Int(screen.origin.x))\n"
            }
        }

        return output
    }


    func scanAndTrackWindows() {
        guard let apps = SIApplication.runningApplications() as? [SIApplication] else { return }

        var updated: [String: [SIWindow]] = [:]
        
        for app in SIApplication.runningApplications() as? [SIApplication] ?? [] {
            let element = app.axElementRef
            var value: CFTypeRef?
            let result = AXUIElementCopyAttributeValue(element, kAXWindowsAttribute as CFString, &value)
            
            log("AX result for \(app.title() ?? "Unknown"): \(result.rawValue)")
        }

        for app in apps {
            guard let bundleID = app.bundleIdentifier else { continue }
            let windows = app.windows()
//                .filter {
////                $0.isStandard() &&
//                $0.frame().width > 0 &&
//                $0.frame().height > 0
            //}

            if !windows.isEmpty {
                updated[bundleID] = windows
                
                
                for window in windows {
                    let windowFrame = window.frame()
                    if let screen = NSScreen.screens.first(where: { $0.frame.intersects(windowFrame) }) {
                        let element = window.axElement().takeUnretainedValue()
                        windowScreenMap[element] = screen
                    }
                }
            }
        }

        appWindows = updated
        log(prettyPrintWindows(updated))
    }


    func focusApp(_ bundleID: String) {
        log("to focus \(bundleID) \(appWindows[bundleID] ?? [])")
        
        if let groupID = appToGroup[bundleID] {
              applyLayout(groupID: groupID)
              return
          }
        
        guard let windows = appWindows[bundleID], !windows.isEmpty else {
            launchAppIfNeeded(bundleID)
            return
        }

        let currentIndex = currentWindowPerApp[bundleID] ?? 0
        let window = windows[currentIndex]

        // Cycle to next on repeated key press
        currentWindowPerApp[bundleID] = (currentIndex + 1) % windows.count

        // Hide all others *before* we focus/maximize the target window
        hideAllWindows(except: window)

        // Focus & maximize
        window.focus()
        maximize(window: window)
        
        log("✅ Focused window: \(window.title() ?? "<No Title>") for \(bundleID)")
    }


    func hideAllWindows(except visibleWindow: SIWindow?) {
        log("🔒 Hiding all windows except: \(visibleWindow?.title() ?? "<none>")")
        
        for (_, windows) in appWindows {
            for window in windows {
                guard window != visibleWindow else { continue }
                
                // Hide using AXHidden attribute
                let axElement = window.axElement().takeUnretainedValue()
                let hidden: CFTypeRef = kCFBooleanTrue
                let result = AXUIElementSetAttributeValue(axElement, kAXHiddenAttribute as CFString, hidden)

                if result != .success {
                    log("⚠️ Failed to hide window: \(window.title() ?? "<no title>")")
                }
            }
        }
    }


    func launchAppIfNeeded(_ bundleID: String) {
        let ws = NSWorkspace.shared
        log("🚀 Launching app \(bundleID)")

        guard !ws.runningApplications.contains(where: { $0.bundleIdentifier == bundleID }) else {
            log("✅ App already running: \(bundleID)")
            return
        }

        guard let url = NSWorkspace.shared.urlForApplication(withBundleIdentifier: bundleID) else {
            log("❌ Could not find app URL for bundle ID: \(bundleID)")
            return
        }

        let config = NSWorkspace.OpenConfiguration()
        config.activates = true

        ws.openApplication(at: url, configuration: config) { app, error in
            if let error = error {
                log("❌ Failed to launch app: \(error)")
            } else {
                log("✅ App launched: \(bundleID)")
            }
        }
    }
    
    private func maximize(window: SIWindow) {
            guard let screen = NSScreen.screens.first(where: {
                $0.frame.intersects(window.frame())
            }) else { return }

            let screenFrame = screen.visibleFrame

           let position = CGPoint(x: screenFrame.origin.x, y: screenFrame.origin.y)
           let size = CGSize(width: screenFrame.width, height: screenFrame.height)

           window.setPosition(position)
           window.setSize(size)
   }
    
    func getCurrentFocusedWindow() -> SIWindow? {
        for windows in appWindows.values {
            for window in windows {
                if window.isFocused() {
                    return window
                }
            }
        }
        log("❌ No focused window found")
        return nil
    }

    
    func addAppToSplit(_ newAppBundleID: String) {
        guard let currentWindow = getCurrentFocusedWindow() else {
            log("❌ No focused window found")
            return
        }

        // Get the bundle ID of the app owning this window
        var currentBundleID: String?
        for (bundleID, windows) in appWindows {
            if windows.contains(where: { $0 == currentWindow }) {
                currentBundleID = bundleID
                break
            }
        }

        guard let currentBundleID = currentBundleID else {
            log("❌ Could not determine bundle ID for current window")
            return
        }
        
        // Determine group ID
        let groupID = appToGroup[currentBundleID] ?? UUID().uuidString


        // Register apps to group
        layoutGroups[groupID, default: []].removeAll(where: { $0 == newAppBundleID }) // Avoid duplicates
        layoutGroups[groupID, default: []].append(newAppBundleID)
        appToGroup[currentBundleID] = groupID
        appToGroup[newAppBundleID] = groupID

        applyLayout(groupID: groupID)
    }
    
    func applyLayout(groupID: String) {
        guard let bundleIDs = layoutGroups[groupID], !bundleIDs.isEmpty else { return }

        let screen = NSScreen.main ?? NSScreen.screens.first!
        let screenFrame = screen.visibleFrame
        let count = CGFloat(bundleIDs.count)
        let widthPerApp = screenFrame.width / count

        for (index, bundleID) in bundleIDs.enumerated() {
            guard let windows = appWindows[bundleID], !windows.isEmpty else { continue }
            let window = windows.first!

            let frame = CGRect(x: screenFrame.origin.x + (widthPerApp * CGFloat(index)),
                               y: screenFrame.origin.y,
                               width: widthPerApp,
                               height: screenFrame.height)

            try? window.setFrame(frame)
            window.focus()
        }
    }
}
