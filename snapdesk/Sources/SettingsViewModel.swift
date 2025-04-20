//
//  SettingsViewModel.swift
//  snapdesk
//
//  Created by Pedro Knup on 20/04/2025.
//

import Foundation

enum SettingsTab {
    case settings
    case shortcuts
    case about
}

class SettingsViewModel: ObservableObject {
    @Published var selectedTab: SettingsTab = .settings
}
