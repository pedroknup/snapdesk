//
//  TerminalStyleWindowFactory.swift
//  snapdesk
//
//  Created by Pedro Knup on 22/11/2025.
//

import Cocoa

enum TerminalStyleWindowFactory {
    static func createWindow(attributedText: NSAttributedString, images: [(NSImage, String)] = [], position: FloatingPosition, fontSize: CGFloat = 16) -> NSWindow {
        if images.isEmpty {
            return createTextOnlyWindow(attributedText: attributedText, position: position, fontSize: fontSize)
        } else {
            return createWindowWithImages(attributedText: attributedText, images: images, position: position, fontSize: fontSize)
        }
    }

    private static func createTextOnlyWindow(attributedText: NSAttributedString, position: FloatingPosition, fontSize: CGFloat) -> NSWindow {
        let maxWidth = NSScreen.main?.visibleFrame.width ?? 1920 * 0.6
        let maxHeight = NSScreen.main?.visibleFrame.height ?? 1080 * 0.8
        let padding: CGFloat = 24

        let terminalText = NotificationContentRenderer.createTerminalTextContent(attributedText: attributedText, fontSize: fontSize, maxWidth: maxWidth)

        let textSize = terminalText.boundingRect(
            with: NSSize(width: maxWidth * 0.8, height: maxHeight * 0.8),
            options: [.usesLineFragmentOrigin, .usesFontLeading]
        ).size

        let windowSize = NSSize(
            width: min(textSize.width + padding * 2, maxWidth),
            height: min(textSize.height + padding * 2, maxHeight)
        )

        let windowOrigin = NotificationPositionCalculator.calculateWindowOrigin(position: position, windowSize: windowSize)
        let windowRect = NSRect(origin: windowOrigin, size: windowSize)

        let window = NSWindow(
            contentRect: windowRect,
            styleMask: .borderless,
            backing: .buffered,
            defer: false
        )

        window.backgroundColor = NSColor.clear
        window.isOpaque = false
        window.hasShadow = true
        window.ignoresMouseEvents = true
        window.collectionBehavior = [.canJoinAllSpaces, .stationary]

        let backgroundView = createBackgroundView(size: windowSize)

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

        animateFadeIn(window: window)

        return window
    }

    private static func createWindowWithImages(attributedText: NSAttributedString, images: [(NSImage, String)], position: FloatingPosition, fontSize: CGFloat) -> NSWindow {
        let maxWidth = NSScreen.main?.visibleFrame.width ?? 1920 * 0.6
        let maxHeight = NSScreen.main?.visibleFrame.height ?? 1080 * 0.8
        let padding: CGFloat = 24

        let containerView = createBackgroundView(size: .zero)

        let stackView = NSStackView()
        stackView.orientation = .vertical
        stackView.alignment = .leading
        stackView.spacing = 10
        stackView.translatesAutoresizingMaskIntoConstraints = false

        let textView = createHeaderTextView(attributedText: attributedText, fontSize: fontSize, maxWidth: maxWidth, maxHeight: maxHeight)
        stackView.addArrangedSubview(textView)

        var totalWidth = textView.frame.width
        var totalHeight = textView.frame.height

        if !images.isEmpty {
            let (imageStackView, imageWidth, imageHeight) = createImageStack(images: images, fontSize: fontSize)
            stackView.addArrangedSubview(imageStackView)
            totalWidth = max(totalWidth, imageWidth)
            totalHeight += imageHeight
        }

        let windowSize = NSSize(
            width: min(totalWidth + padding * 2, maxWidth),
            height: min(totalHeight + padding * 2, maxHeight)
        )

        let windowOrigin = NotificationPositionCalculator.calculateWindowOrigin(position: position, windowSize: windowSize)
        let windowRect = NSRect(origin: windowOrigin, size: windowSize)

        let window = NSWindow(
            contentRect: windowRect,
            styleMask: .borderless,
            backing: .buffered,
            defer: false
        )

        window.backgroundColor = NSColor.clear
        window.isOpaque = false
        window.hasShadow = true
        window.ignoresMouseEvents = true
        window.collectionBehavior = [.canJoinAllSpaces, .stationary]

        containerView.frame = NSRect(origin: .zero, size: windowSize)
        containerView.addSubview(stackView)

        stackView.topAnchor.constraint(equalTo: containerView.topAnchor, constant: padding).isActive = true
        stackView.leadingAnchor.constraint(equalTo: containerView.leadingAnchor, constant: padding).isActive = true
        stackView.trailingAnchor.constraint(equalTo: containerView.trailingAnchor, constant: -padding).isActive = true
        stackView.bottomAnchor.constraint(equalTo: containerView.bottomAnchor, constant: -padding).isActive = true

        stackView.setHuggingPriority(.defaultHigh, for: .horizontal)
        stackView.setHuggingPriority(.defaultHigh, for: .vertical)

        window.contentView = containerView

        animateFadeIn(window: window)

        return window
    }

