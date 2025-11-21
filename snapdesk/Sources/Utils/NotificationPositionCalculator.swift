//
//  NotificationPositionCalculator.swift
//  snapdesk
//
//  Created by Pedro Knup on 21/11/2025.
//

import Cocoa

enum NotificationPositionCalculator {
    static func calculateWindowOrigin(position: FloatingPosition, windowSize: NSSize) -> NSPoint {
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
}
