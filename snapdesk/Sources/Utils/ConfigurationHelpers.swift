//
//  ConfigurationHelpers.swift
//  snapdesk
//
//  Created by Pedro Knup on 21/11/2025.
//

import Foundation

enum ConfigurationHelpers {
    /// Gets the default layout mode from settings
    static func getDefaultLayoutMode() -> LayoutKind {
        let defaultLayoutString = UserDefaults.standard.string(forKey: "defaultLayoutMode") ?? "wide"

        switch defaultLayoutString.lowercased() {
        case "tall":
            return .tall
        case "fullscreen":
            return .fullscreen
        case "floating":
            return .floating
        default:
            return .wide
        }
    }

    /// Gets whether auto-expand new windows is enabled
    static func shouldAutoExpandNewWindows() -> Bool {
        return UserDefaults.standard.object(forKey: "autoExpandNewWindows") as? Bool ?? true
    }
}
