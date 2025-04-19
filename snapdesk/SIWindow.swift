extension SIWindow {
    func isStandard() -> Bool {
          do {
              let ax = try axElement().takeUnretainedValue()
              log("element is \(ax)")
              var value: CFTypeRef?
              let result = AXUIElementCopyAttributeValue(ax, kAXSubroleAttribute as CFString, &value)
              if result == .success {
                  return true
              } else {
                  log("⚠️ AXUIElementCopyAttributeValue failed with code \(result)")
              }
          } catch {
              log("❌ Failed to unwrap axElement in isStandard(): \(error)")
          }
          return false
      }
    
    func isFocused() -> Bool {
           let myElement = axElement().takeUnretainedValue()
           let systemWideElement = AXUIElementCreateSystemWide()

           var focusedValue: CFTypeRef?
           let result = AXUIElementCopyAttributeValue(systemWideElement,
                                                      kAXFocusedWindowAttribute as CFString,
                                                      &focusedValue)

           guard result == .success else {
               return false
           }

           let focusedAX = focusedValue as! AXUIElement
           return CFEqual(myElement, focusedAX)
       }
}
