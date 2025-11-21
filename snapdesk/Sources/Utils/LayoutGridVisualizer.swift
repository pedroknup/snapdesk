//
//  LayoutGridVisualizer.swift
//  snapdesk
//
//  Created by Pedro Knup on 22/11/2025.
//

import Cocoa

enum LayoutGridVisualizer {
    static func createLayoutGridWindow(layouts: [LayoutKind], layoutNames: [String], currentLayout: LayoutKind, position: FloatingPosition) -> NSWindow {
        let itemWidth: CGFloat = 100
        let itemHeight: CGFloat = 80
        let spacing: CGFloat = 20
        let padding: CGFloat = 24
        let itemsPerRow = 3

        let rows = Int(ceil(Double(layouts.count) / Double(itemsPerRow)))
        let cols = min(layouts.count, itemsPerRow)

        let contentWidth = CGFloat(cols) * itemWidth + CGFloat(cols - 1) * spacing
        let contentHeight = CGFloat(rows) * itemHeight + CGFloat(rows - 1) * spacing
        let windowSize = NSSize(width: contentWidth + padding * 2, height: contentHeight + padding * 2)

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

        animateFadeIn(window: window)

        return window
    }

    static func updateLayoutGridContent(window: NSWindow, layouts: [LayoutKind], layoutNames: [String], currentLayout: LayoutKind, position: FloatingPosition) {
        let itemWidth: CGFloat = 100
        let itemHeight: CGFloat = 80
        let spacing: CGFloat = 20
        let padding: CGFloat = 24
        let itemsPerRow = 3

        let rows = Int(ceil(Double(layouts.count) / Double(itemsPerRow)))
        let cols = min(layouts.count, itemsPerRow)

        let contentWidth = CGFloat(cols) * itemWidth + CGFloat(cols - 1) * spacing
        let contentHeight = CGFloat(rows) * itemHeight + CGFloat(rows - 1) * spacing
        let windowSize = NSSize(width: contentWidth + padding * 2, height: contentHeight + padding * 2)

        let windowOrigin = NotificationPositionCalculator.calculateWindowOrigin(position: position, windowSize: windowSize)

        let backgroundView = createBackgroundView(size: windowSize)

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

    private static func createLayoutItemView(layout: LayoutKind, name: String, isActive: Bool, frame: NSRect) -> NSView {
        let itemView = NSView(frame: frame)
        itemView.wantsLayer = true

        let opacity: CGFloat = isActive ? 1.0 : 0.4
        let borderWidth: CGFloat = isActive ? 2.0 : 1.0
        let borderColor = isActive ? NSColor.white : NSColor(calibratedWhite: 0.6, alpha: 0.5)

        itemView.layer?.backgroundColor = NSColor(calibratedWhite: 0.12, alpha: opacity).cgColor
        itemView.layer?.cornerRadius = 8
        itemView.layer?.borderWidth = borderWidth
        itemView.layer?.borderColor = borderColor.cgColor
        itemView.alphaValue = opacity

        if isActive {
            itemView.layer?.shadowColor = NSColor.white.cgColor
            itemView.layer?.shadowOffset = NSSize(width: 0, height: 0)
            itemView.layer?.shadowRadius = 6
            itemView.layer?.shadowOpacity = 0.3
        }

        let iconView = createLayoutIcon(for: layout, isActive: isActive)
        iconView.frame = NSRect(x: 10, y: 30, width: frame.width - 20, height: frame.height - 50)
        itemView.addSubview(iconView)

        let label = NSTextField(labelWithString: name)
        label.font = NSFont.systemFont(ofSize: 11, weight: isActive ? .semibold : .regular)
        label.textColor = isActive ? NSColor.white : NSColor(calibratedWhite: 0.8, alpha: 1.0)
        label.alignment = .center
        label.frame = NSRect(x: 5, y: 5, width: frame.width - 10, height: 20)
        itemView.addSubview(label)

        return itemView
    }

    private static func createLayoutIcon(for layout: LayoutKind, isActive: Bool) -> NSView {
        let iconView = NSView()
        iconView.wantsLayer = true

        let color = isActive ? NSColor.white : NSColor(calibratedWhite: 0.7, alpha: 1.0)

        switch layout {
        case .tall:
            addRect(to: iconView, frame: NSRect(x: 0, y: 20, width: 60, height: 20), color: color)
            addRect(to: iconView, frame: NSRect(x: 0, y: 0, width: 60, height: 15), color: color)

        case .wide:
            addRect(to: iconView, frame: NSRect(x: 0, y: 0, width: 30, height: 35), color: color)
            addRect(to: iconView, frame: NSRect(x: 35, y: 0, width: 25, height: 35), color: color)

        case .vertical_stack:
            addRect(to: iconView, frame: NSRect(x: 0, y: 24, width: 60, height: 10), color: color)
            addRect(to: iconView, frame: NSRect(x: 0, y: 12, width: 60, height: 10), color: color)
            addRect(to: iconView, frame: NSRect(x: 0, y: 0, width: 60, height: 10), color: color)

        case .horizontal_stack:
            addRect(to: iconView, frame: NSRect(x: 0, y: 0, width: 18, height: 35), color: color)
            addRect(to: iconView, frame: NSRect(x: 21, y: 0, width: 18, height: 35), color: color)
            addRect(to: iconView, frame: NSRect(x: 42, y: 0, width: 18, height: 35), color: color)

        case .fullscreen:
            addRect(to: iconView, frame: NSRect(x: 0, y: 0, width: 60, height: 35), color: color)

        case .floating:
            addRect(to: iconView, frame: NSRect(x: 0, y: 15, width: 25, height: 20), color: color)
            addRect(to: iconView, frame: NSRect(x: 15, y: 8, width: 25, height: 20), color: color)
            addRect(to: iconView, frame: NSRect(x: 30, y: 0, width: 25, height: 20), color: color)
        }

        return iconView
    }

    private static func addRect(to parentView: NSView, frame: CGRect, color: NSColor) {
        let rectView = NSView(frame: frame)
        rectView.wantsLayer = true
        rectView.layer?.backgroundColor = color.cgColor
        rectView.layer?.cornerRadius = 2
        parentView.addSubview(rectView)
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
