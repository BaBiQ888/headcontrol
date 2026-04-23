import AppKit
import ApplicationServices
import CoreGraphics

/// One discrete output action that a head gesture can map to.
enum KeyAction: String, CaseIterable, Identifiable, Sendable {
    case none

    case arrowLeft, arrowRight, arrowUp, arrowDown
    case pageUp, pageDown
    case spaceLeft, spaceRight     // Ctrl + ← / →  (switch macOS Space)
    case browserBack, browserForward  // Cmd + ← / →
    case scrollUp, scrollDown, scrollLeft, scrollRight

    var id: String { rawValue }

    var label: String {
        switch self {
        case .none:           "—"
        case .arrowLeft:      "← Arrow"
        case .arrowRight:     "→ Arrow"
        case .arrowUp:        "↑ Arrow"
        case .arrowDown:      "↓ Arrow"
        case .pageUp:         "Page Up"
        case .pageDown:       "Page Down"
        case .spaceLeft:      "Switch Space ←"
        case .spaceRight:     "Switch Space →"
        case .browserBack:    "Browser Back"
        case .browserForward: "Browser Forward"
        case .scrollUp:       "Scroll Up"
        case .scrollDown:     "Scroll Down"
        case .scrollLeft:     "Scroll Left"
        case .scrollRight:    "Scroll Right"
        }
    }
}

/// Preset bundles for all four gestures at once.
enum BindingPreset: String, CaseIterable, Identifiable {
    case spaces, reading, browser, scroll, custom

    var id: String { rawValue }

    var label: String {
        switch self {
        case .spaces:  "Spaces (default)"
        case .reading: "Reading (Arrows)"
        case .browser: "Browser (Back/Fwd)"
        case .scroll:  "Scroll Wheel"
        case .custom:  "Custom"
        }
    }

    /// Returns nil for `.custom`, which means "leave bindings as-is".
    var mappings: [HeadGesture: KeyAction]? {
        switch self {
        case .spaces:  [.left: .spaceLeft,  .right: .spaceRight, .up: .pageUp,    .down: .pageDown]
        case .reading: [.left: .arrowLeft,  .right: .arrowRight, .up: .arrowUp,   .down: .arrowDown]
        case .browser: [.left: .browserBack,.right: .browserForward, .up: .pageUp, .down: .pageDown]
        case .scroll:  [.left: .scrollLeft, .right: .scrollRight, .up: .scrollUp, .down: .scrollDown]
        case .custom:  nil
        }
    }
}

struct KeyInjector {
    static func isAccessibilityTrusted() -> Bool { AXIsProcessTrusted() }

    static func openAccessibilitySettings() {
        let url = URL(string: "x-apple.systempreferences:com.apple.preference.security?Privacy_Accessibility")
        if let url { NSWorkspace.shared.open(url) }
    }

    func inject(_ action: KeyAction) {
        let source = CGEventSource(stateID: .hidSystemState)
        switch action {
        case .none:
            return
        case .scrollUp:    postScroll(source: source, vertical:  6, horizontal:  0)
        case .scrollDown:  postScroll(source: source, vertical: -6, horizontal:  0)
        case .scrollLeft:  postScroll(source: source, vertical:  0, horizontal:  6)
        case .scrollRight: postScroll(source: source, vertical:  0, horizontal: -6)
        default:
            let (key, flags) = keycode(for: action)
            postKey(source: source, key: key, flags: flags)
        }
    }

    private func keycode(for action: KeyAction) -> (CGKeyCode, CGEventFlags) {
        switch action {
        case .arrowLeft:      (123, [])
        case .arrowRight:     (124, [])
        case .arrowDown:      (125, [])
        case .arrowUp:        (126, [])
        case .pageUp:         (116, [])
        case .pageDown:       (121, [])
        case .spaceLeft:      (123, .maskControl)
        case .spaceRight:     (124, .maskControl)
        case .browserBack:    (123, .maskCommand)
        case .browserForward: (124, .maskCommand)
        default:              (0, [])
        }
    }

    private func postKey(source: CGEventSource?, key: CGKeyCode, flags: CGEventFlags) {
        guard let down = CGEvent(keyboardEventSource: source, virtualKey: key, keyDown: true),
              let up   = CGEvent(keyboardEventSource: source, virtualKey: key, keyDown: false) else { return }
        down.flags = flags
        up.flags   = flags
        down.post(tap: .cghidEventTap)
        up.post(tap: .cghidEventTap)
    }

    private func postScroll(source: CGEventSource?, vertical: Int32, horizontal: Int32) {
        guard let event = CGEvent(scrollWheelEvent2Source: source,
                                  units: .line,
                                  wheelCount: 2,
                                  wheel1: vertical,
                                  wheel2: horizontal,
                                  wheel3: 0) else { return }
        event.post(tap: .cghidEventTap)
    }
}
