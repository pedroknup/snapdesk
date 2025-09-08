//
//  BaseLayout.swift
//  SnapDesk
//
//  Created by Claude on 9/8/25.
//

import Foundation

// MARK: - Base Layout Implementation

/// Base class for built-in layouts with common functionality
class BaseLayout: LayoutEngine {
    let id: String
    let displayName: String
    let description: String
    
    init(id: String, displayName: String, description: String) {
        self.id = id
        self.displayName = displayName
        self.description = description
    }
    
    // Default implementations
    var supportsPanelSizeAdjustment: Bool { true }
    var supportsGaps: Bool { true }
    var supportsMargins: Bool { true }
    var requiresMinimumWindows: Int { 1 }
    var maximumWindows: Int? { nil }
    
    func initialize() {}
    func cleanup() {}
    
    // Subclasses must implement this
    func expandWindows(
        _ windows: [AXWindow],
        in frame: CGRect,
        with settings: LayoutSettings,
        bringToFront: Bool
    ) -> [FrameAssignment<AXWindow>] {
        fatalError("Subclasses must implement expandWindows")
    }
    
    // Helper method for common layout calculations
    func calculateWindowSizes(
        count: Int,
        availableSpace: CGFloat,
        mainPanelAdjustment: CGFloat
    ) -> [CGFloat] {
        if count == 1 {
            return [availableSpace]
        }
        
        let baseSize = availableSpace / CGFloat(count)
        let adjustmentPerOther = mainPanelAdjustment / CGFloat(count - 1)
        
        var sizes = [baseSize + mainPanelAdjustment]
        for _ in 1..<count {
            sizes.append(baseSize - adjustmentPerOther)
        }
        
        return sizes
    }
}