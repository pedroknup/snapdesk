//
//  WindowSet.swift
//  Amethyst
//
//  Created by Ian Ynda-Hummel on 3/29/19.
//  Copyright © 2019 Ian Ynda-Hummel. All rights reserved.
//

import Foundation

/// Possible dimensions without constraints.
enum UnconstrainedDimension: Int {
    /// The dimension along the x-axis.
    case horizontal

    /// The dimension along the y-axis.
    case vertical
}


/**
 This struct defines what adjustments to a particular window frame are allowed and tracks its size as a proportion of available space (for use in resize calculations).

 Some window resizes reflect valid adjustments to the frame layout.
 
 Some window resizes would not be allowed due to hard constraints.
 */
struct ResizeRules {
    /// Whether or not the resize rule is applying to the main frame.
    let isMain: Bool

    /// The dimension that is allowed to scale.
    let unconstrainedDimension: UnconstrainedDimension

    /// the scale factor for the unconstrained dimension.
    let scaleFactor: CGFloat

    /**
     Determines the new value of the dimension based on the scale factor.
     
     Given a new frame, decide which dimension will be honored and return its size.
     
     - Parameters:
        - frame: The frame to transform.
        - negatePadding: Whether or not to take padding into account.
     */
    func scaledDimension(_ frame: CGRect, negatePadding: Bool) -> CGFloat {
        let dimension: CGFloat = {
            switch unconstrainedDimension {
            case .horizontal: return frame.width
            case .vertical: return frame.height
            }
        }()

        let padding = UserConfiguration.shared.windowMargins() ? UserConfiguration.shared.windowMarginSize() : 0
        return negatePadding ? dimension + padding : dimension
    }
}

/// Encapsulation of an assignment of a frame to a window.
struct FrameAssignment<W: WindowType> {
    /// The frame to apply to the window.
    let frame: CGRect

    /// The ID of the window that will be moved and sized.
    let windowID: W.WindowID

    /// The frame of the screen being occupied.
    let screenFrame: CGRect

    /// The rules governing constraints to frame transforms.
    let resizeRules: ResizeRules

    /// If `true`, then window margins won't be applied.
    let disableWindowMargins: Bool

    init(
        frame: CGRect,
        windowID: W.WindowID,
        screenFrame: CGRect,
        resizeRules: ResizeRules,
        disableWindowMargins: Bool = false
    ) {
        self.frame = frame
        self.windowID = windowID
        self.screenFrame = screenFrame
        self.resizeRules = resizeRules
        self.disableWindowMargins = disableWindowMargins
    }

    /// The final frame is the desired frame, but transformed to provide desired padding
    var finalFrame: CGRect {
        var ret = frame
        let padding = floor(UserConfiguration.shared.windowMarginSize() / 2)

        if UserConfiguration.shared.windowMargins() && !disableWindowMargins {
            ret.origin.x += padding
            ret.origin.y += padding
            ret.size.width -= 2 * padding
            ret.size.height -= 2 * padding
        }

        let windowMinimumWidth = UserConfiguration.shared.windowMinimumWidth()
        let windowMinimumHeight = UserConfiguration.shared.windowMinimumHeight()

        if windowMinimumWidth > ret.size.width {
            ret.origin.x -= ((windowMinimumWidth - ret.size.width) / 2)
            ret.size.width = windowMinimumWidth
        }

        if windowMinimumHeight > ret.size.height {
            ret.origin.y -= ((windowMinimumHeight - ret.size.height) / 2)
            ret.size.height = windowMinimumHeight
        }

        return ret
    }

    func impliedMainPaneRatio(windowFrame: CGRect) -> CGFloat {
        let oldDimension = resizeRules.scaledDimension(frame, negatePadding: false)
        let newDimension = resizeRules.scaledDimension(windowFrame, negatePadding: true)
        let implied = (newDimension / oldDimension) / resizeRules.scaleFactor
        return resizeRules.isMain ? implied : 1 - implied
    }

