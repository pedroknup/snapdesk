//
//  ConfigurationHelper.swift
//  snapdesk
//
//  Created by Pedro Knup on 11/09/2025.
//

import Foundation
import AppKit

// MARK: - Configuration Helper

class ConfigurationHelper {
    static let shared = ConfigurationHelper()
    
    private init() {}
    
    // MARK: - Layout Configuration
    
    func getDefaultLayoutMode() -> LayoutKind {
        let defaultMode = UserDefaults.standard.string(forKey: "defaultLayoutMode") ?? "wide"
        return LayoutKind.from(string: defaultMode)
    }
    
    func setDefaultLayoutMode(_ layout: LayoutKind) {
        UserDefaults.standard.set(layout.toString(), forKey: "defaultLayoutMode")
    }
    
    // MARK: - Window Behavior Configuration
    
    func shouldAutoExpandNewWindows() -> Bool {
        return UserDefaults.standard.bool(forKey: "autoExpandNewWindows")
    }
    
    func setShouldAutoExpandNewWindows(_ value: Bool) {
        UserDefaults.standard.set(value, forKey: "autoExpandNewWindows")
    }
    
    func shouldAnimateWindowTransitions() -> Bool {
        return UserDefaults.standard.bool(forKey: "animateWindowTransitions")
    }
    
    func setShouldAnimateWindowTransitions(_ value: Bool) {
        UserDefaults.standard.set(value, forKey: "animateWindowTransitions")
    }
    
    func shouldRespectWindowMinimumSize() -> Bool {
        return UserDefaults.standard.bool(forKey: "respectWindowMinimumSize")
    }
    
    func setShouldRespectWindowMinimumSize(_ value: Bool) {
        UserDefaults.standard.set(value, forKey: "respectWindowMinimumSize")
    }
    
    // MARK: - Visual Feedback Configuration
    
    func shouldShowLayoutIndicator() -> Bool {
        return UserDefaults.standard.bool(forKey: "showLayoutIndicator")
    }
    
    func setShouldShowLayoutIndicator(_ value: Bool) {
        UserDefaults.standard.set(value, forKey: "showLayoutIndicator")
    }
    
    func shouldShowAllLayoutsOnToggle() -> Bool {
        return UserDefaults.standard.bool(forKey: "show-all-layouts-on-toggle")
    }
    
    func setShouldShowAllLayoutsOnToggle(_ value: Bool) {
        UserDefaults.standard.set(value, forKey: "show-all-layouts-on-toggle")
    }
    
    func shouldShowThrowNotifications() -> Bool {
        return UserDefaults.standard.bool(forKey: "showThrowNotifications")
    }
    
    func setShouldShowThrowNotifications(_ value: Bool) {
        UserDefaults.standard.set(value, forKey: "showThrowNotifications")
    }
    
    func getNotificationDuration() -> Double {
        let duration = UserDefaults.standard.double(forKey: "notificationDuration")
        return duration > 0 ? duration : 1.5
    }
    
    func setNotificationDuration(_ duration: Double) {
        UserDefaults.standard.set(duration, forKey: "notificationDuration")
    }
    
    // MARK: - Spacing Configuration
    
    func getWindowGap() -> CGFloat {
        return CGFloat(UserDefaults.standard.double(forKey: "windowGap"))
    }
    
    func setWindowGap(_ gap: CGFloat) {
        UserDefaults.standard.set(Double(gap), forKey: "windowGap")
    }
    
    func getWindowMargin() -> CGFloat {
        return CGFloat(UserDefaults.standard.double(forKey: "windowMargin"))
    }
    
    func setWindowMargin(_ margin: CGFloat) {
        UserDefaults.standard.set(Double(margin), forKey: "windowMargin")
    }
    
    // MARK: - System Behavior Configuration
    
    func shouldLaunchAtLogin() -> Bool {
        return UserDefaults.standard.bool(forKey: "launchAtLogin")
    }
    
    func setShouldLaunchAtLogin(_ value: Bool) {
        UserDefaults.standard.set(value, forKey: "launchAtLogin")
        UserConfiguration.shared.setLaunchAtLogin(value)
    }
    
    func shouldHideMenuBarIcon() -> Bool {
        return UserDefaults.standard.bool(forKey: "hideMenuBarIcon")
    }
    
    func setShouldHideMenuBarIcon(_ value: Bool) {
        UserDefaults.standard.set(value, forKey: "hideMenuBarIcon")
    }
    
