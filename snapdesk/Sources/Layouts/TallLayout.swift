//
//  TallLayout.swift
//  SnapDesk
//
//  Created by Claude on 9/8/25.
//

import Foundation

/// Tall layout: Windows arranged vertically (main window on top, stack below)
class TallLayout: BaseLayout {
    init() {
        super.init(
            id: "tall",
            displayName: "Tall (Vertical Split)",
            description: "Main window on top, stack below"
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
        let totalGapHeight = settings.windowGap * CGFloat(windowCount - 1)
        let availableHeight = frame.height - totalGapHeight
        
        // Calculate window heights with main panel adjustment
        let windowHeights = calculateWindowSizes(
            count: windowCount,
            availableSpace: availableHeight,
            mainPanelAdjustment: settings.mainPanelSizeAdjustment
        )
        
        var currentY = frame.origin.y
        for (index, window) in windows.enumerated() {
            let windowHeight = windowHeights[index]
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
                    isMain: index == 0,
                    unconstrainedDimension: .vertical,
                    scaleFactor: windowHeight / availableHeight
                )
            )
            assignments.append(assignment)
            
            currentY += windowHeight + settings.windowGap
        }
        
        return assignments
    }
}