    static func updateWindowContent(window: NSWindow, attributedText: NSAttributedString, images: [(NSImage, String)], position: FloatingPosition, fontSize: CGFloat) {
        let maxWidth = NSScreen.main?.visibleFrame.width ?? 1920 * 0.6
        let maxHeight = NSScreen.main?.visibleFrame.height ?? 1080 * 0.8
        let padding: CGFloat = 24

        var totalWidth: CGFloat = 0
        var totalHeight: CGFloat = 0

        if images.isEmpty {
            let terminalText = NotificationContentRenderer.createTerminalTextContent(attributedText: attributedText, fontSize: fontSize, maxWidth: maxWidth)
            let textSize = terminalText.boundingRect(
                with: NSSize(width: maxWidth * 0.8, height: maxHeight * 0.8),
                options: [.usesLineFragmentOrigin, .usesFontLeading]
            ).size
            totalWidth = textSize.width
            totalHeight = textSize.height

            updateToTextOnlyLayout(window: window, attributedText: attributedText, fontSize: fontSize, padding: padding, windowSize: NSSize(width: totalWidth + padding * 2, height: totalHeight + padding * 2), position: position)
        } else {
            let textSize = attributedText.boundingRect(
                with: NSSize(width: maxWidth * 0.8, height: maxHeight * 0.8),
                options: [.usesLineFragmentOrigin, .usesFontLeading]
            ).size

            let (_, imageWidth, imageHeight) = calculateImageStackDimensions(images: images, fontSize: fontSize)

            totalWidth = max(textSize.width, imageWidth)
            totalHeight = textSize.height + imageHeight

            updateToImageLayout(window: window, attributedText: attributedText, images: images, fontSize: fontSize, padding: padding, windowSize: NSSize(width: totalWidth + padding * 2, height: totalHeight + padding * 2), position: position)
        }
    }

    private static func updateToTextOnlyLayout(window: NSWindow, attributedText: NSAttributedString, fontSize: CGFloat, padding: CGFloat, windowSize: NSSize, position: FloatingPosition) {
        let windowOrigin = NotificationPositionCalculator.calculateWindowOrigin(position: position, windowSize: windowSize)

        let backgroundView = createBackgroundView(size: windowSize)

        let maxWidth = NSScreen.main?.visibleFrame.width ?? 1920 * 0.6
        let terminalText = NotificationContentRenderer.createTerminalTextContent(attributedText: attributedText, fontSize: fontSize, maxWidth: maxWidth)

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
        let newFrame = NSRect(origin: windowOrigin, size: windowSize)
        if !window.frame.equalTo(newFrame) {
            window.setFrame(newFrame, display: false, animate: false)
        }
    }

