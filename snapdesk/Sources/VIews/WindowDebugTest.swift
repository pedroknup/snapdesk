import Foundation
import Silica

func log(_ message: String) {
    let path = "/tmp/snapdesk.log"
    let entry = message + "\n"
    if let data = entry.data(using: .utf8) {
        if FileManager.default.fileExists(atPath: path) {
            if let handle = try? FileHandle(forWritingTo: URL(fileURLWithPath: path)) {
                handle.seekToEndOfFile()
                handle.write(data)
                handle.closeFile()
            }
        } else {
            try? data.write(to: URL(fileURLWithPath: path))
        }
    }
    print(message)
}

class WindowDebugTest {
    func run() {
        log("🔍 Listing visible windows...\n")

        guard let anyApps = SIApplication.runningApplications() else {
            log("❌ No applications found [SDL]")
            return
        }
        
        let apps = anyApps.compactMap { $0 as? SIApplication }

        for app in apps {
            let appName = app.title() ?? "Unknown App"

            for window in app.windows() {
//                guard window.isWindowMinimized(),
//                      !window.isNormalWindow(),
//                      window.frame().size.width > 0,
//                      window.frame().size.height > 0 else {
//                    continue
//                }
//                guard
//                      window.isNormalWindow() else {
//                    continue
//                }

                let title = window.title() ?? "Untitled"
                let id = window.windowID()
                let frame = window.frame()
                let position = frame.origin
                let size = frame.size

                log("""
                🪟 [SDL] Window:
                  App: \(appName)
                  Title: \(title)
                  ID: \(id)
                  Position: (x: \(Int(position.x)), y: \(Int(position.y)))
                  Size: (w: \(Int(size.width)), h: \(Int(size.height)))
                """)
            }
        }
    }
}
