//
//  SettingsViewModel.swift
//  snapdesk
//
//  Created by Pedro Knup on 20/04/2025.
//

import Foundation

enum SettingsTab: String, CaseIterable {
    case settings, shortcuts, about

    var title: String {
        switch self {
        case .settings: return "Settings"
        case .shortcuts: return "Shortcuts"
        case .about: return "About"
        }
    }

    var icon: String {
        switch self {
        case .settings: return "gearshape"
        case .shortcuts: return "command"
        case .about: return "info.circle"
        }
    }
}

class PreferencesViewModel: ObservableObject {
    @Published var selectedTab: SettingsTab = .settings
}


