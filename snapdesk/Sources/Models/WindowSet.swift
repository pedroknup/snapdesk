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

/// One logical collection of windows + how to arrange them
final class WindowSet: Identifiable {
    enum LayoutKind: String, Codable {
        case tall        // vertical split, main + stack
        case wide        // horizontal split
        case fullscreen
        case floating
    }

    let id: UUID = UUID()
    var layout: LayoutKind
    var windows: [AXWindow]
    var screenID: String?

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
    func expandWindows(on screen: AMScreen) {
        guard !windows.isEmpty else { return }
        
        let availableFrame = screen.adjustedFrame()
        log("🔧 Expanding \(windows.count) windows in \(layout) layout on screen \(screen.screenID() ?? "unknown")")
        log("📐 Available frame: \(NSStringFromRect(availableFrame))")
        
        switch layout {
        case .wide:
            expandWindowsWide(in: availableFrame)
        case .tall:
            expandWindowsTall(in: availableFrame)
        case .fullscreen:
            expandWindowsFullscreen(in: availableFrame)
        case .floating:
            // Floating windows maintain their current positions/sizes
            log("💭 Skipping expansion for floating layout")
        }
    }
    
    private func expandWindowsWide(in frame: CGRect) {
        let windowCount = windows.count
        let windowWidth = frame.width / CGFloat(windowCount)
        
        for (index, window) in windows.enumerated() {
            let windowFrame = CGRect(
                x: frame.origin.x + (CGFloat(index) * windowWidth),
                y: frame.origin.y,
                width: windowWidth,
                height: frame.height
            )
            
            log("📱 Moving window \(index): \(window.title() ?? "untitled") to \(NSStringFromRect(windowFrame))")
            move(window: window.axElementRef, to: windowFrame)
        }
    }
    
    private func expandWindowsTall(in frame: CGRect) {
        let windowCount = windows.count
        let windowHeight = frame.height / CGFloat(windowCount)
        
        for (index, window) in windows.enumerated() {
            let windowFrame = CGRect(
                x: frame.origin.x,
                y: frame.origin.y + (CGFloat(index) * windowHeight),
                width: frame.width,
                height: windowHeight
            )
            
            log("📱 Moving window \(index): \(window.title() ?? "untitled") to \(NSStringFromRect(windowFrame))")
            move(window: window.axElementRef, to: windowFrame)
        }
    }
    
    private func expandWindowsFullscreen(in frame: CGRect) {
        // In fullscreen mode, all windows take up the entire screen
        // Only the focused window should be visible
        for window in windows {
            log("🖥️ Expanding window to fullscreen: \(window.title() ?? "untitled")")
            move(window: window.axElementRef, to: frame)
        }
    }
}
