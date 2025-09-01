//
//  Untitled.swift
//  snapdesk
//
//  Created by Pedro Knup on 01/09/2025.
//

import AppKit
import HotKey
import Swift

// App cache manager for storing and retrieving cached app list
class AppCacheManager {
    static let shared = AppCacheManager()
    private let cacheKey = "com.snapdesk.cachedApps"
    private let cacheExpiryKey = "com.snapdesk.cachedAppsExpiry"
    private let cacheExpiryInterval: TimeInterval = 24 * 60 * 60 // 24 hours
    
    private init() {}
    
    func getCachedApps() -> [AppInfo]? {
        guard let data = UserDefaults.standard.data(forKey: cacheKey),
              let apps = try? JSONDecoder().decode([AppInfo].self, from: data) else {
            return nil
        }
        
        // Load icons separately for cached apps
        var appsWithIcons = apps
        for (index, app) in appsWithIcons.enumerated() {
            if let appURL = NSWorkspace.shared.urlForApplication(withBundleIdentifier: app.bundleIdentifier) {
                appsWithIcons[index].icon = NSWorkspace.shared.icon(forFile: appURL.path)
            }
        }
        
        return appsWithIcons
    }
    
    func setCachedApps(_ apps: [AppInfo]) {
        if let data = try? JSONEncoder().encode(apps) {
            UserDefaults.standard.set(data, forKey: cacheKey)
            UserDefaults.standard.set(Date(), forKey: cacheExpiryKey)
        }
    }
    
    func isCacheExpired() -> Bool {
        guard let expiryDate = UserDefaults.standard.object(forKey: cacheExpiryKey) as? Date else {
            return true
        }
        return Date().timeIntervalSince(expiryDate) > cacheExpiryInterval
    }
    
    func clearCache() {
        UserDefaults.standard.removeObject(forKey: cacheKey)
        UserDefaults.standard.removeObject(forKey: cacheExpiryKey)
    }
}
