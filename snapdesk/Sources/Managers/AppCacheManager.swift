//
//  AppCacheManager.swift
//  snapdesk
//
//  Created by Pedro Knup on 01/09/2025.
//

import AppKit
import HotKey
import Swift

// Callback types for async operations
typealias AppListUpdateCallback = ([AppInfo]) -> Void
typealias ErrorCallback = (Error) -> Void

// Cache strategy enum
enum CacheStrategy {
    case cacheFirst      // Return cache immediately, then update in background
    case networkFirst    // Fetch fresh data, fall back to cache on error
    case cacheOnly       // Return only cached data
    case networkOnly     // Always fetch fresh data
}

// Enhanced app cache manager with background fetching and smart caching
class AppCacheManager {
    static let shared = AppCacheManager()
    
    // Cache configuration
    private let cacheKey = "com.snapdesk.cachedApps"
    private let cacheExpiryKey = "com.snapdesk.cachedAppsExpiry"
    private let cacheExpiryInterval: TimeInterval = 6 * 60 * 60 // 6 hours (reduced for more frequent updates)
    
    // Background queue for app fetching
    private let backgroundQueue = DispatchQueue(label: "com.snapdesk.appcache", qos: .utility)
    
    // In-memory cache for fast access
    private var memoryCache: [AppInfo]?
    private var memoryCacheTimestamp: Date?
    private let memoryCacheTimeout: TimeInterval = 5 * 60 // 5 minutes
    
    // Track ongoing fetches to prevent duplicates
    private var isFetching = false
    private var fetchCallbacks: [AppListUpdateCallback] = []
    
    private init() {}
    
    // MARK: - Public API
    
    /// Get applications using specified cache strategy
    func getApplications(strategy: CacheStrategy = .cacheFirst, 
                        onUpdate: @escaping AppListUpdateCallback,
                        onError: ErrorCallback? = nil) {
        
        switch strategy {
        case .cacheFirst:
            getCacheFirst(onUpdate: onUpdate, onError: onError)
        case .networkFirst:
            getNetworkFirst(onUpdate: onUpdate, onError: onError)
        case .cacheOnly:
            getCacheOnly(onUpdate: onUpdate, onError: onError)
        case .networkOnly:
            getNetworkOnly(onUpdate: onUpdate, onError: onError)
        }
    }
    
    /// Get applications synchronously (returns cache if available)
    func getApplicationsSync() -> [AppInfo] {
        // Try memory cache first
        if let memoryCache = getMemoryCache() {
            return memoryCache
        }
        
        // Fall back to disk cache
        return getCachedApps() ?? []
    }
    
    /// Force refresh the application list
    func refreshApplications(onUpdate: @escaping AppListUpdateCallback, onError: ErrorCallback? = nil) {
        getNetworkOnly(onUpdate: onUpdate, onError: onError)
    }
    
    /// Check if we have valid cached data
    func hasValidCache() -> Bool {
        return !isCacheExpired() && (getMemoryCache() != nil || getCachedApps() != nil)
    }
    
    // MARK: - Cache Strategy Implementations
    
    private func getCacheFirst(onUpdate: @escaping AppListUpdateCallback, onError: ErrorCallback?) {
        // Return cache immediately if available
        if let cached = getMemoryCache() ?? getCachedApps() {
            DispatchQueue.main.async {
                onUpdate(cached)
            }
        }
        
        // Always fetch fresh data in background if cache is expired or memory cache is stale
        if isCacheExpired() || isMemoryCacheStale() {
            fetchFreshApplications(onUpdate: onUpdate, onError: onError)
        }
    }
    
    private func getNetworkFirst(onUpdate: @escaping AppListUpdateCallback, onError: ErrorCallback?) {
        fetchFreshApplications(onUpdate: { freshApps in
            onUpdate(freshApps)
        }, onError: { error in
            // Fall back to cache on error
            if let cached = self.getMemoryCache() ?? self.getCachedApps() {
                DispatchQueue.main.async {
                    onUpdate(cached)
                }
            } else {
                onError?(error)
            }
        })
    }
    
