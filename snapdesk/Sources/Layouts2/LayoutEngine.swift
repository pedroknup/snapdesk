//
//  LayoutEngine.swift
//  SnapDesk
//
//  Created by Claude on 9/8/25.
//

import Foundation

// MARK: - Layout Plugin Architecture

/// Protocol for pluggable layout engines
protocol LayoutEngine {
    // Metadata
    var id: String { get }
    var displayName: String { get }
    var description: String { get }
    
    // Layout behavior
    func expandWindows(
        _ windows: [AXWindow],
        in frame: CGRect,
        with settings: LayoutSettings,
        bringToFront: Bool
    ) -> [FrameAssignment<AXWindow>]
    
    // Configuration capabilities
    var supportsPanelSizeAdjustment: Bool { get }
    var supportsGaps: Bool { get }
    var supportsMargins: Bool { get }
    var requiresMinimumWindows: Int { get }
    var maximumWindows: Int? { get }
    
    // Plugin lifecycle
    func initialize()
    func cleanup()
}

/// Settings passed to layout engines
struct LayoutSettings {
    let windowGap: CGFloat
    let windowMargin: CGFloat
    let mainPanelSizeAdjustment: CGFloat
    let customSettings: [String: Any]
    
    init(
        windowGap: CGFloat = 0,
        windowMargin: CGFloat = 0, 
        mainPanelSizeAdjustment: CGFloat = 0,
        customSettings: [String: Any] = [:]
    ) {
        self.windowGap = windowGap
        self.windowMargin = windowMargin
        self.mainPanelSizeAdjustment = mainPanelSizeAdjustment
        self.customSettings = customSettings
    }
}

/// Registry for managing layout engines
class LayoutRegistry {
    static let shared = LayoutRegistry()
    private var registeredLayouts: [String: LayoutEngine] = [:]
    
    private init() {
        loadBuiltInLayouts()
    }
    
    func register(_ layout: LayoutEngine) {
        layout.initialize()
        registeredLayouts[layout.id] = layout
    }
    
    func unregister(id: String) {
        if let layout = registeredLayouts[id] {
            layout.cleanup()
            registeredLayouts.removeValue(forKey: id)
        }
    }
    
    func layout(for id: String) -> LayoutEngine? {
        return registeredLayouts[id]
    }
    
    func availableLayouts() -> [LayoutEngine] {
        return Array(registeredLayouts.values)
    }
    
    private func loadBuiltInLayouts() {
        // Built-in layouts will be registered here
        register(TallLayout())
        register(WideLayout())
        register(FullscreenLayout())
        register(FloatingLayout())
    }
}