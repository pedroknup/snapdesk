//
//  DebugLogViewer.swift
//  snapdesk
//
//  Created by Claude on 27/08/2025.
//

import Cocoa
import Foundation

class DebugLogViewer {
    private static var sharedInstance: DebugLogViewer?
    private var logWindow: NSWindow?
    private var textView: NSTextView?
    private var scrollView: NSScrollView?
    
    // Store recent log entries
    private var logEntries: [String] = []
    private let maxLogEntries = 50
    
    static var shared: DebugLogViewer {
        if sharedInstance == nil {
            sharedInstance = DebugLogViewer()
        }
        return sharedInstance!
    }
    
    private init() {
        print("🔧 DebugLogViewer initializing...")
        setupLogViewer()
        updateVisibility()
        print("🔧 DebugLogViewer setup complete")
        
        // Listen for settings changes
        NotificationCenter.default.addObserver(
            self,
            selector: #selector(settingsChanged),
            name: UserDefaults.didChangeNotification,
            object: nil
        )
    }
    
    private func setupLogViewer() {
        guard let firstScreen = NSScreen.screens.first else { 
            print("🔧 DebugLogViewer: No screens found!")
            return 
        }
        print("🔧 DebugLogViewer: Setting up on screen: \(firstScreen.frame)")
        
        // Calculate position (bottom right corner with some padding)
        let windowWidth: CGFloat = 400
        let windowHeight: CGFloat = 250
        let padding: CGFloat = 20
        
        let screenFrame = firstScreen.visibleFrame
        let windowOrigin = NSPoint(
            x: screenFrame.maxX - windowWidth - padding,
            y: screenFrame.minY + padding
        )
        
        let windowRect = NSRect(
            origin: windowOrigin,
            size: NSSize(width: windowWidth, height: windowHeight)
        )
        
        // Create window
        logWindow = NSWindow(
            contentRect: windowRect,
            styleMask: [.titled, .closable, .miniaturizable, .resizable],
            backing: .buffered,
            defer: false
        )
        
        guard let window = logWindow else { return }
        
        // Configure window
        window.title = "Snapdesk Debug Logs"
        window.level = NSWindow.Level.floating
        window.collectionBehavior = [.canJoinAllSpaces, .stationary]
        window.isReleasedWhenClosed = false
        
        // Create scroll view
        scrollView = NSScrollView(frame: window.contentView!.bounds)
        scrollView!.hasVerticalScroller = true
        scrollView!.hasHorizontalScroller = false
        scrollView!.autohidesScrollers = false
        scrollView!.autoresizingMask = [.width, .height]
        
        // Create text view
        textView = NSTextView(frame: scrollView!.contentView.bounds)
        textView!.isEditable = false
        textView!.isSelectable = true
        textView!.font = NSFont.monospacedSystemFont(ofSize: 11, weight: .regular)
        textView!.textColor = NSColor.labelColor
        textView!.backgroundColor = NSColor.textBackgroundColor
        textView!.autoresizingMask = [.width, .height]
        textView!.textContainer?.widthTracksTextView = true
        textView!.textContainer?.containerSize = NSSize(width: windowWidth - 20, height: .greatestFiniteMagnitude)
        
        // Set up text container
        textView!.textContainer?.lineFragmentPadding = 8
        textView!.textContainerInset = NSSize(width: 8, height: 8)
        
        // Add text view to scroll view
        scrollView!.documentView = textView
        
        // Add scroll view to window
        window.contentView?.addSubview(scrollView!)
        
        // Set initial content
        updateLogDisplay()
    }
    
    func addLogEntry(_ entry: String) {
        let timestamp = DateFormatter.logFormatter.string(from: Date())
        let formattedEntry = "[\(timestamp)] \(entry)"
        
        print("🔧 Formatted entry: \(formattedEntry)")
        
        DispatchQueue.main.async { [weak self] in
            guard let self = self else { 
                print("🔧 DebugLogViewer.addLogEntry: self is nil!")
                return 
            }
            
            // Add to log entries array
            self.logEntries.append(formattedEntry)
            
            // Keep only the most recent entries
            if self.logEntries.count > self.maxLogEntries {
                self.logEntries.removeFirst(self.logEntries.count - self.maxLogEntries)
            }
            
            // Update display if visible
            self.updateLogDisplay()
            self.scrollToBottom()
        }
    }
    
    private func updateLogDisplay() {
        guard let textView = textView else { 
            return 
        }
        
        let logText = logEntries.joined(separator: "\n")
        textView.string = logText
    }
    
    private func scrollToBottom() {
        guard let textView = textView else { return }
        
        DispatchQueue.main.async {
            let range = NSRange(location: textView.string.count, length: 0)
            textView.scrollRangeToVisible(range)
        }
    }
    
    private func updateVisibility() {
        let shouldShow = UserDefaults.standard.object(forKey: "showLogsView") as? Bool ?? false
        print("🔧 DebugLogViewer updateVisibility: shouldShow = \(shouldShow)")
        
        DispatchQueue.main.async { [weak self] in
            guard let window = self?.logWindow else { 
                print("🔧 DebugLogViewer: logWindow is nil!")
                return 
            }
            
            print("🔧 DebugLogViewer: window exists, applying visibility")
            if shouldShow {
                print("🔧 DebugLogViewer: Showing window")
                window.makeKeyAndOrderFront(nil)
            } else {
                print("🔧 DebugLogViewer: Hiding window")
                window.orderOut(nil)
            }
        }
    }
    
    @objc private func settingsChanged() {
        updateVisibility()
    }
    
    // Clear all logs
    func clearLogs() {
        DispatchQueue.main.async { [weak self] in
            self?.logEntries.removeAll()
            self?.updateLogDisplay()
        }
    }
    
    deinit {
        NotificationCenter.default.removeObserver(self)
    }
}

// MARK: - DateFormatter Extension
private extension DateFormatter {
    static let logFormatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.dateFormat = "HH:mm:ss"
        return formatter
    }()
}
