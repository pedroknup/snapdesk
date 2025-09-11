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
            
            // Set window level before showing to avoid positioning issues
            window.level = NSWindow.Level(rawValue: Int(CGWindowLevelForKey(.floatingWindow)))
            window.makeKeyAndOrderFront(nil)
            
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
            // Calculate dynamic width based on actual content sizes
            var maxRowWidth: CGFloat = textSize.width
            var totalImageHeight: CGFloat = 0
            
            for (image, title) in images {
                let originalSize = image.size
                let maxSize = NSSize(width: config.maxWidth, height: config.maxHeight)
                let aspectRatio = originalSize.width / originalSize.height
                var imageSize = maxSize
                
                if aspectRatio > (maxSize.width / maxSize.height) {
                    imageSize.height = maxSize.width / aspectRatio
                } else {
                    imageSize.width = maxSize.height * aspectRatio
                }
                
                // Calculate actual title width
                let cleanTitle = title
                    .replacingOccurrences(of: title.components(separatedBy: ".").first?.trimmingCharacters(in: .whitespaces) ?? "", with: "")
                    .replacingOccurrences(of: ". ", with: "")
                    .replacingOccurrences(of: " ◄", with: "")
                
                let titleFont = NSFont.systemFont(ofSize: fontSize - 1, weight: .regular)
                let titleSize = cleanTitle.boundingRect(
                    with: NSSize(width: CGFloat.greatestFiniteMagnitude, height: 30),
                    options: [.usesLineFragmentOrigin],
                    attributes: [.font: titleFont]
                ).size
                
                // Account for: number(35) + spacing(12) + image(actual width) + spacing(12) + title(actual width)
                let rowWidth = 35 + 12 + imageSize.width + 12 + titleSize.width
                maxRowWidth = max(maxRowWidth, rowWidth)
                totalImageHeight += imageSize.height + 12
            }
            
            totalWidth = maxRowWidth
            totalHeight = textSize.height + totalImageHeight
            
            // Update with image content
            updateToImageLayout(window: window, attributedText: attributedText, images: images, fontSize: fontSize, padding: padding, windowSize: NSSize(width: totalWidth + padding * 2, height: totalHeight + padding * 2), position: position)
        }
    }
    
    /// Updates window to text-only layout and repositions it
    private static func updateToTextOnlyLayout(window: NSWindow, attributedText: NSAttributedString, fontSize: CGFloat, padding: CGFloat, windowSize: NSSize, position: FloatingPosition) {
        // Calculate new position
        let windowOrigin = calculateWindowOrigin(position: position, windowSize: windowSize)
        
        // Create modern background for better contrast
        let backgroundView = NSView(frame: NSRect(origin: .zero, size: windowSize))
        backgroundView.wantsLayer = true
        backgroundView.layer?.backgroundColor = NSColor(calibratedWhite: 0.06, alpha: 0.95).cgColor
        backgroundView.layer?.cornerRadius = 16
        backgroundView.layer?.borderWidth = 1.0
        backgroundView.layer?.borderColor = NSColor(calibratedWhite: 1.0, alpha: 0.12).cgColor
        
        // Enhanced shadow for depth
        backgroundView.layer?.shadowColor = NSColor.black.cgColor
        backgroundView.layer?.shadowOffset = NSSize(width: 0, height: 8)
        backgroundView.layer?.shadowRadius = 24
        backgroundView.layer?.shadowOpacity = 0.4
        
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
        
        // Update window content and frame smoothly
        window.contentView = backgroundView
        let newFrame = NSRect(origin: windowOrigin, size: windowSize)
        if !window.frame.equalTo(newFrame) {
            window.setFrame(newFrame, display: false, animate: false)
        }
    }
    
    /// Updates window to image layout and repositions it
    private static func updateToImageLayout(window: NSWindow, attributedText: NSAttributedString, images: [(NSImage, String)], fontSize: CGFloat, padding: CGFloat, windowSize: NSSize, position: FloatingPosition) {
        // Calculate new position
        let windowOrigin = calculateWindowOrigin(position: position, windowSize: windowSize)
        
        // Create modern container with improved styling
        let containerView = NSView()
        containerView.wantsLayer = true
        containerView.layer?.backgroundColor = NSColor(calibratedWhite: 0.06, alpha: 0.95).cgColor
        containerView.layer?.cornerRadius = 16
        containerView.layer?.borderWidth = 1.0
        containerView.layer?.borderColor = NSColor(calibratedWhite: 1.0, alpha: 0.12).cgColor
        
        // Enhanced shadow for depth
        containerView.layer?.shadowColor = NSColor.black.cgColor
        containerView.layer?.shadowOffset = NSSize(width: 0, height: 8)
        containerView.layer?.shadowRadius = 24
        containerView.layer?.shadowOpacity = 0.4
        
        // Create content stack view
        let stackView = NSStackView()
        stackView.orientation = .vertical
        stackView.alignment = .leading
        stackView.spacing = 10
        stackView.translatesAutoresizingMaskIntoConstraints = false
        
        // Add header text with styled content
        let textView = NSTextView()
        
        // Create styled header with proper formatting
        let styledText = NSMutableAttributedString(attributedString: attributedText)
        let paragraphStyle = NSMutableParagraphStyle()
        paragraphStyle.alignment = .left
        paragraphStyle.lineSpacing = 4
        
        styledText.addAttributes([
            .font: NSFont.systemFont(ofSize: fontSize, weight: .semibold),
            .foregroundColor: NSColor(calibratedWhite: 0.95, alpha: 1.0),
            .paragraphStyle: paragraphStyle
        ], range: NSRange(location: 0, length: styledText.length))
        
        textView.textStorage?.setAttributedString(styledText)
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
            imageStackView.spacing = 10
            
            let config = ConfigurationManager.shared.loadConfig()
            let theme = config?.theme ?? ThemeConfig()
            
            for (image, title) in images {
                let imageRowView = NSStackView()
                imageRowView.orientation = .horizontal
                imageRowView.alignment = .centerY
                imageRowView.spacing = 12
                
                // Check if this is the active window (has the ◄ marker)
                let isActive = title.contains(" ◄")
                
                // Extract the number from the title (e.g., "1. WindowTitle ◄" -> "1")
                let numberString = title.components(separatedBy: ".").first?.trimmingCharacters(in: .whitespaces) ?? ""
                
                // Create simple number label
                let numberLabel = NSTextField(labelWithString: numberString)
                numberLabel.textColor = isActive ? theme.accentColor : NSColor(calibratedWhite: 0.85, alpha: 1.0)
                numberLabel.font = NSFont.systemFont(ofSize: fontSize + 2, weight: isActive ? .bold : .regular)
                numberLabel.backgroundColor = NSColor.clear
                numberLabel.isBordered = false
                numberLabel.alignment = .center
                numberLabel.frame = NSRect(origin: .zero, size: NSSize(width: 35, height: 35))
                
                imageRowView.addArrangedSubview(numberLabel)
                
                // Create image view sized to content
                let imageView = NSImageView()
                imageView.image = image
                imageView.imageScaling = .scaleProportionallyUpOrDown
                imageView.wantsLayer = true
                imageView.layer?.cornerRadius = 8
                imageView.layer?.masksToBounds = false
                
                // Calculate actual content size with aspect ratio
                let originalSize = image.size
                let windowPreviewConfig = config?.windowPreview ?? WindowPreviewConfig()
                let maxSize = NSSize(width: windowPreviewConfig.maxWidth, height: windowPreviewConfig.maxHeight)
                
                let aspectRatio = originalSize.width / originalSize.height
                var imageSize = maxSize
                
                if aspectRatio > (maxSize.width / maxSize.height) {
                    imageSize.height = maxSize.width / aspectRatio
                } else {
                    imageSize.width = maxSize.height * aspectRatio
                }
                
                // Improved styling with better visual hierarchy
                if isActive {
                    // Prominent highlight for active window
                    imageView.layer?.borderWidth = 3.0
                    imageView.layer?.borderColor = theme.accentColor.cgColor
                    imageView.alphaValue = 1.0
                    // Enhanced glow effect
                    imageView.layer?.shadowColor = theme.accentColor.cgColor
                    imageView.layer?.shadowOffset = NSSize(width: 0, height: 0)
                    imageView.layer?.shadowRadius = 8
                    imageView.layer?.shadowOpacity = 0.6
                    // Add inner glow
                    imageView.layer?.backgroundColor = theme.accentColor.withAlphaComponent(0.1).cgColor
                } else {
                    imageView.alphaValue = 0.75
                    imageView.layer?.borderWidth = 1.0
                    imageView.layer?.borderColor = NSColor(calibratedWhite: 0.4, alpha: 0.4).cgColor
                    // Subtle shadow for inactive windows
                    imageView.layer?.shadowColor = NSColor.black.cgColor
                    imageView.layer?.shadowOffset = NSSize(width: 0, height: 2)
                    imageView.layer?.shadowRadius = 4
                    imageView.layer?.shadowOpacity = 0.2
                }
                
                imageView.frame = NSRect(origin: .zero, size: imageSize)
                imageRowView.addArrangedSubview(imageView)
                
                // Extract title without number and marker
                let cleanTitle = title
                    .replacingOccurrences(of: "\(numberString). ", with: "")
                    .replacingOccurrences(of: " ◄", with: "")
                
                // Create title with dynamic sizing
                let titleLabel = NSTextField(labelWithString: cleanTitle)
                titleLabel.textColor = isActive ? theme.accentColor : NSColor(calibratedWhite: 0.8, alpha: 1.0)
                titleLabel.font = NSFont.systemFont(ofSize: fontSize - 1, weight: isActive ? .semibold : .regular)
                titleLabel.backgroundColor = NSColor.clear
                titleLabel.isBordered = false
                titleLabel.cell?.wraps = false
                titleLabel.cell?.lineBreakMode = .byTruncatingTail
                titleLabel.alignment = .left
                titleLabel.sizeToFit()
                
                imageRowView.addArrangedSubview(titleLabel)
                
                imageStackView.addArrangedSubview(imageRowView)
            }
            
            stackView.addArrangedSubview(imageStackView)
        }
        
        // Setup container view
        containerView.frame = NSRect(origin: .zero, size: windowSize)
        containerView.addSubview(stackView)
        
        // Setup constraints for stack view to hug content
        stackView.topAnchor.constraint(equalTo: containerView.topAnchor, constant: padding).isActive = true
        stackView.leadingAnchor.constraint(equalTo: containerView.leadingAnchor, constant: padding).isActive = true
        stackView.trailingAnchor.constraint(equalTo: containerView.trailingAnchor, constant: -padding).isActive = true
        stackView.bottomAnchor.constraint(equalTo: containerView.bottomAnchor, constant: -padding).isActive = true
        
        // Set content hugging priority to prevent unnecessary expansion
        stackView.setHuggingPriority(.defaultHigh, for: .horizontal)
        stackView.setHuggingPriority(.defaultHigh, for: .vertical)
        
        // Update window content and frame smoothly
        window.contentView = containerView
        let newFrame = NSRect(origin: windowOrigin, size: windowSize)
        if !window.frame.equalTo(newFrame) {
            window.setFrame(newFrame, display: false, animate: false)
        }
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
        
        // Create modern container for images layout
        let containerView = NSView()
        containerView.wantsLayer = true
        containerView.layer?.backgroundColor = NSColor(calibratedWhite: 0.06, alpha: 0.95).cgColor
        containerView.layer?.cornerRadius = 16
        containerView.layer?.borderWidth = 1.0
        containerView.layer?.borderColor = NSColor(calibratedWhite: 1.0, alpha: 0.12).cgColor
        
        // Enhanced shadow for depth
        containerView.layer?.shadowColor = NSColor.black.cgColor
        containerView.layer?.shadowOffset = NSSize(width: 0, height: 8)
        containerView.layer?.shadowRadius = 24
        containerView.layer?.shadowOpacity = 0.4
        
        // Create content stack view
        let stackView = NSStackView()
        stackView.orientation = .vertical
        stackView.alignment = .leading
        stackView.spacing = 10
        stackView.translatesAutoresizingMaskIntoConstraints = false
        
        // Add header text with styled content
        let textView = NSTextView()
        
        // Create styled header with proper formatting
        let styledText = NSMutableAttributedString(attributedString: attributedText)
        let paragraphStyle = NSMutableParagraphStyle()
        paragraphStyle.alignment = .left
        paragraphStyle.lineSpacing = 4
        
        styledText.addAttributes([
            .font: NSFont.systemFont(ofSize: fontSize, weight: .semibold),
            .foregroundColor: NSColor(calibratedWhite: 0.95, alpha: 1.0),
            .paragraphStyle: paragraphStyle
        ], range: NSRange(location: 0, length: styledText.length))
        
        textView.textStorage?.setAttributedString(styledText)
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
            
            let config = ConfigurationManager.shared.loadConfig()
            let theme = config?.theme ?? ThemeConfig()
            let windowPreviewConfig = config?.windowPreview ?? WindowPreviewConfig()
            
            for (image, title) in images {
                // Check if this is the active window (has the ◄ marker)
                let isActive = title.contains(" ◄")
                
                // Extract the number from the title (e.g., "1. WindowTitle ◄" -> "1")
                let numberString = title.components(separatedBy: ".").first?.trimmingCharacters(in: .whitespaces) ?? ""
                
                // Create horizontal container for number + image + text
                let imageRowView = NSStackView()
                imageRowView.orientation = .horizontal
                imageRowView.alignment = .centerY
                imageRowView.spacing = 12
                
                // Add number label on the left
                let numberLabel = NSTextField(labelWithString: numberString)
                numberLabel.textColor = isActive ? theme.accentColor : NSColor.white
                numberLabel.font = NSFont.systemFont(ofSize: fontSize + 2, weight: isActive ? .bold : .regular)
                numberLabel.backgroundColor = NSColor.clear
                numberLabel.alignment = .center
                let numberWidth: CGFloat = 35
                numberLabel.frame = NSRect(origin: .zero, size: NSSize(width: numberWidth, height: 35))
                imageRowView.addArrangedSubview(numberLabel)
                
                // Calculate actual content size with aspect ratio
                let originalSize = image.size
                let maxSize = NSSize(width: windowPreviewConfig.maxWidth, height: windowPreviewConfig.maxHeight)
                let aspectRatio = originalSize.width / originalSize.height
                var imageSize = maxSize
                
                if aspectRatio > (maxSize.width / maxSize.height) {
                    imageSize.height = maxSize.width / aspectRatio
                } else {
                    imageSize.width = maxSize.height * aspectRatio
                }
                
                // Add image with improved styling
                let imageView = NSImageView()
                imageView.image = image
                imageView.imageScaling = .scaleProportionallyUpOrDown
                imageView.wantsLayer = true
                imageView.layer?.cornerRadius = 8
                imageView.layer?.masksToBounds = false
                
                if isActive {
                    imageView.layer?.borderWidth = 3.0
                    imageView.layer?.borderColor = theme.accentColor.cgColor
                    imageView.alphaValue = 1.0
                    imageView.layer?.shadowColor = theme.accentColor.cgColor
                    imageView.layer?.shadowOffset = NSSize(width: 0, height: 0)
                    imageView.layer?.shadowRadius = 8
                    imageView.layer?.shadowOpacity = 0.6
                    imageView.layer?.backgroundColor = theme.accentColor.withAlphaComponent(0.1).cgColor
                } else {
                    imageView.alphaValue = 0.75
                    imageView.layer?.borderWidth = 1.0
                    imageView.layer?.borderColor = NSColor(calibratedWhite: 0.4, alpha: 0.4).cgColor
                    imageView.layer?.shadowColor = NSColor.black.cgColor
                    imageView.layer?.shadowOffset = NSSize(width: 0, height: 2)
                    imageView.layer?.shadowRadius = 4
                    imageView.layer?.shadowOpacity = 0.2
                }
                
                imageView.frame = NSRect(origin: .zero, size: imageSize)
                imageRowView.addArrangedSubview(imageView)
                
                // Extract title without number and marker
                let cleanTitle = title
                    .replacingOccurrences(of: "\(numberString). ", with: "")
                    .replacingOccurrences(of: " ◄", with: "")
                
                // Add title with dynamic sizing
                let titleLabel = NSTextField(labelWithString: cleanTitle)
                titleLabel.textColor = isActive ? theme.accentColor : NSColor.white
                titleLabel.font = NSFont.systemFont(ofSize: fontSize - 1, weight: isActive ? .semibold : .regular)
                titleLabel.backgroundColor = NSColor.clear
                titleLabel.cell?.wraps = false
                titleLabel.cell?.lineBreakMode = .byTruncatingTail
                titleLabel.sizeToFit()
                imageRowView.addArrangedSubview(titleLabel)
                
                imageStackView.addArrangedSubview(imageRowView)
                
                // Calculate actual title width for accurate sizing
                let titleFont = NSFont.systemFont(ofSize: fontSize - 1, weight: isActive ? .semibold : .regular)
                let titleSize = cleanTitle.boundingRect(
                    with: NSSize(width: CGFloat.greatestFiniteMagnitude, height: 30),
                    options: [.usesLineFragmentOrigin],
                    attributes: [.font: titleFont]
                ).size
                
                // Update total dimensions with actual content sizes
                let rowWidth = 35 + 12 + imageSize.width + 12 + titleSize.width
                totalWidth = max(totalWidth, rowWidth)
                totalHeight += imageSize.height + 12
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
        
        // Setup constraints for stack view to hug content
        stackView.topAnchor.constraint(equalTo: containerView.topAnchor, constant: padding).isActive = true
        stackView.leadingAnchor.constraint(equalTo: containerView.leadingAnchor, constant: padding).isActive = true
        stackView.trailingAnchor.constraint(equalTo: containerView.trailingAnchor, constant: -padding).isActive = true
        stackView.bottomAnchor.constraint(equalTo: containerView.bottomAnchor, constant: -padding).isActive = true
        
        // Set content hugging priority to prevent unnecessary expansion
        stackView.setHuggingPriority(.defaultHigh, for: .horizontal)
        stackView.setHuggingPriority(.defaultHigh, for: .vertical)
        
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
        
        // Create modern background for text-only popup
        let backgroundView = NSView(frame: NSRect(origin: .zero, size: windowSize))
        backgroundView.wantsLayer = true
        backgroundView.layer?.backgroundColor = NSColor(calibratedWhite: 0.06, alpha: 0.95).cgColor
        backgroundView.layer?.cornerRadius = 16
        backgroundView.layer?.borderWidth = 1.0
        backgroundView.layer?.borderColor = NSColor(calibratedWhite: 1.0, alpha: 0.12).cgColor
        
        // Enhanced shadow for depth
        backgroundView.layer?.shadowColor = NSColor.black.cgColor
        backgroundView.layer?.shadowOffset = NSSize(width: 0, height: 8)
        backgroundView.layer?.shadowRadius = 24
        backgroundView.layer?.shadowOpacity = 0.4
        
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
    
    /// Shows all available layouts in a grid with the current layout highlighted
    static func showAllLayoutsGrid(currentLayout: LayoutKind, position: FloatingPosition = .center, duration: TimeInterval = 1.5) {
        let layouts: [LayoutKind] = [.tall, .wide, .vertical_stack, .horizontal_stack, .fullscreen, .floating]
        let layoutNames = ["Tall", "Wide", "V.Stack", "H.Stack", "Full", "Float"]
        
        // Check if we have an active popup to reuse
        if let activePopup = activePopupWindow, activePopup.isVisible {
            // Reuse existing popup - update content and reset timer
            reuseActivePopupForLayoutGrid(window: activePopup, layouts: layouts, layoutNames: layoutNames, currentLayout: currentLayout, position: position, duration: duration)
        } else {
            // Create new popup
            let window = createLayoutGridWindow(layouts: layouts, layoutNames: layoutNames, currentLayout: currentLayout, position: position)
            activeWindows.append(window)
            activePopupWindow = window
            
            // Set window level before showing to avoid positioning issues
            window.level = NSWindow.Level(rawValue: Int(CGWindowLevelForKey(.floatingWindow)))
            window.makeKeyAndOrderFront(nil)
            
            // Schedule close timer
            schedulePopupClose(window: window, duration: duration)
        }
    }
    
    /// Reuses an active popup window for the layout grid display
    private static func reuseActivePopupForLayoutGrid(window: NSWindow, layouts: [LayoutKind], layoutNames: [String], currentLayout: LayoutKind, position: FloatingPosition, duration: TimeInterval) {
        // Cancel existing timer
        popupTimer?.invalidate()
        popupTimer = nil
        
        // Reset opacity to full
        window.alphaValue = 1.0
        
        // Update window content with new layout grid
        updatePopupContentForLayoutGrid(window: window, layouts: layouts, layoutNames: layoutNames, currentLayout: currentLayout, position: position)
        
        // Schedule new close timer
        schedulePopupClose(window: window, duration: duration)
    }
    
    /// Creates a window displaying all layouts in a grid format
    private static func createLayoutGridWindow(layouts: [LayoutKind], layoutNames: [String], currentLayout: LayoutKind, position: FloatingPosition) -> NSWindow {
        let itemWidth: CGFloat = 100
        let itemHeight: CGFloat = 80
        let spacing: CGFloat = 20
        let padding: CGFloat = 24
        let itemsPerRow = 3
        
        // Calculate grid dimensions
        let rows = Int(ceil(Double(layouts.count) / Double(itemsPerRow)))
        let cols = min(layouts.count, itemsPerRow)
        
        let contentWidth = CGFloat(cols) * itemWidth + CGFloat(cols - 1) * spacing
        let contentHeight = CGFloat(rows) * itemHeight + CGFloat(rows - 1) * spacing
        let windowSize = NSSize(width: contentWidth + padding * 2, height: contentHeight + padding * 2)
        
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
        
        // Create modern background
        let backgroundView = NSView(frame: NSRect(origin: .zero, size: windowSize))
        backgroundView.wantsLayer = true
        backgroundView.layer?.backgroundColor = NSColor(calibratedWhite: 0.06, alpha: 0.95).cgColor
        backgroundView.layer?.cornerRadius = 16
        backgroundView.layer?.borderWidth = 1.0
        backgroundView.layer?.borderColor = NSColor(calibratedWhite: 1.0, alpha: 0.12).cgColor
        
        // Enhanced shadow for depth
        backgroundView.layer?.shadowColor = NSColor.black.cgColor
        backgroundView.layer?.shadowOffset = NSSize(width: 0, height: 8)
        backgroundView.layer?.shadowRadius = 24
        backgroundView.layer?.shadowOpacity = 0.4
        
        // Create grid of layout items
        for (index, layout) in layouts.enumerated() {
            let row = index / itemsPerRow
            let col = index % itemsPerRow
            
            let x = padding + CGFloat(col) * (itemWidth + spacing)
            let y = padding + contentHeight - CGFloat(row + 1) * itemHeight - CGFloat(row) * spacing
            
            let itemView = createLayoutItemView(
                layout: layout,
                name: layoutNames[index],
                isActive: layout == currentLayout,
                frame: NSRect(x: x, y: y, width: itemWidth, height: itemHeight)
            )
            
            backgroundView.addSubview(itemView)
        }
        
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
    
    /// Updates existing popup content to show the layout grid
    private static func updatePopupContentForLayoutGrid(window: NSWindow, layouts: [LayoutKind], layoutNames: [String], currentLayout: LayoutKind, position: FloatingPosition) {
        let itemWidth: CGFloat = 100
        let itemHeight: CGFloat = 80
        let spacing: CGFloat = 20
        let padding: CGFloat = 24
        let itemsPerRow = 3
        
        // Calculate grid dimensions
        let rows = Int(ceil(Double(layouts.count) / Double(itemsPerRow)))
        let cols = min(layouts.count, itemsPerRow)
        
        let contentWidth = CGFloat(cols) * itemWidth + CGFloat(cols - 1) * spacing
        let contentHeight = CGFloat(rows) * itemHeight + CGFloat(rows - 1) * spacing
        let windowSize = NSSize(width: contentWidth + padding * 2, height: contentHeight + padding * 2)
        
        // Calculate new position
        let windowOrigin = calculateWindowOrigin(position: position, windowSize: windowSize)
        
        // Create modern background
        let backgroundView = NSView(frame: NSRect(origin: .zero, size: windowSize))
        backgroundView.wantsLayer = true
        backgroundView.layer?.backgroundColor = NSColor(calibratedWhite: 0.06, alpha: 0.95).cgColor
        backgroundView.layer?.cornerRadius = 16
        backgroundView.layer?.borderWidth = 1.0
        backgroundView.layer?.borderColor = NSColor(calibratedWhite: 1.0, alpha: 0.12).cgColor
        
        // Enhanced shadow for depth
        backgroundView.layer?.shadowColor = NSColor.black.cgColor
        backgroundView.layer?.shadowOffset = NSSize(width: 0, height: 8)
        backgroundView.layer?.shadowRadius = 24
        backgroundView.layer?.shadowOpacity = 0.4
        
        // Create grid of layout items
        for (index, layout) in layouts.enumerated() {
            let row = index / itemsPerRow
            let col = index % itemsPerRow
            
            let x = padding + CGFloat(col) * (itemWidth + spacing)
            let y = padding + contentHeight - CGFloat(row + 1) * itemHeight - CGFloat(row) * spacing
            
            let itemView = createLayoutItemView(
                layout: layout,
                name: layoutNames[index],
                isActive: layout == currentLayout,
                frame: NSRect(x: x, y: y, width: itemWidth, height: itemHeight)
            )
            
            backgroundView.addSubview(itemView)
        }
        
        // Update window content and frame smoothly
        window.contentView = backgroundView
        let newFrame = NSRect(origin: windowOrigin, size: windowSize)
        if !window.frame.equalTo(newFrame) {
            window.setFrame(newFrame, display: false, animate: false)
        }
    }
    
    /// Creates a single layout item view with icon and label
    private static func createLayoutItemView(layout: LayoutKind, name: String, isActive: Bool, frame: NSRect) -> NSView {
        let itemView = NSView(frame: frame)
        itemView.wantsLayer = true
        
        // Container styling
        let opacity: CGFloat = isActive ? 1.0 : 0.4
        let borderWidth: CGFloat = isActive ? 2.0 : 1.0
        let borderColor = isActive ? NSColor.white : NSColor(calibratedWhite: 0.6, alpha: 0.5)
        
        itemView.layer?.backgroundColor = NSColor(calibratedWhite: 0.12, alpha: opacity).cgColor
        itemView.layer?.cornerRadius = 8
        itemView.layer?.borderWidth = borderWidth
        itemView.layer?.borderColor = borderColor.cgColor
        itemView.alphaValue = opacity
        
        if isActive {
            // Add glow effect for active layout
            itemView.layer?.shadowColor = NSColor.white.cgColor
            itemView.layer?.shadowOffset = NSSize(width: 0, height: 0)
            itemView.layer?.shadowRadius = 6
            itemView.layer?.shadowOpacity = 0.3
        }
        
        // Create simple visual representation
        let iconView = createLayoutIcon(for: layout, isActive: isActive)
        iconView.frame = NSRect(x: 10, y: 30, width: frame.width - 20, height: frame.height - 50)
        itemView.addSubview(iconView)
        
        // Add layout name label
        let label = NSTextField(labelWithString: name)
        label.font = NSFont.systemFont(ofSize: 11, weight: isActive ? .semibold : .regular)
        label.textColor = isActive ? NSColor.white : NSColor(calibratedWhite: 0.8, alpha: 1.0)
        label.alignment = .center
        label.frame = NSRect(x: 5, y: 5, width: frame.width - 10, height: 20)
        itemView.addSubview(label)
        
        return itemView
    }
    
    /// Creates a simple visual icon for each layout type
    private static func createLayoutIcon(for layout: LayoutKind, isActive: Bool) -> NSView {
        let iconView = NSView()
        iconView.wantsLayer = true
        
        let color = isActive ? NSColor.white : NSColor(calibratedWhite: 0.7, alpha: 1.0)
        
        switch layout {
        case .tall:
            // Main pane on top, secondary below
            addRect(to: iconView, frame: NSRect(x: 0, y: 20, width: 60, height: 20), color: color)
            addRect(to: iconView, frame: NSRect(x: 0, y: 0, width: 60, height: 15), color: color)
            
        case .wide:
            // Main pane on left, secondary on right
            addRect(to: iconView, frame: NSRect(x: 0, y: 0, width: 30, height: 35), color: color)
            addRect(to: iconView, frame: NSRect(x: 35, y: 0, width: 25, height: 35), color: color)
            
        case .vertical_stack:
            // Equal height windows stacked vertically
            addRect(to: iconView, frame: NSRect(x: 0, y: 24, width: 60, height: 10), color: color)
            addRect(to: iconView, frame: NSRect(x: 0, y: 12, width: 60, height: 10), color: color)
            addRect(to: iconView, frame: NSRect(x: 0, y: 0, width: 60, height: 10), color: color)
            
        case .horizontal_stack:
            // Equal width windows side by side
            addRect(to: iconView, frame: NSRect(x: 0, y: 0, width: 18, height: 35), color: color)
            addRect(to: iconView, frame: NSRect(x: 21, y: 0, width: 18, height: 35), color: color)
            addRect(to: iconView, frame: NSRect(x: 42, y: 0, width: 18, height: 35), color: color)
            
        case .fullscreen:
            // Single full window
            addRect(to: iconView, frame: NSRect(x: 0, y: 0, width: 60, height: 35), color: color)
            
        case .floating:
            // Overlapping windows
            addRect(to: iconView, frame: NSRect(x: 0, y: 15, width: 25, height: 20), color: color)
            addRect(to: iconView, frame: NSRect(x: 15, y: 8, width: 25, height: 20), color: color)
            addRect(to: iconView, frame: NSRect(x: 30, y: 0, width: 25, height: 20), color: color)
        }
        
        return iconView
    }
    
    /// Helper method to add a rectangle to an icon view
    private static func addRect(to parentView: NSView, frame: CGRect, color: NSColor) {
        let rectView = NSView(frame: frame)
        rectView.wantsLayer = true
        rectView.layer?.backgroundColor = color.cgColor
        rectView.layer?.cornerRadius = 2
        parentView.addSubview(rectView)
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