    private static func updateToImageLayout(window: NSWindow, attributedText: NSAttributedString, images: [(NSImage, String)], fontSize: CGFloat, padding: CGFloat, windowSize: NSSize, position: FloatingPosition) {
        let windowOrigin = NotificationPositionCalculator.calculateWindowOrigin(position: position, windowSize: windowSize)

        let containerView = createBackgroundView(size: windowSize)

        let stackView = NSStackView()
        stackView.orientation = .vertical
        stackView.alignment = .leading
        stackView.spacing = 10
        stackView.translatesAutoresizingMaskIntoConstraints = false

        let maxWidth = NSScreen.main?.visibleFrame.width ?? 1920 * 0.6
        let maxHeight = NSScreen.main?.visibleFrame.height ?? 1080 * 0.8

        let textView = createHeaderTextView(attributedText: attributedText, fontSize: fontSize, maxWidth: maxWidth, maxHeight: maxHeight)
        stackView.addArrangedSubview(textView)

        if !images.isEmpty {
            let (imageStackView, _, _) = createImageStack(images: images, fontSize: fontSize)
            stackView.addArrangedSubview(imageStackView)
        }

        containerView.frame = NSRect(origin: .zero, size: windowSize)
        containerView.addSubview(stackView)

        stackView.topAnchor.constraint(equalTo: containerView.topAnchor, constant: padding).isActive = true
        stackView.leadingAnchor.constraint(equalTo: containerView.leadingAnchor, constant: padding).isActive = true
        stackView.trailingAnchor.constraint(equalTo: containerView.trailingAnchor, constant: -padding).isActive = true
        stackView.bottomAnchor.constraint(equalTo: containerView.bottomAnchor, constant: -padding).isActive = true

        stackView.setHuggingPriority(.defaultHigh, for: .horizontal)
        stackView.setHuggingPriority(.defaultHigh, for: .vertical)

        window.contentView = containerView
        let newFrame = NSRect(origin: windowOrigin, size: windowSize)
        if !window.frame.equalTo(newFrame) {
            window.setFrame(newFrame, display: false, animate: false)
        }
    }

    private static func createBackgroundView(size: NSSize) -> NSView {
        let backgroundView = NSView(frame: NSRect(origin: .zero, size: size))
        backgroundView.wantsLayer = true
        backgroundView.layer?.backgroundColor = NSColor(calibratedWhite: 0.06, alpha: 0.95).cgColor
        backgroundView.layer?.cornerRadius = 16
        backgroundView.layer?.borderWidth = 1.0
        backgroundView.layer?.borderColor = NSColor(calibratedWhite: 1.0, alpha: 0.12).cgColor

        backgroundView.layer?.shadowColor = NSColor.black.cgColor
        backgroundView.layer?.shadowOffset = NSSize(width: 0, height: 8)
        backgroundView.layer?.shadowRadius = 24
        backgroundView.layer?.shadowOpacity = 0.4

        return backgroundView
    }

    private static func createHeaderTextView(attributedText: NSAttributedString, fontSize: CGFloat, maxWidth: CGFloat, maxHeight: CGFloat) -> NSTextView {
        let textView = NSTextView()

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

        return textView
    }

