//
//  FloatingWindowHelper.swift
//  snapdesk
//
//  Created by Claude on 27/08/2025.
//

import Cocoa

enum FloatingPosition {
    case center
    case topLeft
    case topRight
    case bottomLeft
    case bottomRight
}

class FloatingWindowHelper {
    private static var activeWindows: [NSWindow] = []
    
    static func showFloatingWindow(text: String, position: FloatingPosition = .center, duration: TimeInterval = 2.0, fontSize: CGFloat = 16) {
        showFloatingWindow(attributedText: NSAttributedString(string: text), position: position, duration: duration, fontSize: fontSize)
    }
    
    static func showFloatingWindow(attributedText: NSAttributedString, position: FloatingPosition = .center, duration: TimeInterval = 2.0, fontSize: CGFloat = 16) {
        // Read settings for notification position and duration
        let settingsDuration = UserDefaults.standard.object(forKey: "notificationDuration") as? Double ?? duration
        let settingsPosition = UserDefaults.standard.string(forKey: "notificationPosition") ?? "center"
        
        // Convert settings position to FloatingPosition
        let actualPosition: FloatingPosition
        switch settingsPosition {
        case "topLeft": actualPosition = .topLeft
        case "topRight": actualPosition = .topRight
        case "bottomLeft": actualPosition = .bottomLeft
        case "bottomRight": actualPosition = .bottomRight
        default: actualPosition = .center
        }
        
        let window = createFloatingWindow(attributedText: attributedText, position: actualPosition, fontSize: fontSize)
        activeWindows.append(window)
        
        window.makeKeyAndOrderFront(nil)
        window.level = NSWindow.Level(rawValue: Int(CGWindowLevelForKey(.floatingWindow)))
        
        // Auto-hide after duration (use settings duration)
        DispatchQueue.main.asyncAfter(deadline: .now() + settingsDuration) {
            hideWindow(window)
        }
    }
    
    private static func createFloatingWindow(attributedText: NSAttributedString, position: FloatingPosition, fontSize: CGFloat = 16) -> NSWindow {
        // Create text view to display attributed text
        let textView = NSTextView()
        textView.textStorage?.setAttributedString(attributedText)
        textView.font = NSFont.monospacedSystemFont(ofSize: fontSize, weight: .regular)
        textView.textColor = NSColor.white
        textView.backgroundColor = NSColor.clear
        textView.isEditable = false
        textView.isSelectable = false
        textView.alignment = .left
        textView.isRichText = true
        textView.allowsUndo = false
        
        // Calculate required size by measuring the attributed text
        let maxWidth = NSScreen.main?.visibleFrame.width ?? 1920 * 0.6
        let maxHeight = NSScreen.main?.visibleFrame.height ?? 1080 * 0.8
        let constraintSize = NSSize(width: maxWidth * 0.8, height: maxHeight * 0.8)
        
        let textSize = attributedText.boundingRect(
            with: constraintSize,
            options: [.usesLineFragmentOrigin, .usesFontLeading]
        ).size
        let padding: CGFloat = 30  // Increased padding for better readability
        
        let windowSize = NSSize(
            width: min(textSize.width + padding * 2, maxWidth),
            height: min(textSize.height + padding * 2, maxHeight)
        )
        
        // Calculate position based on enum
        let screenFrame = NSScreen.main?.visibleFrame ?? NSRect.zero
        let windowOrigin: NSPoint
        
        switch position {
        case .center:
            windowOrigin = NSPoint(
                x: screenFrame.midX - windowSize.width / 2,
                y: screenFrame.midY - windowSize.height / 2
            )
        case .topLeft:
            windowOrigin = NSPoint(
                x: screenFrame.minX + 20,
                y: screenFrame.maxY - windowSize.height - 20
            )
        case .topRight:
            windowOrigin = NSPoint(
                x: screenFrame.maxX - windowSize.width - 20,
                y: screenFrame.maxY - windowSize.height - 20
            )
        case .bottomLeft:
            windowOrigin = NSPoint(
                x: screenFrame.minX + 20,
                y: screenFrame.minY + 20
            )
        case .bottomRight:
            windowOrigin = NSPoint(
                x: screenFrame.maxX - windowSize.width - 20,
                y: screenFrame.minY + 20
            )
        }
        
        let windowRect = NSRect(origin: windowOrigin, size: windowSize)
        
        let window = NSWindow(
            contentRect: windowRect,
            styleMask: .borderless,
            backing: .buffered,
            defer: false
        )
        
        // Window styling
        window.backgroundColor = NSColor.clear
        window.isOpaque = false
        window.hasShadow = false
        window.ignoresMouseEvents = true
        window.collectionBehavior = [.canJoinAllSpaces, .stationary]
        
        // Create background view with rounded corners and transparency
        let backgroundView = NSView(frame: NSRect(origin: .zero, size: windowSize))
        backgroundView.wantsLayer = true
        backgroundView.layer?.backgroundColor = NSColor.black.withAlphaComponent(0.9).cgColor  // Slightly more opaque
        backgroundView.layer?.cornerRadius = 12
        
        // Position text view to fill the available space with padding
        textView.frame = NSRect(
            x: padding,
            y: padding,
            width: windowSize.width - padding * 2,
            height: windowSize.height - padding * 2
        )
        
        backgroundView.addSubview(textView)
        window.contentView = backgroundView
        
        // Add fade-in animation
        window.alphaValue = 0.0
        NSAnimationContext.runAnimationGroup { context in
            context.duration = 0.3
            window.animator().alphaValue = 1.0
        }
        
        return window
    }
    
    private static func hideWindow(_ window: NSWindow) {
        // Fade-out animation
        NSAnimationContext.runAnimationGroup({ context in
            context.duration = 0.3
            window.animator().alphaValue = 0.0
        }, completionHandler: {
            window.orderOut(nil)
            // Remove from active windows array
            activeWindows.removeAll { $0 === window }
        })
    }
    
    // Helper method to immediately hide all floating windows
    static func hideAllFloatingWindows() {
        for window in activeWindows {
            hideWindow(window)
        }
    }
    
    // Demo method to show multiple overlapping windows
    static func showMultipleDemo() {
        showFloatingWindow(text: "First Window", position: .center, duration: 4.0)
        
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
            showFloatingWindow(text: "Second Window", position: .topRight, duration: 3.5)
        }
        
        DispatchQueue.main.asyncAfter(deadline: .now() + 1.0) {
            showFloatingWindow(text: "Third Window", position: .bottomLeft, duration: 3.0)
        }
    }
}