    private func getCacheOnly(onUpdate: @escaping AppListUpdateCallback, onError: ErrorCallback?) {
        if let cached = getMemoryCache() ?? getCachedApps() {
            DispatchQueue.main.async {
                onUpdate(cached)
            }
        } else {
            onError?(CacheError.noCache)
        }
    }
    
    private func getNetworkOnly(onUpdate: @escaping AppListUpdateCallback, onError: ErrorCallback?) {
        fetchFreshApplications(onUpdate: onUpdate, onError: onError)
    }
    
    // MARK: - Memory Cache Management
    
    private func getMemoryCache() -> [AppInfo]? {
        guard let cache = memoryCache,
              let timestamp = memoryCacheTimestamp,
              Date().timeIntervalSince(timestamp) < memoryCacheTimeout else {
            return nil
        }
        return cache
    }
    
    private func setMemoryCache(_ apps: [AppInfo]) {
        memoryCache = apps
        memoryCacheTimestamp = Date()
    }
    
    private func isMemoryCacheStale() -> Bool {
        guard let timestamp = memoryCacheTimestamp else { return true }
        return Date().timeIntervalSince(timestamp) > memoryCacheTimeout
    }
    
    // MARK: - Background Fetching
    
    private func fetchFreshApplications(onUpdate: @escaping AppListUpdateCallback, onError: ErrorCallback?) {
        // Add callback to queue
        fetchCallbacks.append(onUpdate)
        
        // If already fetching, just wait for result
        guard !isFetching else { return }
        
        isFetching = true
        
        backgroundQueue.async { [weak self] in
            guard let self = self else { return }
            
            do {
                let apps = try self.fetchApplicationsFromSystem()
                
                // Update caches
                self.setMemoryCache(apps)
                self.setCachedApps(apps)
                
                // Notify all callbacks
                DispatchQueue.main.async {
                    let callbacks = self.fetchCallbacks
                    self.fetchCallbacks.removeAll()
                    self.isFetching = false
                    
                    callbacks.forEach { callback in
                        callback(apps)
                    }
                }
                
            } catch {
                DispatchQueue.main.async {
                    let callbacks = self.fetchCallbacks
                    self.fetchCallbacks.removeAll()
                    self.isFetching = false
                    
                    callbacks.forEach { _ in
                        onError?(error)
                    }
                }
            }
        }
    }
    
    private func fetchApplicationsFromSystem() throws -> [AppInfo] {
        let workspace = NSWorkspace.shared
        let runningApps = workspace.runningApplications
        let allApps = runningApps.compactMap { app -> AppInfo? in
            guard let bundleIdentifier = app.bundleIdentifier,
                  let localizedName = app.localizedName,
                  app.activationPolicy == .regular else {
                return nil
            }
            
            // Get app icon
            var icon: NSImage?
            if let appURL = workspace.urlForApplication(withBundleIdentifier: bundleIdentifier) {
                icon = workspace.icon(forFile: appURL.path)
            }
            
            return AppInfo(
                name: localizedName,
                bundleIdentifier: bundleIdentifier,
                icon: icon
            )
        }
        
        // Sort apps alphabetically for consistent ordering
        return allApps.sorted { $0.name.localizedCaseInsensitiveCompare($1.name) == .orderedAscending }
    }
    
    // MARK: - Legacy Disk Cache Methods
    
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
        memoryCache = nil
        memoryCacheTimestamp = nil
    }
}

// MARK: - Error Types

enum CacheError: Error, LocalizedError {
    case noCache
    case fetchFailed
    
    var errorDescription: String? {
        switch self {
        case .noCache:
            return "No cached data available"
        case .fetchFailed:
            return "Failed to fetch fresh application data"
        }
    }
}