    private static func createImageStack(images: [(NSImage, String)], fontSize: CGFloat) -> (NSStackView, CGFloat, CGFloat) {
        let imageStackView = NSStackView()
        imageStackView.orientation = .vertical
        imageStackView.alignment = .leading
        imageStackView.spacing = 10

        let config = ConfigurationManager.shared.loadConfig()
        let theme = config?.theme ?? ThemeConfig()
        let windowPreviewConfig = config?.windowPreview ?? WindowPreviewConfig()

        var maxRowWidth: CGFloat = 0
        var totalImageHeight: CGFloat = 0

        for (image, title) in images {
            let isActive = title.contains(" ◄")
            let numberString = title.components(separatedBy: ".").first?.trimmingCharacters(in: .whitespaces) ?? ""

            let imageRowView = NSStackView()
            imageRowView.orientation = .horizontal
            imageRowView.alignment = .centerY
            imageRowView.spacing = 12

            let numberLabel = NSTextField(labelWithString: numberString)
            numberLabel.textColor = isActive ? theme.accentColor : NSColor(calibratedWhite: 0.85, alpha: 1.0)
            numberLabel.font = NSFont.systemFont(ofSize: fontSize + 2, weight: isActive ? .bold : .regular)
            numberLabel.backgroundColor = NSColor.clear
            numberLabel.isBordered = false
            numberLabel.alignment = .center
            numberLabel.frame = NSRect(origin: .zero, size: NSSize(width: 35, height: 35))

            imageRowView.addArrangedSubview(numberLabel)

            let imageView = NSImageView()
            imageView.image = image
            imageView.imageScaling = .scaleProportionallyUpOrDown
            imageView.wantsLayer = true
            imageView.layer?.cornerRadius = 8
            imageView.layer?.masksToBounds = false

            let originalSize = image.size
            let maxSize = NSSize(width: windowPreviewConfig.maxWidth, height: windowPreviewConfig.maxHeight)

            let aspectRatio = originalSize.width / originalSize.height
            var imageSize = maxSize

            if aspectRatio > (maxSize.width / maxSize.height) {
                imageSize.height = maxSize.width / aspectRatio
            } else {
                imageSize.width = maxSize.height * aspectRatio
            }

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

            let cleanTitle = title
                .replacingOccurrences(of: "\(numberString). ", with: "")
                .replacingOccurrences(of: " ◄", with: "")

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

            let titleFont = NSFont.systemFont(ofSize: fontSize - 1, weight: isActive ? .semibold : .regular)
            let titleSize = cleanTitle.boundingRect(
                with: NSSize(width: CGFloat.greatestFiniteMagnitude, height: 30),
                options: [.usesLineFragmentOrigin],
                attributes: [.font: titleFont]
            ).size

            let rowWidth = 35 + 12 + imageSize.width + 12 + titleSize.width
            maxRowWidth = max(maxRowWidth, rowWidth)
            totalImageHeight += imageSize.height + 12
        }

        return (imageStackView, maxRowWidth, totalImageHeight)
    }

    private static func calculateImageStackDimensions(images: [(NSImage, String)], fontSize: CGFloat) -> (CGFloat, CGFloat, CGFloat) {
        let config = ConfigurationManager.shared.loadConfig()?.windowPreview ?? WindowPreviewConfig()

        var maxRowWidth: CGFloat = 0
        var totalImageHeight: CGFloat = 0

        for (image, title) in images {
            let isActive = title.contains(" ◄")
            let numberString = title.components(separatedBy: ".").first?.trimmingCharacters(in: .whitespaces) ?? ""

            let originalSize = image.size
            let maxSize = NSSize(width: config.maxWidth, height: config.maxHeight)
            let aspectRatio = originalSize.width / originalSize.height
            var imageSize = maxSize

            if aspectRatio > (maxSize.width / maxSize.height) {
                imageSize.height = maxSize.width / aspectRatio
            } else {
                imageSize.width = maxSize.height * aspectRatio
            }

            let cleanTitle = title
                .replacingOccurrences(of: "\(numberString). ", with: "")
                .replacingOccurrences(of: " ◄", with: "")

            let titleFont = NSFont.systemFont(ofSize: fontSize - 1, weight: isActive ? .semibold : .regular)
            let titleSize = cleanTitle.boundingRect(
                with: NSSize(width: CGFloat.greatestFiniteMagnitude, height: 30),
                options: [.usesLineFragmentOrigin],
                attributes: [.font: titleFont]
            ).size

            let rowWidth = 35 + 12 + imageSize.width + 12 + titleSize.width
            maxRowWidth = max(maxRowWidth, rowWidth)
            totalImageHeight += imageSize.height + 12
        }

        return (maxRowWidth, maxRowWidth, totalImageHeight)
    }

    private static func animateFadeIn(window: NSWindow) {
        window.alphaValue = 0.0
        NSAnimationContext.runAnimationGroup { context in
            context.duration = 0.2
            context.timingFunction = CAMediaTimingFunction(name: .easeInEaseOut)
            window.animator().alphaValue = 1.0
        }
    }
}
