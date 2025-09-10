//
//  TallLayout.swift
//  SnapDesk
//
//  Created by Claude on 9/8/25.
//

import Foundation

/// Tall layout: Main pane on top, secondary pane below (fibonacci-style)
class TallLayout: BaseLayout {
    init() {
        super.init(
            id: "tall",
            displayName: "Tall",
            description: "Main pane on top, secondary pane below"
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
            let windowFrame = CGRect(
                x: frame.origin.x + settings.windowMargin,
                y: frame.origin.y + settings.windowMargin,
                width: frame.width - (settings.windowMargin * 2),
                height: frame.height - (settings.windowMargin * 2)
            )
            
            assignments.append(FrameAssignment<AXWindow>(
                frame: windowFrame,
                windowID: windows[0].id(),
                screenFrame: frame,
                resizeRules: ResizeRules(
                    isMain: true,
                    unconstrainedDimension: .vertical,
                    scaleFactor: 1.0
                )
            ))
        } else {
            // Main pane on top, secondary pane below
            let paneGap = settings.windowGap
            let availableHeight = frame.height - paneGap
            
            // Main pane gets 50% by default, adjusted by mainPanelSizeAdjustment
            let baseMainHeight = availableHeight * 0.5
            let mainHeight = max(100, baseMainHeight + settings.mainPanelSizeAdjustment)
            let secondaryHeight = availableHeight - mainHeight
            
            // Main pane (single window)
            let mainFrame = CGRect(
                x: frame.origin.x + settings.windowMargin,
                y: frame.origin.y + settings.windowMargin,
                width: frame.width - (settings.windowMargin * 2),
                height: mainHeight - (settings.windowMargin * 2)
            )
            
            assignments.append(FrameAssignment<AXWindow>(
                frame: mainFrame,
                windowID: windows[0].id(),
                screenFrame: frame,
                resizeRules: ResizeRules(
                    isMain: true,
                    unconstrainedDimension: .vertical,
                    scaleFactor: mainHeight / availableHeight
                )
            ))
            
            // Secondary pane (remaining windows stacked vertically)
            let secondaryWindows = Array(windows.dropFirst())
            let secondaryWindowCount = secondaryWindows.count
            let secondaryWindowGaps = settings.windowGap * CGFloat(max(0, secondaryWindowCount - 1))
            let availableSecondaryHeight = secondaryHeight - secondaryWindowGaps
            let secondaryWindowHeight = availableSecondaryHeight / CGFloat(secondaryWindowCount)
            
            let secondaryStartY = frame.origin.y + mainHeight + paneGap
            
            for (index, window) in secondaryWindows.enumerated() {
                let windowY = secondaryStartY + (CGFloat(index) * (secondaryWindowHeight + settings.windowGap))
                let windowFrame = CGRect(
                    x: frame.origin.x + settings.windowMargin,
                    y: windowY + settings.windowMargin,
                    width: frame.width - (settings.windowMargin * 2),
                    height: secondaryWindowHeight - (settings.windowMargin * 2)
                )
                
                assignments.append(FrameAssignment<AXWindow>(
                    frame: windowFrame,
                    windowID: window.id(),
                    screenFrame: frame,
                    resizeRules: ResizeRules(
                        isMain: false,
                        unconstrainedDimension: .vertical,
                        scaleFactor: secondaryWindowHeight / availableHeight
                    )
                ))
            }
        }
        
        return assignments
    }
}