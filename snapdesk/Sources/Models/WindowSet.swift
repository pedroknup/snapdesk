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
    case tall              // main pane on top, secondary pane below
    case wide              // main pane on left, secondary pane on right  
    case vertical_stack    // windows stacked vertically with equal height
    case horizontal_stack  // windows stacked horizontally with equal width
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
        
        // Use the plugin system
        guard let layoutEngine = LayoutRegistry.shared.layout(for: layout.rawValue) else {
            print("Warning: Layout engine not found for \(layout.rawValue)")
            return
        }
        
        // Create settings from current configuration
        let settings = LayoutSettings(
            windowGap: CGFloat(UserDefaults.standard.object(forKey: "windowGap") as? Double ?? 0),
            windowMargin: CGFloat(UserDefaults.standard.object(forKey: "windowMargin") as? Double ?? 0),
            mainPanelSizeAdjustment: mainPanelSizeAdjustment
        )
        
        // Get frame assignments from the layout engine
        let assignments = layoutEngine.expandWindows(windows, in: availableFrame, with: settings, bringToFront: bringToFront)
        
        // Apply the frame assignments using the existing move function
        for assignment in assignments {
            if let window = windows.first(where: { $0.id() == assignment.windowID }) {
                move(window: window.axElementRef, to: assignment.finalFrame)
            }
        }
        
        // Handle bringing windows to front for layouts that support it
        if bringToFront && !assignments.isEmpty {
            for (index, window) in windows.enumerated() {
                DispatchQueue.main.asyncAfter(deadline: .now() + Double(index) * 0.1) {
                    window.raise()
                }
            }
        }
    }
    
    /// Raises all windows in this WindowSet to bring them to front WITHOUT changing focus
    /// This only changes z-order (visibility), not which window receives keyboard input
    func raiseAllWindows(excluding excludeWindow: AXWindow? = nil) async {
        // Raise windows in reverse order so the first window ends up on top
        // This ensures proper stacking order for the windowset
        for window in windows.reversed() {
            // Skip the excluded window if specified
            if let exclude = excludeWindow, window.cgID() == exclude.cgID() {
                continue
            }
            
            // Only raise, don't focus - this changes z-order without changing keyboard focus
            window.raise()
            // Small delay to ensure the raise operation completes
            try? await Task.sleep(nanoseconds: 5_000_000) // 5ms between raises
        }
    }
    
    /// Toggle between layout types for this WindowSet
    func toggleLayout() {
        let nextLayout: LayoutKind
        switch layout {
        case .tall:
            nextLayout = .wide
        case .wide:
            nextLayout = .vertical_stack
        case .vertical_stack:
            nextLayout = .horizontal_stack
        case .horizontal_stack:
            nextLayout = .tall
        case .fullscreen, .floating:
            // If currently in fullscreen or floating, default to tall
            nextLayout = .tall
        }
        
        layout = nextLayout
        
        // Show popup notification for layout change
        showLayoutChangePopup(for: layout)
        
        // Re-expand windows with the new layout
        expandWindows()
    }
    
    /// Shows a popup notification indicating the current layout
    private func showLayoutChangePopup(for layout: LayoutKind) {
        // Check if all layouts should be shown in a grid
        if UserConfiguration.shared.showAllLayoutsOnToggle() {
            FloatingWindowHelper.showAllLayoutsGrid(
                currentLayout: layout,
                position: .center,
                duration: 1.5
            )
        } else {
            // Show simple text popup (existing behavior)
            let layoutDisplayName: String
            
            switch layout {
            case .tall:
                layoutDisplayName = "Tall"
            case .wide:
                layoutDisplayName = "Wide"
            case .vertical_stack:
                layoutDisplayName = "Vertical Stack"
            case .horizontal_stack:
                layoutDisplayName = "Horizontal Stack"
            case .fullscreen:
                layoutDisplayName = "Fullscreen"
            case .floating:
                layoutDisplayName = "Floating"
            }
            
            FloatingWindowHelper.showFloatingWindow(
                text: layoutDisplayName,
                position: .center,
                duration: 1.0,
                fontSize: 16
            )
        }
    }
}
