//
//  HorizontalStackLayout.swift
//  SnapDesk
//
//  Created by Claude on 9/8/25.
//

import Foundation

/// Horizontal Stack layout: Windows arranged in a horizontal stack
class HorizontalStackLayout: BaseLayout {
    
    // Stack layouts don't support panel size adjustment since all windows are equal
    override var supportsPanelSizeAdjustment: Bool { false }
    
    init() {
        super.init(
            id: "horizontal_stack",
            displayName: "Horizontal Stack",
            description: "Windows stacked horizontally with equal width"
        )
    }
    
    override func expandWindows(
        _ windows: [AXWindow],
        in frame: CGRect,
        with settings: LayoutSettings,
        bringToFront: Bool
    ) -> [FrameAssignment<AXWindow>] {
        var assignments: [FrameAssignment<AXWindow>] = []
        
        let windowCount = windows.count
        guard windowCount > 0 else { return assignments }
        
        let totalGapWidth = settings.windowGap * CGFloat(max(0, windowCount - 1))
        let availableWidth = frame.width - totalGapWidth
        
        // Equal width for all windows (ignore mainPanelAdjustment for stack layout)
        let windowWidth = availableWidth / CGFloat(windowCount)
        
        var currentX = frame.origin.x
        for window in windows {
            let windowFrame = CGRect(
                x: currentX,
                y: frame.origin.y,
                width: windowWidth,
                height: frame.height
            )

            let assignment = FrameAssignment<AXWindow>(
                frame: windowFrame,
                windowID: window.id(),
                screenFrame: frame,
                resizeRules: ResizeRules(
                    isMain: false,
                    unconstrainedDimension: .horizontal,
                    scaleFactor: 1.0 / CGFloat(windowCount)
                )
            )
            assignments.append(assignment)

            currentX += windowWidth + settings.windowGap
        }
        
        return assignments
    }
}
