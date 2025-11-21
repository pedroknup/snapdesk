//
//  WindowOrderManager.swift
//  snapdesk
//
//  Created by Pedro Knup on 21/11/2025.
//

import Foundation
import AppKit

class WindowOrderManager {
    private weak var workspaceProvider: WorkspaceProvider?
    private let cyclingManager: CyclingManager

    init(workspaceProvider: WorkspaceProvider, cyclingManager: CyclingManager) {
        self.workspaceProvider = workspaceProvider
        self.cyclingManager = cyclingManager
    }

    // MARK: - Public API

    func moveWindowUpInLayout() {
        moveWindowInLayout(direction: .up)
    }

    func moveWindowDownInLayout() {
        moveWindowInLayout(direction: .down)
    }

    // MARK: - Private Implementation

    private enum MoveDirection {
        case up, down
    }

    private func moveWindowInLayout(direction: MoveDirection) {
        DispatchQueue.main.async { [weak self] in
            guard let self = self else { return }

            guard let focusedWindow = frontmostWindow() else {
                log("❌ No focused window found")
                return
            }

            self.performWindowCyclingOrderChange(direction: direction, focusedWindow: focusedWindow)
        }
    }

    private func performWindowCyclingOrderChange(direction: MoveDirection, focusedWindow: AXUIElement) {
        let axWindow = AXWindow(axElement: focusedWindow)
        let focusedWindowID = axWindow.cgID()

        guard let app = NSRunningApplication(processIdentifier: axWindow.pid()),
              let bundleID = app.bundleIdentifier else {
            log("❌ Could not find app for focused window")
            return
        }

        let currentCyclingOrder = cyclingManager.getWindowCyclingOrder(for: bundleID)
        guard let cyclingIndex = currentCyclingOrder.firstIndex(of: focusedWindowID) else {
            return
        }

        let moveDirection = direction == .up ? -1 : 1
        let newCyclingIndex = max(0, min(currentCyclingOrder.count - 1, cyclingIndex + moveDirection))

        if newCyclingIndex == cyclingIndex {
            showCyclingOrderFeedback(
                bundleID: bundleID,
                appName: app.localizedName ?? bundleID,
                windowOrder: currentCyclingOrder,
                focusedWindowID: focusedWindowID
            )
            return
        }

        guard let newOrder = cyclingManager.moveWindowInCyclingOrder(
            for: bundleID,
            windowID: focusedWindowID,
            direction: moveDirection
        ) else {
            return
        }

        showCyclingOrderFeedback(
            bundleID: bundleID,
            appName: app.localizedName ?? bundleID,
            windowOrder: newOrder,
            focusedWindowID: focusedWindowID
        )
    }

    private func showCyclingOrderFeedback(bundleID: String, appName: String, windowOrder: [CGWindowID], focusedWindowID: CGWindowID) {
        let config = ConfigurationManager.shared.loadConfig()?.windowPreview ?? WindowPreviewConfig()
        let feedbackText = ""

        var previewImages: [(NSImage, String)] = []

        guard let workspace = workspaceProvider?.workspace else { return }

        for (index, windowID) in windowOrder.enumerated() {
            var windowTitle = "Unknown"
            for screenWorkspace in workspace.screens {
                for windowSet in screenWorkspace.windowSets {
                    if let window = windowSet.windows.first(where: { $0.cgID() == windowID }) {
                        let title = window.title() ?? "untitled"
                        let cleanTitle = title.replacingOccurrences(of: "✳", with: "").trimmingCharacters(in: .whitespaces)
                        let appName = NSRunningApplication(processIdentifier: window.pid())?.localizedName ?? "App"

                        if cleanTitle.isEmpty || cleanTitle == "Order Change" || cleanTitle == appName {
                            windowTitle = "\(appName) (\(String(windowID).suffix(4)))"
                        } else {
                            windowTitle = cleanTitle
                        }
                        break
                    }
                }
            }

            let truncatedTitle = truncateString(windowTitle, maxLength: 35)
            let isCurrent = windowID == focusedWindowID
            let marker = isCurrent ? " ◄" : ""

            if config.enabled {
                let maxSize = NSSize(width: config.maxWidth, height: config.maxHeight)
                if let screenshot = WindowScreenshotCapture.captureWindow(windowID: windowID, maxSize: maxSize) {
                    previewImages.append((screenshot, "\(index + 1). \(truncatedTitle)\(marker)"))
                }
            }
        }

        if config.enabled && !previewImages.isEmpty {
            FloatingWindowHelper.showFloatingWindow(
                attributedText: NSAttributedString(string: feedbackText),
                images: previewImages,
                position: .center,
                duration: 2.5,
                fontSize: 14
            )
        }
    }

    private func truncateString(_ string: String, maxLength: Int) -> String {
        if string.count <= maxLength {
            return string
        }
        let endIndex = string.index(string.startIndex, offsetBy: maxLength - 3)
        return String(string[..<endIndex]) + "..."
    }
}
