//
//  WideLayout.swift
//  SnapDesk
//
//  Created by Claude on 9/8/25.
//

import Foundation

/// Wide layout: Windows arranged horizontally (main window on left, stack on right)
class WideLayout: BaseLayout {
    init() {
        super.init(
            id: "wide",
            displayName: "Wide (Horizontal Split)",
            description: "Main window on left, stack on right"
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
        let totalGapWidth = settings.windowGap * CGFloat(windowCount - 1)
        let availableWidth = frame.width - totalGapWidth
        
        // Calculate window widths with main panel adjustment
        let windowWidths = calculateWindowSizes(
            count: windowCount,
            availableSpace: availableWidth,
            mainPanelAdjustment: settings.mainPanelSizeAdjustment
        )
        
        var currentX = frame.origin.x
        for (index, window) in windows.enumerated() {
            let windowWidth = windowWidths[index]
            let windowFrame = CGRect(
                x: currentX + settings.windowMargin,
                y: frame.origin.y + settings.windowMargin,
                width: windowWidth - (settings.windowMargin * 2),
                height: frame.height - (settings.windowMargin * 2)
            )
            
            let assignment = FrameAssignment<AXWindow>(
                frame: windowFrame,
                windowID: window.id(),
                screenFrame: frame,
                resizeRules: ResizeRules(
                    isMain: index == 0,
                    unconstrainedDimension: .horizontal,
                    scaleFactor: windowWidth / availableWidth
                )
            )
            assignments.append(assignment)
            
            currentX += windowWidth + settings.windowGap
        }
        
        return assignments
    }
}