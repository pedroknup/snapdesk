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
