import AppKit
import ApplicationServices

// MARK: - AX Utilities

private extension AXUIElement {
    static var systemWide: AXUIElement { AXUIElementCreateSystemWide() }

    func axCopyAttribute<T>(_ attr: CFString) -> T? {
        var ref: CFTypeRef?
        let err = AXUIElementCopyAttributeValue(self, attr, &ref)
        guard err == .success, let v = ref as? T else { return nil }
        return v
    }

    @discardableResult
    func axSetAttribute(_ attr: CFString, _ value: CFTypeRef) -> Bool {
        AXUIElementSetAttributeValue(self, attr, value) == .success
    }
}

// MARK: - AXValue helpers

private func makeAXValue<T>(_ type: AXValueType, _ value: inout T) -> AXValue {
    AXValueCreate(type, &value)!
}

private func cgPoint(from value: CFTypeRef?) -> CGPoint? {
    guard let v = value else { return nil }
    var p = CGPoint.zero
    return AXValueGetValue((v as! AXValue), .cgPoint, &p) ? p : nil
}

private func cgSize(from value: CFTypeRef?) -> CGSize? {
    guard let v = value else { return nil }
    var s = CGSize.zero
    return AXValueGetValue((v as! AXValue), .cgSize, &s) ? s : nil
}


// MARK: - Window shape accessors

func windowFrame(of window: AXUIElement) -> CGRect? {
    guard
        let posRef: CFTypeRef = window.axCopyAttribute(kAXPositionAttribute as CFString) as CFTypeRef?,
        let sizeRef: CFTypeRef = window.axCopyAttribute(kAXSizeAttribute as CFString) as CFTypeRef?,
        let pos = cgPoint(from: posRef),
        let size = cgSize(from: sizeRef)
    else { return nil }
    return CGRect(origin: pos, size: size)
}

@discardableResult
private func setWindowFrame(_ window: AXUIElement, _ frame: CGRect) -> Bool {
    var pos = frame.origin
    var size = frame.size
    let ok1 = window.axSetAttribute(kAXPositionAttribute as CFString, makeAXValue(.cgPoint, &pos))
    let ok2 = window.axSetAttribute(kAXSizeAttribute     as CFString, makeAXValue(.cgSize,  &size))
    return ok1 && ok2
}

private func isStandardWindow(_ window: AXUIElement) -> Bool {
    let role: String?    = window.axCopyAttribute(kAXRoleAttribute as CFString)
    let subrole: String? = window.axCopyAttribute(kAXSubroleAttribute as CFString)

    return role == (kAXWindowRole as String) &&
           subrole != (kAXSystemDialogSubrole as String) &&
           subrole != (kAXFloatingWindowSubrole as String) &&
           subrole != "AXSheet"   // sheet subrole
}


// MARK: - Public API

func frontmostWindow() -> AXUIElement? {
    // 1) Global focused window
    if let focused: AXUIElement = AXUIElement.systemWide.axCopyAttribute(kAXFocusedWindowAttribute as CFString),
       isStandardWindow(focused) {
        return focused
    }

    // 2) Frontmost app → its focused window (then first window)
    if let app = NSWorkspace.shared.frontmostApplication {
        let appElem = AXUIElementCreateApplication(app.processIdentifier)

        if let win: AXUIElement = appElem.axCopyAttribute(kAXFocusedWindowAttribute as CFString),
           isStandardWindow(win) {
            return win
        }

        if let windows: [AXUIElement] = appElem.axCopyAttribute(kAXWindowsAttribute as CFString) {
            return windows.first(where: isStandardWindow)
        }
    }
    return nil
}

@discardableResult
func move(window: AXUIElement, to targetFrame: CGRect) -> Bool {
    // Check if window position validation is needed to prevent unnecessary moves
    if shouldPreserveWindowPosition(window, targetFrame: targetFrame) {
        log("🔒 Preserving window position - target frame is similar to current frame")
        return true
    }

    // Missing constant in some SDKs
    let kAXFullscreenAttribute: CFString = "AXFullScreen" as CFString

    // If full screen, toggle off so size/position becomes writable
    if let isFullCF: CFBoolean = window.axCopyAttribute(kAXFullscreenAttribute as CFString),
       CFBooleanGetValue(isFullCF) {
        _ = window.axSetAttribute(kAXFullscreenAttribute as CFString, kCFBooleanFalse)
        usleep(20_000)
    }

    if setWindowFrame(window, targetFrame) { return true }

    // Fallback: size then position
    var size = targetFrame.size
    var pos  = targetFrame.origin
    let ok1 = window.axSetAttribute(kAXSizeAttribute     as CFString, makeAXValue(.cgSize,  &size))
    let ok2 = window.axSetAttribute(kAXPositionAttribute as CFString, makeAXValue(.cgPoint, &pos))
    return ok1 && ok2
}

/// Determines if a window should preserve its current position instead of being moved
/// Returns true if the window is already properly positioned and shouldn't be moved
private func shouldPreserveWindowPosition(_ window: AXUIElement, targetFrame: CGRect) -> Bool {
    // Check if position preservation is enabled (default: true)
    let preserveEnabled = UserDefaults.standard.object(forKey: "preventUnnecessaryWindowMoves") as? Bool ?? true
    if !preserveEnabled {
        return false
    }

    // Get current window frame
    guard let currentFrame = windowFrame(of: window) else {
        return false
    }

    // Define tolerance for position and size differences (in pixels)
    let positionTolerance: CGFloat = 5.0
    let sizeTolerance: CGFloat = 10.0

    // Check if positions are similar (within tolerance)
    let positionsSimilar = abs(currentFrame.origin.x - targetFrame.origin.x) <= positionTolerance &&
                          abs(currentFrame.origin.y - targetFrame.origin.y) <= positionTolerance

    // Check if sizes are similar (within tolerance)
    let sizesSimilar = abs(currentFrame.size.width - targetFrame.size.width) <= sizeTolerance &&
                      abs(currentFrame.size.height - targetFrame.size.height) <= sizeTolerance

    // Check if window is on the correct screen by ensuring target frame is reasonable
    let targetInBounds = targetFrame.width > 50 && targetFrame.height > 50 &&
                        targetFrame.origin.x > -1000 && targetFrame.origin.y > -1000

    // Preserve position if window is already properly positioned and target makes sense
    let shouldPreserve = positionsSimilar && sizesSimilar && targetInBounds

    if shouldPreserve {
        log("📍 Window already properly positioned: current=\(NSStringFromRect(currentFrame)) target=\(NSStringFromRect(targetFrame))")
    }

    return shouldPreserve
}
