//
//  FullscreenLayout.swift
//  SnapDesk
//
//  Created by Claude on 9/8/25.
//

import Foundation

/// Fullscreen layout: All windows take up the entire screen
class FullscreenLayout: BaseLayout {
    init() {
        super.init(
            id: "fullscreen",
            displayName: "Fullscreen",
            description: "All windows take up the entire screen"
        )
    }
    
    override var supportsPanelSizeAdjustment: Bool { false }
    override var supportsGaps: Bool { false }
    
    override func expandWindows(
        _ windows: [AXWindow],
        in frame: CGRect,
        with settings: LayoutSettings,
        bringToFront: Bool
    ) -> [FrameAssignment<AXWindow>] {
        var assignments: [FrameAssignment<AXWindow>] = []
        
        let fullscreenFrame = CGRect(
            x: frame.origin.x + settings.windowMargin,
            y: frame.origin.y + settings.windowMargin,
            width: frame.width - (settings.windowMargin * 2),
            height: frame.height - (settings.windowMargin * 2)
        )
        
        for window in windows {
            let assignment = FrameAssignment<AXWindow>(
                frame: fullscreenFrame,
                windowID: window.id(),
                screenFrame: frame,
                resizeRules: ResizeRules(
                    isMain: true,
                    unconstrainedDimension: .horizontal,
                    scaleFactor: 1.0
                )
            )
            assignments.append(assignment)
        }
        
        return assignments
    }
}