import SwiftUI
import HotKey

struct ShortcutRecorderView: View {
    @Binding var shortcut: ShortcutConfig?
    @Environment(\.dismiss) private var dismiss
    @State private var isRecording = false
    @State private var currentKey: String = ""
    @State private var currentModifiers: Set<String> = []
    
    var body: some View {
        VStack(spacing: 20) {
            Text("Press the keys for your shortcut")
                .font(.headline)
            
            if isRecording {
                Text(formatCurrentShortcut())
                    .font(.title2)
                    .foregroundColor(.blue)
            } else if let shortcut = shortcut {
                Text(formatShortcut(shortcut))
                    .font(.title2)
            } else {
                Text("No shortcut set")
                    .font(.title2)
                    .foregroundColor(.gray)
            }
            
            HStack(spacing: 16) {
                Button("Cancel") {
                    dismiss()
                }
                .buttonStyle(.bordered)
                
                if shortcut != nil {
                    Button("Clear") {
                        shortcut = nil
                        dismiss()
                    }
                    .buttonStyle(.bordered)
                    .foregroundColor(.red)
                }
                
                Button(isRecording ? "Done" : "Record") {
                    if isRecording {
                        if !currentKey.isEmpty {
                            shortcut = ShortcutConfig(
                                key: currentKey,
                                modifiers: Array(currentModifiers)
                            )
                        }
                        isRecording = false
                    } else {
                        isRecording = true
                        currentKey = ""
                        currentModifiers = []
                    }
                }
                .buttonStyle(.borderedProminent)
                .disabled(isRecording && currentKey.isEmpty)
            }
        }
        .padding()
        .frame(width: 300)
        .onAppear {
            startRecording()
        }
    }
    
    private func startRecording() {
        isRecording = true
        currentKey = ""
        currentModifiers = []
    }
    
    private func formatCurrentShortcut() -> String {
        let modifiers = currentModifiers.map { $0.capitalized }.joined(separator: " + ")
        if currentKey.isEmpty {
            return modifiers.isEmpty ? "Press keys..." : modifiers
        }
        return "\(modifiers) + \(currentKey.uppercased())"
    }
    
    private func formatShortcut(_ shortcut: ShortcutConfig) -> String {
        let modifiers = shortcut.modifiers.map { $0.capitalized }.joined(separator: " + ")
        return "\(modifiers) + \(shortcut.key.uppercased())"
    }
}

#Preview {
    ShortcutRecorderView(shortcut: .constant(nil))
} 