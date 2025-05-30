//
//  ShortcutRecorder.swift
//  snapdesk
//
//  Created by Pedro Knup on 20/04/2025.
//

import SwiftUI
import AppKit
import HotKey
import Foundation

struct ShortcutRecorder: View {
    @Binding var shortcut: ShortcutConfig?
    @State private var isRecording = false
    @State private var currentModifiers: NSEvent.ModifierFlags = []
    @State private var currentKey: String?
    
    var body: some View {
        HStack {
            if isRecording {
                // Show the current pressed keys while recording
                Text(formatCurrentKeys())
                    .foregroundColor(.blue)
                    .font(.system(.body, design: .monospaced))
            } else if let shortcut = shortcut, !isClearedShortcut(shortcut) {
                Text(formatShortcut(shortcut))
                    .foregroundColor(.gray)
            } else {
                Text("No shortcut")
                    .foregroundColor(.gray)
            }
            
            HStack(spacing: 8) {
                if isRecording {
                    Button(action: {
                        // Instead of setting to nil, create a new ShortcutConfig with empty values
                        shortcut = ShortcutConfig(key: "", modifiers: [])
                        stopRecording()
                    }) {
                        Text("Clear")
                    }
                    .buttonStyle(.borderless)
                    .foregroundColor(.red)
                }
                
                Button(action: {
                    if isRecording {
                        stopRecording()
                    } else {
                        startRecording()
                    }
                }) {
                    Text(isRecording ? "Cancel" : "Configure")
                }
                .buttonStyle(.borderless)
            }
        }
        .onAppear {
            NSEvent.addLocalMonitorForEvents(matching: .flagsChanged) { event in
                if isRecording {
                    handleModifierChange(event)
                    return nil
                }
                return event
            }
            
            NSEvent.addLocalMonitorForEvents(matching: .keyDown) { event in
                if isRecording {
                    handleKeyDown(event)
                    return nil
                }
                return event
            }
            
            NSEvent.addLocalMonitorForEvents(matching: .keyUp) { event in
                if isRecording {
                    handleKeyUp(event)
                    return nil
                }
                return event
            }
        }
    }
    
    private func startRecording() {
        isRecording = true
        currentModifiers = []
        currentKey = nil
        
        // Pause all hotkeys while recording
        HotkeyManager.pauseAllHotkeys()
    }
    
    private func stopRecording() {
        isRecording = false
        currentModifiers = []
        currentKey = nil
        
        // Resume all hotkeys after recording
        HotkeyManager.resumeAllHotkeys()
    }
    
    private func handleModifierChange(_ event: NSEvent) {
        let modifiers = event.modifierFlags.intersection(.deviceIndependentFlagsMask)
        currentModifiers = modifiers
        
        // If all modifiers are released, also clear the current key
        if modifiers.isEmpty {
            currentKey = nil
        }
    }
    
    private func handleKeyDown(_ event: NSEvent) {
        let modifiers = event.modifierFlags.intersection(.deviceIndependentFlagsMask)
        currentModifiers = modifiers
        
        if let key = event.charactersIgnoringModifiers?.lowercased(), !key.isEmpty {
            currentKey = key
            
            // Convert modifiers to strings
            var modifierStrings: [String] = []
            if modifiers.contains(.command) {
                modifierStrings.append("command")
            }
            if modifiers.contains(.option) {
                modifierStrings.append("option")
            }
            if modifiers.contains(.shift) {
                modifierStrings.append("shift")
            }
            if modifiers.contains(.control) {
                modifierStrings.append("control")
            }
            
            // Create new shortcut
            let newShortcut = ShortcutConfig(key: key, modifiers: modifierStrings)
            shortcut = newShortcut
            stopRecording()
        }
    }
    
    private func handleKeyUp(_ event: NSEvent) {
        let modifiers = event.modifierFlags.intersection(.deviceIndependentFlagsMask)
        currentModifiers = modifiers
        
        // If all modifiers are released, also clear the current key
        if modifiers.isEmpty {
            currentKey = nil
        }
    }
    
    private func formatShortcut(_ shortcut: ShortcutConfig) -> String {
        if isClearedShortcut(shortcut) {
            return "No shortcut"
        }
        
        let modifiers = shortcut.modifiers.map { $0.capitalized }.joined(separator: " + ")
        return "\(modifiers) + \(shortcut.key.uppercased())"
    }
    
    private func formatCurrentKeys() -> String {
        var result = ""
        
        // Add modifiers
        if currentModifiers.contains(.command) {
            result += "⌘ "
        }
        if currentModifiers.contains(.option) {
            result += "⌥ "
        }
        if currentModifiers.contains(.shift) {
            result += "⇧ "
        }
        if currentModifiers.contains(.control) {
            result += "⌃ "
        }
        
        // Add separator if we have modifiers and a key
        if !result.isEmpty && currentKey != nil {
            result += " + "
        }
        
        // Add the current key
        if let key = currentKey {
            result += key.uppercased()
        } else if !result.isEmpty {
            result += "..."
        } else {
            result = "Press keys..."
        }
        
        return result
    }
    
    private func isClearedShortcut(_ shortcut: ShortcutConfig) -> Bool {
        return shortcut.key.isEmpty && shortcut.modifiers.isEmpty
    }
}
