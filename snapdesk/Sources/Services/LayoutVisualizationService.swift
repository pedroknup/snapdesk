//
//  LayoutVisualizationService.swift
//  snapdesk
//
//  Created by Pedro Knup on 21/11/2025.
//

import Foundation
import AppKit

class LayoutVisualizationService {
    private weak var workspaceProvider: WorkspaceProvider?

    init(workspaceProvider: WorkspaceProvider) {
        self.workspaceProvider = workspaceProvider
    }

    // MARK: - Public API

    func showLayoutVisualization() {
        showLayoutVisualization(duration: 3.0, isAutomatic: false)
    }

    func showAutomaticLayoutVisualization() {
        showLayoutVisualization(duration: 1.5, isAutomatic: true)
    }

    // MARK: - Private Implementation

    private func showLayoutVisualization(duration: TimeInterval, isAutomatic: Bool) {
        if isAutomatic {
            let showAutoLayoutViz = UserDefaults.standard.object(forKey: "showAutoLayoutVisualization") as? Bool ?? true
            if !showAutoLayoutViz {
                return
            }
        }

        log("🎨 Showing layout visualization (\(isAutomatic ? "automatic" : "manual"))")

        DispatchQueue.main.async { [weak self] in
            guard let self = self else { return }

            let attributedText = self.createLayoutVisualization()

            // Layout visualization removed
        }
    }

    private func createLayoutVisualization() -> NSAttributedString {
        let focusedWindowID: CGWindowID? = {
            if let focusedElement = frontmostWindow() {
                let axWindow = AXWindow(axElement: focusedElement)
                return axWindow.cgID()
            }
            return nil
        }()

        let currentScreenID: String? = {
            if let focusedElement = frontmostWindow() {
                let axWindow = AXWindow(axElement: focusedElement)
                return axWindow.snapScreen()?.screenID()
            }
            return nil
        }()

        guard let workspace = workspaceProvider?.workspace else {
            return NSAttributedString(string: "")
        }

        return LayoutVisualizationRenderer.renderLayoutVisualization(
            workspace: workspace,
            focusedWindowID: focusedWindowID,
            currentScreenID: currentScreenID
        )
    }
}
