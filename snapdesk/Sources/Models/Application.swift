//
//  Application.swift
//  snapdesk
//
//  Originally derived from Amethyst by Ian Ynda-Hummel
//  Modified by Pedro Knup for SnapDesk
//

import Foundation
import Silica

/// Wrapper around SIApplication for managing application windows
extension SIApplication {
    /// `SIApplication` uses `AXWindow` as its window type.
    typealias Window = AXWindow

    convenience init?(pid: pid_t) {
        guard let runningApplication = NSRunningApplication(processIdentifier: pid) else {
            return nil
        }

        self.init(runningApplication: runningApplication)
    }

    func snapWindows() -> [Window] {
        let axWindows: [SIWindow] = self.windows()
        return axWindows.map { Window(axElement: $0.axElementRef) }
    }

    func pid() -> pid_t {
        return processIdentifier()
    }
}
