//
//  LogManager.swift
//  Amethyst
//
//  Created by Ian Ynda-Hummel on 5/19/16.
//  Copyright © 2016 Ian Ynda-Hummel. All rights reserved.
//

import SwiftyBeaver

// Custom destination for debug log viewer
class DebugLogViewerDestination: BaseDestination {
    private static var callCount = 0
    
    override func send(_ level: SwiftyBeaver.Level, msg: String, thread: String, file: String, function: String, line: Int, context: Any? = nil) -> String? {
        
        DebugLogViewerDestination.callCount += 1
        print("🔧 DebugLogViewerDestination.send called #\(DebugLogViewerDestination.callCount) with level: \(level), msg: \(msg)")
        
        // Create a simple formatted message
        let levelString: String
        switch level {
        case .verbose: levelString = "💬"
        case .debug: levelString = "🔍"
        case .info: levelString = "ℹ️"
        case .warning: levelString = "⚠️"
        case .error: levelString = "❌"
        case .critical:
            levelString = "❌"
        case .fault:
            levelString = "❌"
        }
        
        let simpleMessage = "\(levelString) \(msg)"
        
        print("🔧 Sending to debug viewer: \(simpleMessage)")
        // Send to debug log viewer directly
        DebugLogViewer.shared.addLogEntry(simpleMessage)
        
        // Also call super to maintain normal functionality
        return super.send(level, msg: msg, thread: thread, file: file, function: function, line: line, context: context)
    }
}

// Configure SwiftyBeaver with debug viewer integration
private func setupLogging() {
    print("🔧 Setting up SwiftyBeaver logging with debug viewer...")
    
    // Ensure DebugLogViewer is initialized early
    _ = DebugLogViewer.shared
    
    // Console destination (existing)
    let console = ConsoleDestination()
    console.format = "$DHH:mm:ss$d $L $M"
    SwiftyBeaver.addDestination(console)
    
    // Debug log viewer destination (new)
    let debugViewer = DebugLogViewerDestination()
    debugViewer.format = "$L $M"
    SwiftyBeaver.addDestination(debugViewer)
    
    print("🔧 SwiftyBeaver setup complete with debug viewer destination")
}

// Initialize logging on first access
private let setupLoggingOnce: Void = {
    setupLogging()
}()

let log: SwiftyBeaver.Type = {
    _ = setupLoggingOnce
    return SwiftyBeaver.self
}()
