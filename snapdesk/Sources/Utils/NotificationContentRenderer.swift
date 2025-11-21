//
//  NotificationContentRenderer.swift
//  snapdesk
//
//  Created by Pedro Knup on 22/11/2025.
//

import Cocoa

enum NotificationContentRenderer {
    static func createTerminalTextContent(attributedText: NSAttributedString, fontSize: CGFloat, maxWidth: CGFloat) -> NSAttributedString {
        let result = NSMutableAttributedString()
        let terminalFont = NSFont.monospacedSystemFont(ofSize: fontSize, weight: .medium)
        let textColor = NSColor.white

        let text = attributedText.string

        let lines = text.components(separatedBy: .newlines)
        for (index, line) in lines.enumerated() {
            let cleanLine = line.trimmingCharacters(in: .whitespaces)

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

    static func createTerminalContentWithImages(attributedText: NSAttributedString, images: [(NSImage, String)], fontSize: CGFloat, maxWidth: CGFloat) -> NSAttributedString {
        let result = NSMutableAttributedString()
        let terminalFont = NSFont.monospacedSystemFont(ofSize: fontSize, weight: .medium)
        let textColor = NSColor.white
        let secondaryColor = NSColor.systemGray

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

        if !images.isEmpty {
            result.append(NSAttributedString(string: "\n", attributes: [
                .font: terminalFont,
                .foregroundColor: textColor
            ]))

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

    static func truncateString(_ string: String, maxLength: Int) -> String {
        if string.count <= maxLength {
            return string
        } else {
            return String(string.prefix(maxLength - 3)) + "..."
        }
    }
}
