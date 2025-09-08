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
    private static var activePopupWindow: NSWindow?
    private static var popupTimer: Timer?
    
    static func showFloatingWindow(text: String, position: FloatingPosition = .center, duration: TimeInterval = 2.0, fontSize: CGFloat = 16) {
        showFloatingWindow(attributedText: NSAttributedString(string: text), position: position, duration: duration, fontSize: fontSize)
    }
    
    static func showFloatingWindow(attributedText: NSAttributedString, position: FloatingPosition = .center, duration: TimeInterval = 2.0, fontSize: CGFloat = 16) {
        showFloatingWindow(attributedText: attributedText, images: [], position: position, duration: duration, fontSize: fontSize)
    }
    
    /// Shows a floating window with text and optional images, reusing active popup if available
    static func showFloatingWindow(attributedText: NSAttributedString, images: [(NSImage, String)] = [], position: FloatingPosition = .center, duration: TimeInterval = 2.0, fontSize: CGFloat = 16) {
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
        
        // Check if we have an active popup to reuse
        if let activePopup = activePopupWindow, activePopup.isVisible {
            // Reuse existing popup - update content, reset timer and opacity
            reuseActivePopup(window: activePopup, attributedText: attributedText, images: images, position: actualPosition, fontSize: fontSize, duration: settingsDuration)
        } else {
            // Create new popup
            let window = createTerminalStyleFloatingWindow(attributedText: attributedText, images: images, position: actualPosition, fontSize: fontSize)
            activeWindows.append(window)
            activePopupWindow = window
            
            window.makeKeyAndOrderFront(nil)
            window.level = NSWindow.Level(rawValue: Int(CGWindowLevelForKey(.floatingWindow)))
            
            // Schedule close timer
            schedulePopupClose(window: window, duration: settingsDuration)
        }
    }
    
    /// Reuses an active popup window by updating its content, resetting timer and opacity
    private static func reuseActivePopup(window: NSWindow, attributedText: NSAttributedString, images: [(NSImage, String)], position: FloatingPosition, fontSize: CGFloat, duration: TimeInterval) {
        // Cancel existing timer
        popupTimer?.invalidate()
        popupTimer = nil
        
        // Reset opacity to full
        window.alphaValue = 1.0
        
        // Update window content
        updatePopupContent(window: window, attributedText: attributedText, images: images, position: position, fontSize: fontSize)
        
        // Schedule new close timer
        schedulePopupClose(window: window, duration: duration)
    }
    
    /// Updates the content of an existing popup window
    private static func updatePopupContent(window: NSWindow, attributedText: NSAttributedString, images: [(NSImage, String)], position: FloatingPosition, fontSize: CGFloat) {
        // Always recreate the entire content view to handle switching between different popup types
        // This ensures we properly switch between text-only and image layouts
        let maxWidth = NSScreen.main?.visibleFrame.width ?? 1920 * 0.6
        let maxHeight = NSScreen.main?.visibleFrame.height ?? 1080 * 0.8
        let padding: CGFloat = 24
        
        // Calculate new window size based on content
        var totalWidth: CGFloat = 0
        var totalHeight: CGFloat = 0
        
        if images.isEmpty {
            // Calculate size for text-only content
            let terminalText = createTerminalTextContent(attributedText: attributedText, fontSize: fontSize, maxWidth: maxWidth)
            let textSize = terminalText.boundingRect(
                with: NSSize(width: maxWidth * 0.8, height: maxHeight * 0.8),
                options: [.usesLineFragmentOrigin, .usesFontLeading]
            ).size
            totalWidth = textSize.width
            totalHeight = textSize.height
            
            // Update with text-only content
            updateToTextOnlyLayout(window: window, attributedText: attributedText, fontSize: fontSize, padding: padding, windowSize: NSSize(width: totalWidth + padding * 2, height: totalHeight + padding * 2), position: position)
        } else {
            // Calculate size for image content
            let textSize = attributedText.boundingRect(
                with: NSSize(width: maxWidth * 0.8, height: maxHeight * 0.8),
                options: [.usesLineFragmentOrigin, .usesFontLeading]
            ).size
            
            let config = ConfigurationManager.shared.loadConfig()?.windowPreview ?? WindowPreviewConfig()
            totalWidth = max(textSize.width, config.maxWidth + 12 + 200)
            totalHeight = textSize.height + (config.maxHeight + 8) * CGFloat(images.count)
            
            // Update with image content
            updateToImageLayout(window: window, attributedText: attributedText, images: images, fontSize: fontSize, padding: padding, windowSize: NSSize(width: totalWidth + padding * 2, height: totalHeight + padding * 2), position: position)
        }
    }
    
    /// Updates window to text-only layout and repositions it
    private static func updateToTextOnlyLayout(window: NSWindow, attributedText: NSAttributedString, fontSize: CGFloat, padding: CGFloat, windowSize: NSSize, position: FloatingPosition) {
        // Calculate new position
        let windowOrigin = calculateWindowOrigin(position: position, windowSize: windowSize)
        
        // Create terminal-style background
        let backgroundView = NSView(frame: NSRect(origin: .zero, size: windowSize))
        backgroundView.wantsLayer = true
        backgroundView.layer?.backgroundColor = NSColor.black.withAlphaComponent(0.9).cgColor
        backgroundView.layer?.cornerRadius = 6
        
        // Subtle shadow effect
        backgroundView.layer?.shadowColor = NSColor.black.withAlphaComponent(0.3).cgColor
        backgroundView.layer?.shadowOffset = NSSize(width: 0, height: 2)
        backgroundView.layer?.shadowRadius = 4
        backgroundView.layer?.shadowOpacity = 0.5
        
        // Create text content
        let maxWidth = NSScreen.main?.visibleFrame.width ?? 1920 * 0.6
        let terminalText = createTerminalTextContent(attributedText: attributedText, fontSize: fontSize, maxWidth: maxWidth)
        
        // Create text view
        let textView = NSTextView()
        textView.textStorage?.setAttributedString(terminalText)
        textView.backgroundColor = NSColor.clear
        textView.isEditable = false
        textView.isSelectable = false
        textView.alignment = .center
        textView.textContainer?.widthTracksTextView = true
        textView.textContainer?.containerSize = NSSize(width: windowSize.width - padding * 2, height: .greatestFiniteMagnitude)
        textView.frame = NSRect(
            x: padding,
            y: padding,
            width: windowSize.width - padding * 2,
            height: windowSize.height - padding * 2
        )
        
        backgroundView.addSubview(textView)
        
        // Update window content and frame instantly
        window.contentView = backgroundView
        window.setFrame(NSRect(origin: windowOrigin, size: windowSize), display: true, animate: false)
    }
    
    /// Updates window to image layout and repositions it
    private static func updateToImageLayout(window: NSWindow, attributedText: NSAttributedString, images: [(NSImage, String)], fontSize: CGFloat, padding: CGFloat, windowSize: NSSize, position: FloatingPosition) {
        // Calculate new position
        let windowOrigin = calculateWindowOrigin(position: position, windowSize: windowSize)
        
        // Create container view
        let containerView = NSView()
        containerView.wantsLayer = true
        containerView.layer?.backgroundColor = NSColor.black.withAlphaComponent(0.9).cgColor
        containerView.layer?.cornerRadius = 6
        
        // Create content stack view
        let stackView = NSStackView()
        stackView.orientation = .vertical
        stackView.alignment = .leading
        stackView.spacing = 10
        stackView.translatesAutoresizingMaskIntoConstraints = false
        
        // Add header text
        let textView = NSTextView()
        textView.textStorage?.setAttributedString(attributedText)
        textView.font = NSFont.monospacedSystemFont(ofSize: fontSize, weight: .medium)
        textView.textColor = NSColor.white
        textView.backgroundColor = NSColor.clear
        textView.isEditable = false
        textView.isSelectable = false
        textView.alignment = .left
        textView.isRichText = true
        textView.allowsUndo = false
        textView.isVerticallyResizable = false
        textView.isHorizontallyResizable = false
        textView.textContainer?.widthTracksTextView = true
        
        let maxWidth = NSScreen.main?.visibleFrame.width ?? 1920 * 0.6
        let maxHeight = NSScreen.main?.visibleFrame.height ?? 1080 * 0.8
        let textSize = attributedText.boundingRect(
            with: NSSize(width: maxWidth * 0.8, height: maxHeight * 0.8),
            options: [.usesLineFragmentOrigin, .usesFontLeading]
        ).size
        
        textView.frame = NSRect(origin: .zero, size: textSize)
        stackView.addArrangedSubview(textView)
        
        // Add images
        if !images.isEmpty {
            let imageStackView = NSStackView()
            imageStackView.orientation = .vertical
            imageStackView.alignment = .leading
            imageStackView.spacing = 8
            
            for (image, title) in images {
                let imageRowView = NSStackView()
                imageRowView.orientation = .horizontal
                imageRowView.alignment = .top
                imageRowView.spacing = 12
                
                let imageView = NSImageView()
                imageView.image = image
                imageView.imageScaling = .scaleProportionallyUpOrDown
                imageView.wantsLayer = true
                imageView.layer?.cornerRadius = 4
                
                let config = ConfigurationManager.shared.loadConfig()?.windowPreview ?? WindowPreviewConfig()
                imageView.frame = NSRect(origin: .zero, size: NSSize(width: config.maxWidth, height: config.maxHeight))
                imageRowView.addArrangedSubview(imageView)
                
                let titleLabel = NSTextField(labelWithString: title)
                titleLabel.textColor = NSColor.white
                titleLabel.font = NSFont.monospacedSystemFont(ofSize: fontSize - 2, weight: .medium)
                titleLabel.backgroundColor = NSColor.clear
                titleLabel.cell?.wraps = true
                titleLabel.setContentHuggingPriority(.defaultLow, for: .horizontal)
                imageRowView.addArrangedSubview(titleLabel)
                
                imageStackView.addArrangedSubview(imageRowView)
            }
            
            stackView.addArrangedSubview(imageStackView)
        }
        
        // Setup container view
        containerView.frame = NSRect(origin: .zero, size: windowSize)
        containerView.addSubview(stackView)
        
        // Setup constraints for stack view
        stackView.topAnchor.constraint(equalTo: containerView.topAnchor, constant: padding).isActive = true
        stackView.leadingAnchor.constraint(equalTo: containerView.leadingAnchor, constant: padding).isActive = true
        stackView.trailingAnchor.constraint(lessThanOrEqualTo: containerView.trailingAnchor, constant: -padding).isActive = true
        stackView.bottomAnchor.constraint(lessThanOrEqualTo: containerView.bottomAnchor, constant: -padding).isActive = true
        
        // Update window content and frame instantly
        window.contentView = containerView
        window.setFrame(NSRect(origin: windowOrigin, size: windowSize), display: true, animate: false)
    }
    
    /// Schedules the popup window to close after the specified duration
    private static func schedulePopupClose(window: NSWindow, duration: TimeInterval) {
        popupTimer?.invalidate()
        popupTimer = Timer.scheduledTimer(withTimeInterval: duration, repeats: false) { _ in
            closePopup(window)
        }
    }
    
    /// Closes the popup window and cleans up references
    private static func closePopup(_ window: NSWindow) {
        popupTimer?.invalidate()
        popupTimer = nil
        
        if activePopupWindow == window {
            activePopupWindow = nil
        }
        
        hideWindow(window)
    }
    
    /// Helper to find the text view in a view hierarchy
    private static func findTextView(in view: NSView) -> NSTextView? {
        if let textView = view as? NSTextView {
            return textView
        }
        
        for subview in view.subviews {
            if let textView = findTextView(in: subview) {
                return textView
            }
        }
        
        return nil
    }
    
    /// Creates a terminal-style floating window with ASCII borders and monospace styling
    private static func createTerminalStyleFloatingWindow(attributedText: NSAttributedString, images: [(NSImage, String)] = [], position: FloatingPosition, fontSize: CGFloat = 16) -> NSWindow {
        let maxWidth = NSScreen.main?.visibleFrame.width ?? 1920 * 0.6
        let maxHeight = NSScreen.main?.visibleFrame.height ?? 1080 * 0.8
        let padding: CGFloat = 24
        
        // If no images, use simple terminal text layout
        if images.isEmpty {
            return createTerminalTextWindow(attributedText: attributedText, position: position, fontSize: fontSize)
        }
        
        // Create container view for images layout without outer border
        let containerView = NSView()
        containerView.wantsLayer = true
        containerView.layer?.backgroundColor = NSColor.black.withAlphaComponent(0.9).cgColor
        containerView.layer?.cornerRadius = 6
        
        // Create content stack view
        let stackView = NSStackView()
        stackView.orientation = .vertical
        stackView.alignment = .leading
        stackView.spacing = 10
        stackView.translatesAutoresizingMaskIntoConstraints = false
        
        // Add header text
        let textView = NSTextView()
        textView.textStorage?.setAttributedString(attributedText)
        textView.font = NSFont.monospacedSystemFont(ofSize: fontSize, weight: .medium)
        textView.textColor = NSColor.white
        textView.backgroundColor = NSColor.clear
        textView.isEditable = false
        textView.isSelectable = false
        textView.alignment = .left
        textView.isRichText = true
        textView.allowsUndo = false
        textView.isVerticallyResizable = false
        textView.isHorizontallyResizable = false
        textView.textContainer?.widthTracksTextView = true
        
        let textSize = attributedText.boundingRect(
            with: NSSize(width: maxWidth * 0.8, height: maxHeight * 0.8),
            options: [.usesLineFragmentOrigin, .usesFontLeading]
        ).size
        
        textView.frame = NSRect(origin: .zero, size: textSize)
        stackView.addArrangedSubview(textView)
        
        var totalWidth = textSize.width
        var totalHeight = textSize.height
        
        // Add images if provided
        if !images.isEmpty {
            let imageStackView = NSStackView()
            imageStackView.orientation = .vertical
            imageStackView.alignment = .leading
            imageStackView.spacing = 8
            
            for (image, title) in images {
                // Create horizontal container for image + text
                let imageRowView = NSStackView()
                imageRowView.orientation = .horizontal
                imageRowView.alignment = .top
                imageRowView.spacing = 12
                
                // Add image
                let imageView = NSImageView()
                imageView.image = image
                imageView.imageScaling = .scaleProportionallyUpOrDown
                imageView.wantsLayer = true
                imageView.layer?.cornerRadius = 4
                
                let config = ConfigurationManager.shared.loadConfig()?.windowPreview ?? WindowPreviewConfig()
                imageView.frame = NSRect(origin: .zero, size: NSSize(width: config.maxWidth, height: config.maxHeight))
                imageRowView.addArrangedSubview(imageView)
                
                // Add title
                let titleLabel = NSTextField(labelWithString: title)
                titleLabel.textColor = NSColor.white
                titleLabel.font = NSFont.monospacedSystemFont(ofSize: fontSize - 2, weight: .medium)
                titleLabel.backgroundColor = NSColor.clear
                titleLabel.cell?.wraps = true
                titleLabel.setContentHuggingPriority(.defaultLow, for: .horizontal)
                imageRowView.addArrangedSubview(titleLabel)
                
                imageStackView.addArrangedSubview(imageRowView)
                
                // Update total dimensions
                totalWidth = max(totalWidth, config.maxWidth + 12 + 200)
                totalHeight += config.maxHeight + 8
            }
            
            stackView.addArrangedSubview(imageStackView)
        }
        
        // Calculate final window size
        let windowSize = NSSize(
            width: min(totalWidth + padding * 2, maxWidth),
            height: min(totalHeight + padding * 2, maxHeight)
        )
        
        // Calculate position
        let windowOrigin = calculateWindowOrigin(position: position, windowSize: windowSize)
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
        window.hasShadow = true
        window.ignoresMouseEvents = true
        window.collectionBehavior = [.canJoinAllSpaces, .stationary]
        
        // Setup container view
        containerView.frame = NSRect(origin: .zero, size: windowSize)
        containerView.addSubview(stackView)
        
        // Setup constraints for stack view
        stackView.topAnchor.constraint(equalTo: containerView.topAnchor, constant: padding).isActive = true
        stackView.leadingAnchor.constraint(equalTo: containerView.leadingAnchor, constant: padding).isActive = true
        stackView.trailingAnchor.constraint(lessThanOrEqualTo: containerView.trailingAnchor, constant: -padding).isActive = true
        stackView.bottomAnchor.constraint(lessThanOrEqualTo: containerView.bottomAnchor, constant: -padding).isActive = true
        
        window.contentView = containerView
        
        // Add fade-in animation
        window.alphaValue = 0.0
        NSAnimationContext.runAnimationGroup { context in
            context.duration = 0.2
            context.timingFunction = CAMediaTimingFunction(name: .easeInEaseOut)
            window.animator().alphaValue = 1.0
        }
        
        return window
    }
    
    private static func createFloatingWindow(attributedText: NSAttributedString, images: [(NSImage, String)] = [], position: FloatingPosition, fontSize: CGFloat = 16) -> NSWindow {
        let maxWidth = NSScreen.main?.visibleFrame.width ?? 1920 * 0.6
        let maxHeight = NSScreen.main?.visibleFrame.height ?? 1080 * 0.8
        let padding: CGFloat = 20
        
        // If no images, use simple text-only layout for better compatibility
        if images.isEmpty {
            return createSimpleTextWindow(attributedText: attributedText, position: position, fontSize: fontSize, maxWidth: maxWidth, maxHeight: maxHeight, padding: padding)
        }
        
        // Create container view for complex layout with images
        let containerView = NSView()
        containerView.wantsLayer = true
        containerView.layer?.backgroundColor = NSColor.black.withAlphaComponent(0.85).cgColor
        containerView.layer?.cornerRadius = 8
        
        // Create content stack view
        let stackView = NSStackView()
        stackView.orientation = .vertical
        stackView.alignment = .leading
        stackView.spacing = 10
        stackView.translatesAutoresizingMaskIntoConstraints = false
        
        // Add header text
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
        textView.isVerticallyResizable = false
        textView.isHorizontallyResizable = false
        textView.textContainer?.widthTracksTextView = true
        
        let textSize = attributedText.boundingRect(
            with: NSSize(width: maxWidth * 0.8, height: maxHeight * 0.8),
            options: [.usesLineFragmentOrigin, .usesFontLeading]
        ).size
        
        textView.frame = NSRect(origin: .zero, size: textSize)
        stackView.addArrangedSubview(textView)
        
        var totalWidth = textSize.width
        var totalHeight = textSize.height
        
        // Add images if provided
        if !images.isEmpty {
            let imageStackView = NSStackView()
            imageStackView.orientation = .vertical
            imageStackView.alignment = .leading
            imageStackView.spacing = 8
            
            for (image, title) in images {
                // Create horizontal container for image + text
                let imageRowView = NSStackView()
                imageRowView.orientation = .horizontal
                imageRowView.alignment = .top
                imageRowView.spacing = 12
                
                // Add image
                let imageView = NSImageView()
                imageView.image = image
                imageView.imageScaling = .scaleProportionallyUpOrDown
                imageView.wantsLayer = true
                imageView.layer?.cornerRadius = 4
                imageView.layer?.borderWidth = 1
                imageView.layer?.borderColor = NSColor.gray.withAlphaComponent(0.3).cgColor
                
                let config = ConfigurationManager.shared.loadConfig()?.windowPreview ?? WindowPreviewConfig()
                imageView.frame = NSRect(origin: .zero, size: NSSize(width: config.maxWidth, height: config.maxHeight))
                imageRowView.addArrangedSubview(imageView)
                
                // Add title
                let titleLabel = NSTextField(labelWithString: title)
                titleLabel.textColor = NSColor.white
                titleLabel.font = NSFont.systemFont(ofSize: fontSize - 2)
                titleLabel.backgroundColor = NSColor.clear
                titleLabel.cell?.wraps = true
                titleLabel.setContentHuggingPriority(.defaultLow, for: .horizontal)
                imageRowView.addArrangedSubview(titleLabel)
                
                imageStackView.addArrangedSubview(imageRowView)
                
                // Update total dimensions
                totalWidth = max(totalWidth, config.maxWidth + 12 + 200) // image + spacing + estimated text width
                totalHeight += config.maxHeight + 8 // image height + spacing
            }
            
            stackView.addArrangedSubview(imageStackView)
        }
        
        // Calculate final window size
        let windowSize = NSSize(
            width: min(totalWidth + padding * 2, maxWidth),
            height: min(totalHeight + padding * 2, maxHeight)
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
        
        // Setup container view
        containerView.frame = NSRect(origin: .zero, size: windowSize)
        containerView.addSubview(stackView)
        
        // Setup constraints for stack view
        stackView.topAnchor.constraint(equalTo: containerView.topAnchor, constant: padding).isActive = true
        stackView.leadingAnchor.constraint(equalTo: containerView.leadingAnchor, constant: padding).isActive = true
        stackView.trailingAnchor.constraint(lessThanOrEqualTo: containerView.trailingAnchor, constant: -padding).isActive = true
        stackView.bottomAnchor.constraint(lessThanOrEqualTo: containerView.bottomAnchor, constant: -padding).isActive = true
        
        window.contentView = containerView
        
        // Add fade-in animation
        window.alphaValue = 0.0
        NSAnimationContext.runAnimationGroup { context in
            context.duration = 0.3
            window.animator().alphaValue = 1.0
        }
        
        return window
    }
    
    /// Creates clean terminal content without borders for images
    private static func createTerminalContentWithImages(attributedText: NSAttributedString, images: [(NSImage, String)], fontSize: CGFloat, maxWidth: CGFloat) -> NSAttributedString {
        let result = NSMutableAttributedString()
        let terminalFont = NSFont.monospacedSystemFont(ofSize: fontSize, weight: .medium)
        let textColor = NSColor.white
        let secondaryColor = NSColor.systemGray
        
        // Add main text without borders
        let mainTextLines = attributedText.string.components(separatedBy: .newlines)
        for line in mainTextLines {
            let cleanLine = line.trimmingCharacters(in: .whitespaces)
            if !cleanLine.isEmpty {
                result.append(NSAttributedString(string: " \(cleanLine)\n", attributes: [
                    .font: terminalFont,
                    .foregroundColor: textColor
                ]))
            }
        }
        
        // Add spacing before images
        if !images.isEmpty {
            result.append(NSAttributedString(string: "\n", attributes: [
                .font: terminalFont,
                .foregroundColor: textColor
            ]))
            
            // Add image entries with clean formatting
            for (index, (_, title)) in images.enumerated() {
                let cleanTitle = title.trimmingCharacters(in: .whitespaces)
                let imageEntry = " [\(index + 1)] \(cleanTitle)\n"
                result.append(NSAttributedString(string: imageEntry, attributes: [
                    .font: terminalFont,
                    .foregroundColor: secondaryColor
                ]))
            }
        }
        
        return result
    }
    
    // Helper function for text truncation
    private static func truncateString(_ string: String, maxLength: Int) -> String {
        if string.count <= maxLength {
            return string
        } else {
            return String(string.prefix(maxLength - 3)) + "..."
        }
    }
    
    /// Creates a simple terminal-style text window
    private static func createTerminalTextWindow(attributedText: NSAttributedString, position: FloatingPosition, fontSize: CGFloat) -> NSWindow {
        let maxWidth = NSScreen.main?.visibleFrame.width ?? 1920 * 0.6
        let maxHeight = NSScreen.main?.visibleFrame.height ?? 1080 * 0.8
        let padding: CGFloat = 24
        
        // Create terminal-styled text with ASCII border
        let terminalText = createTerminalTextContent(attributedText: attributedText, fontSize: fontSize, maxWidth: maxWidth)
        
        let textSize = terminalText.boundingRect(
            with: NSSize(width: maxWidth * 0.8, height: maxHeight * 0.8),
            options: [.usesLineFragmentOrigin, .usesFontLeading]
        ).size
        
        let windowSize = NSSize(
            width: min(textSize.width + padding * 2, maxWidth),
            height: min(textSize.height + padding * 2, maxHeight)
        )
        
        let windowOrigin = calculateWindowOrigin(position: position, windowSize: windowSize)
        let windowRect = NSRect(origin: windowOrigin, size: windowSize)
        
        let window = NSWindow(
            contentRect: windowRect,
            styleMask: .borderless,
            backing: .buffered,
            defer: false
        )
        
        // Terminal-style window configuration
        window.backgroundColor = NSColor.clear
        window.isOpaque = false
        window.hasShadow = true
        window.ignoresMouseEvents = true
        window.collectionBehavior = [.canJoinAllSpaces, .stationary]
        
        // Create subtle terminal background without outer border
        let backgroundView = NSView(frame: NSRect(origin: .zero, size: windowSize))
        backgroundView.wantsLayer = true
        backgroundView.layer?.backgroundColor = NSColor.black.withAlphaComponent(0.9).cgColor
        backgroundView.layer?.cornerRadius = 6
        
        // Subtle shadow effect
        backgroundView.layer?.shadowColor = NSColor.black.withAlphaComponent(0.3).cgColor
        backgroundView.layer?.shadowOffset = NSSize(width: 0, height: 2)
        backgroundView.layer?.shadowRadius = 4
        backgroundView.layer?.shadowOpacity = 0.5
        
        // Create text view
        let textView = NSTextView()
        textView.textStorage?.setAttributedString(terminalText)
        textView.backgroundColor = NSColor.clear
        textView.isEditable = false
        textView.isSelectable = false
        textView.alignment = .center
        textView.textContainer?.widthTracksTextView = true
        textView.textContainer?.containerSize = NSSize(width: windowSize.width - padding * 2, height: .greatestFiniteMagnitude)
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
            context.duration = 0.2
            context.timingFunction = CAMediaTimingFunction(name: .easeInEaseOut)
            window.animator().alphaValue = 1.0
        }
        
        return window
    }
    
    /// Creates clean terminal-styled text content without borders
    private static func createTerminalTextContent(attributedText: NSAttributedString, fontSize: CGFloat, maxWidth: CGFloat) -> NSAttributedString {
        let result = NSMutableAttributedString()
        let terminalFont = NSFont.monospacedSystemFont(ofSize: fontSize, weight: .medium)
        let textColor = NSColor.white
        
        let text = attributedText.string
        
        // Clean content - centered without extra padding
        let lines = text.components(separatedBy: .newlines)
        for (index, line) in lines.enumerated() {
            let cleanLine = line.trimmingCharacters(in: .whitespaces)
            
            // Add line breaks between sections but don't add extra spaces
            if index > 0 && !cleanLine.isEmpty {
                result.append(NSAttributedString(string: "\n", attributes: [
                    .font: terminalFont,
                    .foregroundColor: textColor
                ]))
            }
            
            if !cleanLine.isEmpty {
                result.append(NSAttributedString(string: cleanLine + "\n", attributes: [
                    .font: terminalFont,
                    .foregroundColor: textColor,
                    .paragraphStyle: {
                        let style = NSMutableParagraphStyle()
                        style.alignment = .center
                        return style
                    }()
                ]))
            }
        }
        
        return result
    }
    
    /// Helper to calculate window origin based on position
    private static func calculateWindowOrigin(position: FloatingPosition, windowSize: NSSize) -> NSPoint {
        let screenFrame = NSScreen.main?.visibleFrame ?? NSRect.zero
        
        switch position {
        case .center:
            return NSPoint(
                x: screenFrame.midX - windowSize.width / 2,
                y: screenFrame.midY - windowSize.height / 2
            )
        case .topLeft:
            return NSPoint(
                x: screenFrame.minX + 20,
                y: screenFrame.maxY - windowSize.height - 20
            )
        case .topRight:
            return NSPoint(
                x: screenFrame.maxX - windowSize.width - 20,
                y: screenFrame.maxY - windowSize.height - 20
            )
        case .bottomLeft:
            return NSPoint(
                x: screenFrame.minX + 20,
                y: screenFrame.minY + 20
            )
        case .bottomRight:
            return NSPoint(
                x: screenFrame.maxX - windowSize.width - 20,
                y: screenFrame.minY + 20
            )
        }
    }
    
    /// Creates a simple text-only floating window (original implementation)
    private static func createSimpleTextWindow(attributedText: NSAttributedString, position: FloatingPosition, fontSize: CGFloat, maxWidth: CGFloat, maxHeight: CGFloat, padding: CGFloat) -> NSWindow {
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
        let constraintSize = NSSize(width: maxWidth * 0.8, height: maxHeight * 0.8)
        
        let textSize = attributedText.boundingRect(
            with: constraintSize,
            options: [.usesLineFragmentOrigin, .usesFontLeading]
        ).size
        
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
        backgroundView.layer?.backgroundColor = NSColor.black.withAlphaComponent(0.9).cgColor
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

// MARK: - Window Screenshot Utility
class WindowScreenshotCapture {
    private static var cache: [CGWindowID: (image: NSImage, timestamp: TimeInterval)] = [:]
    
    /// Captures a screenshot of a specific window
    /// - Parameters:
    ///   - windowID: The window ID to capture
    ///   - maxSize: Maximum size for the captured image
    /// - Returns: NSImage of the window, scaled to maxSize if necessary
    static func captureWindow(windowID: CGWindowID, maxSize: NSSize = NSSize(width: 200, height: 150)) -> NSImage? {
        let config = ConfigurationManager.shared.loadConfig()?.windowPreview ?? WindowPreviewConfig()
        
        // Check cache first
        if let cached = cache[windowID], 
           Date().timeIntervalSince1970 - cached.timestamp < config.cacheTimeoutSeconds {
            return cached.image
        }
        
        // Capture window screenshot
        guard let cgImage = CGWindowListCreateImage(
            .null,
            .optionIncludingWindow,
            windowID,
            [.boundsIgnoreFraming, .bestResolution]
        ) else {
            return nil
        }
        
        let originalImage = NSImage(cgImage: cgImage, size: .zero)
        let scaledImage = scaleImage(originalImage, to: maxSize)
        
        // Cache the result
        cache[windowID] = (image: scaledImage, timestamp: Date().timeIntervalSince1970)
        
        // Clean up old cache entries
        cleanupCache(maxAge: config.cacheTimeoutSeconds)
        
        return scaledImage
    }
    
    /// Scales an image to fit within the specified size while maintaining aspect ratio
    private static func scaleImage(_ image: NSImage, to maxSize: NSSize) -> NSImage {
        let originalSize = image.size
        let aspectRatio = originalSize.width / originalSize.height
        
        var newSize = maxSize
        
        if aspectRatio > (maxSize.width / maxSize.height) {
            // Width is the limiting factor
            newSize.height = maxSize.width / aspectRatio
        } else {
            // Height is the limiting factor  
            newSize.width = maxSize.height * aspectRatio
        }
        
        let scaledImage = NSImage(size: newSize)
        scaledImage.lockFocus()
        image.draw(in: NSRect(origin: .zero, size: newSize))
        scaledImage.unlockFocus()
        
        return scaledImage
    }
    
    /// Removes old entries from cache
    private static func cleanupCache(maxAge: TimeInterval) {
        let currentTime = Date().timeIntervalSince1970
        cache = cache.filter { currentTime - $0.value.timestamp < maxAge }
    }
    
    /// Clears the entire cache
    static func clearCache() {
        cache.removeAll()
    }
}