    /// Perform the actual application of the frame to the window
    func perform(withWindow window: W) {
        var finalFrame = self.finalFrame
        var finalOrigin = finalFrame.origin

        if window.isFocused() {
            // Peek adjustment
            finalFrame.origin = window.frame().origin
            DispatchQueue.main.sync {
                window.setFrame(finalFrame, withThreshold: CGSize(width: 1, height: 1))
            }

            finalFrame.size = CGSize(
                width: max(window.frame().width, finalFrame.width),
                height: max(window.frame().height, finalFrame.height)
            )
            finalOrigin.x = max(screenFrame.minX, min(finalOrigin.x, screenFrame.maxX - finalFrame.size.width))
            finalOrigin.y = max(screenFrame.minY, min(finalOrigin.y, screenFrame.maxY - finalFrame.size.height))
        }

        finalFrame.origin = finalOrigin
        DispatchQueue.main.sync {
            window.setFrame(finalFrame, withThreshold: CGSize(width: 1, height: 1))
        }
    }
}
public enum LayoutKind: String, Codable {
    case tall        // vertical split, main + stack
    case wide        // horizontal split
    case fullscreen
    case floating
}

/// One logical collection of windows + how to arrange them
final class WindowSet: Identifiable {


    let id: UUID = UUID()
    var layout: LayoutKind
    var windows: [AXWindow]
    var screenID: String?
    
    /// The size adjustment for the main panel (first window) in pixels.
    /// Positive values make the main panel larger, negative values make it smaller.
    /// Resets to 0 when the WindowSet contains only one window.
    var mainPanelSizeAdjustment: CGFloat = 0

    init(layout: LayoutKind = .tall, windows: [AXWindow] = [], screenID: String? = nil) {
        self.layout = layout
        self.windows = windows
        self.screenID = screenID
    }
    
    /// Expands all windows in the WindowSet according to its layout on their assigned screen
    func expandWindows() {
        guard let screenID = screenID,
              let screen = AMScreen.availableScreens.first(where: { $0.screenID() == screenID }) else {
            log("❌ Cannot expand windows: no screen ID or screen not found")
            return
        }
        expandWindows(on: screen)
    }
    
    /// Expands all windows in the WindowSet according to its layout
    /// - Parameter screen: The screen to expand windows on
    /// - Parameter bringToFront: Whether to bring windows to front after expansion (default: true)
    func expandWindows(on screen: AMScreen, bringToFront: Bool = true) {
        guard !windows.isEmpty else { return }
        
        // Reset mainPanelSizeAdjustment if only one window
        if windows.count == 1 {
            mainPanelSizeAdjustment = 0
        }
        
        let availableFrame = screen.adjustedFrame()
        
        switch layout {
        case .wide:
            expandWindowsWide(in: availableFrame, bringToFront: bringToFront)
        case .tall:
            expandWindowsTall(in: availableFrame, bringToFront: bringToFront)
        case .fullscreen:
            expandWindowsFullscreen(in: availableFrame, bringToFront: bringToFront)
        case .floating:
            // Floating windows maintain their current positions/sizes
            break
        }
    }
    
    private func expandWindowsWide(in frame: CGRect, bringToFront: Bool = true) {
        let windowCount = windows.count
        
        // Get window gap and margin from settings
        let windowGap = CGFloat(UserDefaults.standard.object(forKey: "windowGap") as? Double ?? 4.0)
        let windowMargin = CGFloat(UserDefaults.standard.object(forKey: "windowMargin") as? Double ?? 8.0)
        
        // Calculate available width after accounting for gaps
        let totalGapWidth = windowGap * CGFloat(windowCount - 1)
        let availableWidth = frame.width - totalGapWidth
        
        // Calculate window widths with main panel adjustment
        var windowWidths: [CGFloat] = []
        if windowCount == 1 {
            windowWidths = [availableWidth]
        } else {
            // Adjust the main panel size if there are multiple windows
            let baseWidth = availableWidth / CGFloat(windowCount)
            let adjustment = mainPanelSizeAdjustment
            let adjustmentPerOther = adjustment / CGFloat(windowCount - 1)
            
            // First window gets the adjustment
            windowWidths.append(baseWidth + adjustment)
            
            // Other windows share the inverse adjustment
            for _ in 1..<windowCount {
                windowWidths.append(baseWidth - adjustmentPerOther)
            }
        }
        
        // First, move all windows to their positions
        var currentX: CGFloat = frame.origin.x
        for (index, window) in windows.enumerated() {
            let windowWidth = windowWidths[index]
            
            // Apply margin to shrink window inward from all sides
            let windowFrame = CGRect(
                x: currentX + windowMargin,
                y: frame.origin.y + windowMargin,
                width: windowWidth - (windowMargin * 2),
                height: frame.height - (windowMargin * 2)
            )
            
            move(window: window.axElementRef, to: windowFrame)
            currentX += windowWidth + windowGap
        }
        
        // Optionally bring all windows to front with small delays to ensure they all come up
        if bringToFront {
            for (index, window) in windows.enumerated() {
                DispatchQueue.main.asyncAfter(deadline: .now() + Double(index) * 0.1) {
                    window.raise()
                }
            }
        }
    }
    
