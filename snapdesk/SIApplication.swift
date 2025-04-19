//
//  SIApplication.swift
//  snapdesk
//
//  Created by Pedro Knup on 18/04/2025.
//


extension SIApplication {
    var bundleIdentifier: String? {
        return NSRunningApplication(processIdentifier: pid_t(self.processIdentifier()))?.bundleIdentifier
    }
}
