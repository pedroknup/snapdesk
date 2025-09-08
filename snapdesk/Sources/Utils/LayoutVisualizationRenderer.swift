//
//  LayoutVisualizationRenderer.swift
//  snapdesk
//
//  Created by Claude on 08/09/2025.
//

import Cocoa
import Foundation

class LayoutVisualizationRenderer {
    
    // MARK: - Public Methods
    
    static func renderLayoutVisualization(
        workspace: WorkspaceModel,
        focusedWindowID: CGWindowID?,
        currentScreenID: String?
    ) -> NSAttributedString {
        let renderer = LayoutVisualizationRenderer()
        return renderer.renderAttributedString(
            workspace: workspace,
            focusedWindowID: focusedWindowID,
            currentScreenID: currentScreenID
        )
    }
    
    // MARK: - Private Implementation
    
    private func renderAttributedString(
        workspace: WorkspaceModel,
        focusedWindowID: CGWindowID?,
        currentScreenID: String?
    ) -> NSAttributedString {
        let mutableAttributedString = NSMutableAttributedString()
        
        // Add title
        mutableAttributedString.append(NSAttributedString(string: "Window Layouts", attributes: headerAttributes))
        
        // Process each screen
        for (screenIndex, screenWorkspace) in workspace.screens.enumerated() {
            let screen = screenWorkspace.screen
            let screenID = screen.screenID() ?? "unknown"
            let isCurrentScreen = screenID == currentScreenID
            
            renderScreen(
                screenWorkspace: screenWorkspace,
                screenIndex: screenIndex,
                isCurrentScreen: isCurrentScreen,
                focusedWindowID: focusedWindowID,
                into: mutableAttributedString
            )
        }
        
        // Add help text at the bottom
        renderFooter(into: mutableAttributedString)
        
        return mutableAttributedString
    }
    
    private func renderScreen(
        screenWorkspace: ScreenWorkspace,
        screenIndex: Int,
        isCurrentScreen: Bool,
        focusedWindowID: CGWindowID?,
        into mutableAttributedString: NSMutableAttributedString
    ) {
        // Add screen header with current indicator
        let currentMarker = isCurrentScreen ? " *" : ""
        let screenText = "\n\n" + String(repeating: "─", count: 40) + "\nScreen \(screenIndex + 1)\(currentMarker)"
        mutableAttributedString.append(NSAttributedString(string: screenText, attributes: headerAttributes))
        
        // Check if there are any window sets on this screen
        if screenWorkspace.windowSets.isEmpty {
            mutableAttributedString.append(NSAttributedString(string: "\n  No layouts", attributes: baseAttributes))
            return
        }
        
        // Count total windows on this screen
        let totalWindows = screenWorkspace.windowSets.reduce(0) { $0 + $1.windows.count }
        let windowCountText = "\n  \(totalWindows) windows in \(screenWorkspace.windowSets.count) layouts"
        mutableAttributedString.append(NSAttributedString(string: windowCountText, attributes: baseAttributes))
        
        // Process each WindowSet on this screen
        for (layoutIndex, windowSet) in screenWorkspace.windowSets.enumerated() {
            renderWindowSet(
                windowSet: windowSet,
                layoutIndex: layoutIndex,
                focusedWindowID: focusedWindowID,
                into: mutableAttributedString
            )
        }
    }
    
    private func renderWindowSet(
        windowSet: WindowSet,
        layoutIndex: Int,
        focusedWindowID: CGWindowID?,
        into mutableAttributedString: NSMutableAttributedString
    ) {
        // Check if this WindowSet contains the focused window
        let containsFocusedWindow = windowSet.windows.contains { window in
            return focusedWindowID != nil && window.cgID() == focusedWindowID
        }
        
        // Add separator between layouts
        mutableAttributedString.append(NSAttributedString(string: "\n", attributes: baseAttributes))
        
        // Add WindowSet info with active indicator
        let activeMarker = containsFocusedWindow ? " [ACTIVE]" : ""
        let layoutText = "\n[\(layoutIndex + 1)] \(windowSet.layout.rawValue.uppercased())\(activeMarker)"
        let layoutAttributes = containsFocusedWindow ? activeAttributes : baseAttributes
        mutableAttributedString.append(NSAttributedString(string: layoutText, attributes: layoutAttributes))
        
        if !windowSet.windows.isEmpty {
            let windowCountText = " (\(windowSet.windows.count) windows)"
            mutableAttributedString.append(NSAttributedString(string: windowCountText, attributes: layoutAttributes))
            
            // Add window details with ordering numbers
            for (windowIndex, window) in windowSet.windows.enumerated() {
                renderWindow(
                    window: window,
                    windowIndex: windowIndex,
                    focusedWindowID: focusedWindowID,
                    into: mutableAttributedString
                )
            }
        } else {
            mutableAttributedString.append(NSAttributedString(string: " (empty)", attributes: baseAttributes))
        }
    }
    
    private func renderWindow(
        window: AXWindow,
        windowIndex: Int,
        focusedWindowID: CGWindowID?,
        into mutableAttributedString: NSMutableAttributedString
    ) {
        let isFocused = focusedWindowID != nil && window.cgID() == focusedWindowID
        
        // Get app name and window title
        let appName = getAppName(for: window)
        let windowTitle = window.title() ?? "untitled"
        let truncatedTitle = truncateString(windowTitle, maxLength: 30)
        
        // Add ordering number and focus indicator
        let orderNumber = windowIndex + 1
        let focusIndicator = isFocused ? " ▶" : ""
        let windowText = "\n    \(orderNumber). \(appName): \(truncatedTitle)\(focusIndicator)"
        
        // Use different attributes for focused window
        let windowAttributes = isFocused ? activeAttributes : baseAttributes
        mutableAttributedString.append(NSAttributedString(string: windowText, attributes: windowAttributes))
    }
    
    private func renderFooter(into mutableAttributedString: NSMutableAttributedString) {
        mutableAttributedString.append(NSAttributedString(string: "\n\n" + String(repeating: "─", count: 40), attributes: baseAttributes))
        mutableAttributedString.append(NSAttributedString(string: "\n* = Current Screen  |  ▶ = Focused  |  [ACTIVE] = Current Layout", attributes: baseAttributes))
    }
    
    // MARK: - Text Attributes
    
    private var baseAttributes: [NSAttributedString.Key: Any] {
        return [
            .font: NSFont.monospacedSystemFont(ofSize: 14, weight: .regular),
            .foregroundColor: NSColor.white
        ]
    }
    
    private var activeAttributes: [NSAttributedString.Key: Any] {
        return [
            .font: NSFont.monospacedSystemFont(ofSize: 14, weight: .regular),
            .foregroundColor: NSColor.systemGreen,
            .backgroundColor: NSColor.systemGreen.withAlphaComponent(0.2)
        ]
    }
    
    private var headerAttributes: [NSAttributedString.Key: Any] {
        return [
            .font: NSFont.monospacedSystemFont(ofSize: 14, weight: .semibold),
            .foregroundColor: NSColor.systemBlue
        ]
    }
    
    // MARK: - Helper Methods
    
    private func getAppName(for window: AXWindow) -> String {
        guard let app = NSRunningApplication(processIdentifier: window.pid()) else {
            return "Unknown"
        }
        return app.localizedName ?? app.bundleIdentifier ?? "Unknown"
    }
    
    private func truncateString(_ string: String, maxLength: Int) -> String {
        if string.count <= maxLength {
            return string
        }
        let endIndex = string.index(string.startIndex, offsetBy: maxLength - 3)
        return String(string[..<endIndex]) + "..."
    }
}