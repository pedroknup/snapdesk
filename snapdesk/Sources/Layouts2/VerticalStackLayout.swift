//
//  VerticalStackLayout.swift
//  SnapDesk
//
//  Created by Claude on 9/8/25.
//

import Foundation

/// Vertical Stack layout: Windows arranged in a vertical stack
class VerticalStackLayout: BaseLayout {
    
    // Stack layouts don't support panel size adjustment since all windows are equal
    override var supportsPanelSizeAdjustment: Bool { false }
    
    init() {
        super.init(
            id: "vertical_stack",
            displayName: "Vertical Stack",
            description: "Windows stacked vertically with equal height"
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
        
        let totalGapHeight = settings.windowGap * CGFloat(max(0, windowCount - 1))
        let availableHeight = frame.height - totalGapHeight
        
        // Equal height for all windows (ignore mainPanelAdjustment for stack layout)
        let windowHeight = availableHeight / CGFloat(windowCount)
        
        var currentY = frame.origin.y
        for (index, window) in windows.enumerated() {
            let windowFrame = CGRect(
                x: frame.origin.x + settings.windowMargin,
                y: currentY + settings.windowMargin,
                width: frame.width - (settings.windowMargin * 2),
                height: windowHeight - (settings.windowMargin * 2)
            )
            
            let assignment = FrameAssignment<AXWindow>(
                frame: windowFrame,
                windowID: window.id(),
                screenFrame: frame,
                resizeRules: ResizeRules(
                    isMain: false,  // No main window in stack layout
                    unconstrainedDimension: .vertical,
                    scaleFactor: 1.0 / CGFloat(windowCount)
                )
            )
            assignments.append(assignment)
            
            currentY += windowHeight + settings.windowGap
        }
        
        return assignments
    }
}