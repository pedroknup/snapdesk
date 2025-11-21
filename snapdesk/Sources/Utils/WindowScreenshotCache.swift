//
//  WindowScreenshotCache.swift
//  snapdesk
//
//  Created by Pedro Knup on 22/11/2025.
//

import Cocoa

class WindowScreenshotCapture {
    private static var cache: [CGWindowID: (image: NSImage, timestamp: TimeInterval)] = [:]

    static func captureWindow(windowID: CGWindowID, maxSize: NSSize = NSSize(width: 200, height: 150)) -> NSImage? {
        let config = ConfigurationManager.shared.loadConfig()?.windowPreview ?? WindowPreviewConfig()

        if let cached = cache[windowID],
           Date().timeIntervalSince1970 - cached.timestamp < config.cacheTimeoutSeconds {
            return cached.image
        }

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

        cache[windowID] = (image: scaledImage, timestamp: Date().timeIntervalSince1970)

        cleanupCache(maxAge: config.cacheTimeoutSeconds)

        return scaledImage
    }

    private static func scaleImage(_ image: NSImage, to maxSize: NSSize) -> NSImage {
        let originalSize = image.size
        let aspectRatio = originalSize.width / originalSize.height

        var newSize = maxSize

        if aspectRatio > (maxSize.width / maxSize.height) {
            newSize.height = maxSize.width / aspectRatio
        } else {
            newSize.width = maxSize.height * aspectRatio
        }

        let scaledImage = NSImage(size: newSize)
        scaledImage.lockFocus()
        image.draw(in: NSRect(origin: .zero, size: newSize))
        scaledImage.unlockFocus()

        return scaledImage
    }

    private static func cleanupCache(maxAge: TimeInterval) {
        let currentTime = Date().timeIntervalSince1970
        cache = cache.filter { currentTime - $0.value.timestamp < maxAge }
    }

    static func clearCache() {
        cache.removeAll()
    }
}
