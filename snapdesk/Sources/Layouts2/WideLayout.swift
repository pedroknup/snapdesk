//
//  WideLayout.swift
//  SnapDesk
//
//  Created by Claude on 9/8/25.
//

import Foundation

/// Wide layout: Main pane on left, secondary pane on right (fibonacci-style)
class WideLayout: BaseLayout {
    init() {
        super.init(
            id: "wide",
            displayName: "Wide",
            description: "Main pane on left, secondary pane on right"
        )
    }
    
    override func expandWindows(
        _ windows: [AXWindow],
        in frame: CGRect,
        with settings: LayoutSettings,
        bringToFront: Bool
    ) -> [FrameAssignment<AXWindow>] {
        guard !windows.isEmpty else { return [] }
        
        var assignments: [FrameAssignment<AXWindow>] = []
        
        if windows.count == 1 {
            // Single window takes full space
            assignments.append(FrameAssignment<AXWindow>(
                frame: frame,
                windowID: windows[0].id(),
                screenFrame: frame,
                resizeRules: ResizeRules(
                    isMain: true,
                    unconstrainedDimension: .horizontal,
                    scaleFactor: 1.0
                )
            ))
        } else {
            // Main pane on left, secondary pane on right
            let paneGap = settings.windowGap
            let availableWidth = frame.width - paneGap

            // Main pane gets 50% by default, adjusted by mainPanelSizeAdjustment
            let baseMainWidth = availableWidth * 0.5
            let mainWidth = max(100, baseMainWidth + settings.mainPanelSizeAdjustment)
            let secondaryWidth = availableWidth - mainWidth

            // Main pane (single window)
            let mainFrame = CGRect(
                x: frame.origin.x,
                y: frame.origin.y,
                width: mainWidth,
                height: frame.height
            )

            assignments.append(FrameAssignment<AXWindow>(
                frame: mainFrame,
                windowID: windows[0].id(),
                screenFrame: frame,
                resizeRules: ResizeRules(
                    isMain: true,
                    unconstrainedDimension: .horizontal,
                    scaleFactor: mainWidth / availableWidth
                )
            ))

            // Secondary pane (remaining windows stacked horizontally)
            let secondaryWindows = Array(windows.dropFirst())
            let secondaryWindowCount = secondaryWindows.count
            let secondaryWindowGaps = settings.windowGap * CGFloat(max(0, secondaryWindowCount - 1))
            let availableSecondaryWidth = secondaryWidth - secondaryWindowGaps
            let secondaryWindowWidth = availableSecondaryWidth / CGFloat(secondaryWindowCount)

            let secondaryStartX = frame.origin.x + mainWidth + paneGap

            for (index, window) in secondaryWindows.enumerated() {
                let windowX = secondaryStartX + (CGFloat(index) * (secondaryWindowWidth + settings.windowGap))
                let windowFrame = CGRect(
                    x: windowX,
                    y: frame.origin.y,
                    width: secondaryWindowWidth,
                    height: frame.height
                )

                assignments.append(FrameAssignment<AXWindow>(
                    frame: windowFrame,
                    windowID: window.id(),
                    screenFrame: frame,
                    resizeRules: ResizeRules(
                        isMain: false,
                        unconstrainedDimension: .horizontal,
                        scaleFactor: secondaryWindowWidth / availableWidth
                    )
                ))
            }
        }
        
        return assignments
    }
}