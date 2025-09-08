//
//  FloatingLayout.swift
//  SnapDesk
//
//  Created by Claude on 9/8/25.
//

import Foundation

/// Floating layout: Windows maintain their current positions and sizes
class FloatingLayout: BaseLayout {
    init() {
        super.init(
            id: "floating",
            displayName: "Floating",
            description: "Windows maintain their current positions and sizes"
        )
    }
    
    override var supportsPanelSizeAdjustment: Bool { false }
    override var supportsGaps: Bool { false }
    override var supportsMargins: Bool { false }
    
    override func expandWindows(
        _ windows: [AXWindow],
        in frame: CGRect,
        with settings: LayoutSettings,
        bringToFront: Bool
    ) -> [FrameAssignment<AXWindow>] {
        // Floating windows maintain their current positions/sizes
        // Return empty assignments array - no changes needed
        return []
    }
}