    func shouldFocusFollowMouse() -> Bool {
        return UserDefaults.standard.bool(forKey: "focusFollowsMouse")
    }
    
    func setShouldFocusFollowMouse(_ value: Bool) {
        UserDefaults.standard.set(value, forKey: "focusFollowsMouse")
    }
    
    // MARK: - Debug and Development Configuration
    
    func shouldEnableDebugLogging() -> Bool {
        return UserDefaults.standard.bool(forKey: "enableDebugLogging")
    }
    
    func setShouldEnableDebugLogging(_ value: Bool) {
        UserDefaults.standard.set(value, forKey: "enableDebugLogging")
    }
    
    func shouldShowLogsView() -> Bool {
        return UserDefaults.standard.bool(forKey: "showLogsView")
    }
    
    func setShouldShowLogsView(_ value: Bool) {
        UserDefaults.standard.set(value, forKey: "showLogsView")
    }
    
    func getWindowDetectionInterval() -> Double {
        let interval = UserDefaults.standard.double(forKey: "windowDetectionInterval")
        return interval > 0 ? interval : 0.5
    }
    
    func setWindowDetectionInterval(_ interval: Double) {
        UserDefaults.standard.set(interval, forKey: "windowDetectionInterval")
    }
    
    // MARK: - Shortcut Configuration
    
    func getShortcutConfiguration() -> Config? {
        return ConfigurationManager.shared.loadConfig()
    }
    
    func saveShortcutConfiguration(_ config: Config) throws {
        try ConfigurationManager.shared.saveConfig(config)
    }
    
    func getDefaultShortcutConfiguration() -> Config {
        return ConfigurationManager.shared.getDefaultConfig()
    }
    
    // MARK: - Bundle ID Utilities
    
    func getApplicationsWithShortcuts() -> Set<String> {
        guard let config = getShortcutConfiguration() else {
            return Set()
        }
        
        return Set(config.appShortcuts.compactMap { appShortcut in
            appShortcut.shortcut != nil ? appShortcut.bundleIdentifier : nil
        })
    }
    
    func hasShortcutsAssigned(for bundleID: String) -> Bool {
        guard let config = getShortcutConfiguration() else {
            return false
        }
        
        return config.appShortcuts.contains { appShortcut in
            appShortcut.bundleIdentifier == bundleID && appShortcut.shortcut != nil
        }
    }
    
    // MARK: - Configuration Validation
    
    func validateConfiguration() -> [String] {
        var issues: [String] = []
        
        // Check if accessibility is enabled
        let isAccessibilityEnabled = AXIsProcessTrusted()
        if !isAccessibilityEnabled {
            issues.append("Accessibility permissions not granted")
        }
        
        // Check if configuration file is readable
        if getShortcutConfiguration() == nil {
            issues.append("Cannot load shortcut configuration")
        }
        
        // Check for reasonable values
        let detectionInterval = getWindowDetectionInterval()
        if detectionInterval < 0.1 || detectionInterval > 10.0 {
            issues.append("Window detection interval out of reasonable range (0.1-10.0s)")
        }
        
        let notificationDuration = getNotificationDuration()
        if notificationDuration < 0.5 || notificationDuration > 10.0 {
            issues.append("Notification duration out of reasonable range (0.5-10.0s)")
        }
        
        return issues
    }
    
    // MARK: - Configuration Reset
    
    func resetToDefaults() {
        let defaults = UserDefaults.standard
        
        // Remove all SnapDesk-related preferences
        let snapdeskKeys = [
            "defaultLayoutMode",
            "autoExpandNewWindows",
            "animateWindowTransitions",
            "respectWindowMinimumSize",
            "showLayoutIndicator",
            "show-all-layouts-on-toggle",
            "showThrowNotifications",
            "notificationDuration",
            "windowGap",
            "windowMargin",
            "launchAtLogin",
            "hideMenuBarIcon",
            "focusFollowsMouse",
            "enableDebugLogging",
            "showLogsView",
            "windowDetectionInterval"
        ]
        
        for key in snapdeskKeys {
            defaults.removeObject(forKey: key)
        }
        
        // Reset configuration file to defaults
        let defaultConfig = getDefaultShortcutConfiguration()
        try? saveShortcutConfiguration(defaultConfig)
        
        log("Configuration reset to defaults")
    }
}