    private func expandWindowsTall(in frame: CGRect, bringToFront: Bool = true) {
        let windowCount = windows.count
        
        // Get window gap and margin from settings
        let windowGap = CGFloat(UserDefaults.standard.object(forKey: "windowGap") as? Double ?? 4.0)
        let windowMargin = CGFloat(UserDefaults.standard.object(forKey: "windowMargin") as? Double ?? 8.0)
        
        // Calculate available height after accounting for gaps
        let totalGapHeight = windowGap * CGFloat(windowCount - 1)
        let availableHeight = frame.height - totalGapHeight
        
        // Calculate window heights with main panel adjustment
        var windowHeights: [CGFloat] = []
        if windowCount == 1 {
            windowHeights = [availableHeight]
        } else {
            // Adjust the main panel size if there are multiple windows
            let baseHeight = availableHeight / CGFloat(windowCount)
            let adjustment = mainPanelSizeAdjustment
            let adjustmentPerOther = adjustment / CGFloat(windowCount - 1)
            
            // First window gets the adjustment
            windowHeights.append(baseHeight + adjustment)
            
            // Other windows share the inverse adjustment
            for _ in 1..<windowCount {
                windowHeights.append(baseHeight - adjustmentPerOther)
            }
        }
        
        // First, move all windows to their positions
        var currentY: CGFloat = frame.origin.y
        for (index, window) in windows.enumerated() {
            let windowHeight = windowHeights[index]
            
            // Apply margin to shrink window inward from all sides
            let windowFrame = CGRect(
                x: frame.origin.x + windowMargin,
                y: currentY + windowMargin,
                width: frame.width - (windowMargin * 2),
                height: windowHeight - (windowMargin * 2)
            )
            
            move(window: window.axElementRef, to: windowFrame)
            currentY += windowHeight + windowGap
        }
        
        // Optionally bring all windows to front with small delays to ensure they all come up
        if bringToFront {
            for (index, window) in windows.enumerated() {
                DispatchQueue.main.asyncAfter(deadline: .now() + Double(index) * 0.1) {
                    window.raise()
                }
            }
        }
    }
    
    private func expandWindowsFullscreen(in frame: CGRect, bringToFront: Bool = true) {
        // In fullscreen mode, all windows take up the entire screen (minus margin)
        // Only the focused window should be visible
        
        // Get window margin from settings
        let windowMargin = CGFloat(UserDefaults.standard.object(forKey: "windowMargin") as? Double ?? 8.0)
        
        // Apply margin to fullscreen frame
        let fullscreenFrame = CGRect(
            x: frame.origin.x + windowMargin,
            y: frame.origin.y + windowMargin,
            width: frame.width - (windowMargin * 2),
            height: frame.height - (windowMargin * 2)
        )
        
        
        // First, move all windows to fullscreen
        for window in windows {
            move(window: window.axElementRef, to: fullscreenFrame)
        }
        
        // Optionally bring all windows to front with small delays
        if bringToFront {
            for (index, window) in windows.enumerated() {
                DispatchQueue.main.asyncAfter(deadline: .now() + Double(index) * 0.1) {
                    window.raise()
                }
            }
        }
    }
    
    /// Toggle between tall and wide layout types for this WindowSet
    func toggleLayout() {
        let nextLayout: LayoutKind
        switch layout {
        case .tall:
            nextLayout = .wide
        case .wide:
            nextLayout = .tall
        case .fullscreen, .floating:
            // If currently in fullscreen or floating, default to tall
            nextLayout = .tall
        }
        
        layout = nextLayout
        
        // Show floating notification if enabled in settings (default: true)
        let showLayoutIndicator = UserDefaults.standard.object(forKey: "showLayoutIndicator") as? Bool ?? true
        if showLayoutIndicator {
            FloatingWindowHelper.showFloatingWindow(
                text: "Layout: \(nextLayout.rawValue.capitalized)", 
                position: .center, 
                duration: 1.5
            )
        }
        
        // Re-expand windows with the new layout
        expandWindows()
    }
}
