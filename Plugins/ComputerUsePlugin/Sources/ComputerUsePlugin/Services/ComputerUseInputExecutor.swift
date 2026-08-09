import ApplicationServices
import Carbon.HIToolbox
import CoreGraphics
import Foundation

enum ComputerUseInputExecutor {
    static func execute(_ action: ComputerUseAction, observation: ComputerUseObservation) async throws {
        switch action {
        case .screenshot:
            return
        case .click(let x, let y, let button, let count):
            let point = try screenPoint(x: x, y: y, observation: observation)
            try postClick(at: point, button: button, count: count)
        case .move(let x, let y):
            let point = try screenPoint(x: x, y: y, observation: observation)
            guard let event = CGEvent(
                mouseEventSource: eventSource(),
                mouseType: .mouseMoved,
                mouseCursorPosition: point,
                mouseButton: .left
            ) else { throw ComputerUseError.eventCreationFailed }
            event.post(tap: .cghidEventTap)
        case .drag(let path):
            try postDrag(path: path, observation: observation)
        case .scroll(let x, let y, let deltaX, let deltaY):
            let point = try screenPoint(x: x, y: y, observation: observation)
            try moveMouse(to: point)
            guard let event = CGEvent(
                scrollWheelEvent2Source: eventSource(),
                units: .pixel,
                wheelCount: 2,
                wheel1: Int32(clamping: Int(-deltaY.rounded())),
                wheel2: Int32(clamping: Int(-deltaX.rounded())),
                wheel3: 0
            ) else { throw ComputerUseError.eventCreationFailed }
            event.post(tap: .cghidEventTap)
        case .type(let text):
            try ensureFocusedElementIsNotSecure()
            try postUnicodeText(text)
        case .keypress(let keys):
            try postKeypress(keys)
        case .wait(let milliseconds):
            try await Task.sleep(for: .milliseconds(milliseconds))
        }
    }

    private static func eventSource() -> CGEventSource? {
        CGEventSource(stateID: .hidSystemState)
    }

    private static func screenPoint(
        x: Double,
        y: Double,
        observation: ComputerUseObservation
    ) throws -> CGPoint {
        guard x >= 0, y >= 0,
              x <= Double(observation.imageWidth),
              y <= Double(observation.imageHeight)
        else {
            throw ComputerUseError.invalidArguments(
                "coordinate (\(Int(x)), \(Int(y))) is outside \(observation.imageWidth)x\(observation.imageHeight)"
            )
        }
        return observation.screenPoint(imageX: x, imageY: y)
    }

    private static func moveMouse(to point: CGPoint) throws {
        guard let event = CGEvent(
            mouseEventSource: eventSource(),
            mouseType: .mouseMoved,
            mouseCursorPosition: point,
            mouseButton: .left
        ) else { throw ComputerUseError.eventCreationFailed }
        event.post(tap: .cghidEventTap)
    }

    private static func postClick(at point: CGPoint, button: ComputerMouseButton, count: Int) throws {
        let downType: CGEventType
        let upType: CGEventType
        let cgButton: CGMouseButton
        switch button {
        case .left:
            (downType, upType, cgButton) = (.leftMouseDown, .leftMouseUp, .left)
        case .right:
            (downType, upType, cgButton) = (.rightMouseDown, .rightMouseUp, .right)
        case .center:
            (downType, upType, cgButton) = (.otherMouseDown, .otherMouseUp, .center)
        }

        for clickIndex in 1...max(1, min(count, 2)) {
            guard let down = CGEvent(
                mouseEventSource: eventSource(),
                mouseType: downType,
                mouseCursorPosition: point,
                mouseButton: cgButton
            ), let up = CGEvent(
                mouseEventSource: eventSource(),
                mouseType: upType,
                mouseCursorPosition: point,
                mouseButton: cgButton
            ) else { throw ComputerUseError.eventCreationFailed }
            let state = Int64(count == 2 ? clickIndex : 1)
            down.setIntegerValueField(.mouseEventClickState, value: state)
            up.setIntegerValueField(.mouseEventClickState, value: state)
            down.post(tap: .cghidEventTap)
            up.post(tap: .cghidEventTap)
        }
    }

    private static func postDrag(path: [CGPoint], observation: ComputerUseObservation) throws {
        let screenPath = try path.map {
            try screenPoint(x: $0.x, y: $0.y, observation: observation)
        }
        guard let first = screenPath.first,
              let down = CGEvent(
                mouseEventSource: eventSource(),
                mouseType: .leftMouseDown,
                mouseCursorPosition: first,
                mouseButton: .left
              )
        else { throw ComputerUseError.eventCreationFailed }
        try moveMouse(to: first)
        down.post(tap: .cghidEventTap)
        for point in screenPath.dropFirst() {
            guard let event = CGEvent(
                mouseEventSource: eventSource(),
                mouseType: .leftMouseDragged,
                mouseCursorPosition: point,
                mouseButton: .left
            ) else { throw ComputerUseError.eventCreationFailed }
            event.post(tap: .cghidEventTap)
        }
        guard let last = screenPath.last,
              let up = CGEvent(
                mouseEventSource: eventSource(),
                mouseType: .leftMouseUp,
                mouseCursorPosition: last,
                mouseButton: .left
              )
        else { throw ComputerUseError.eventCreationFailed }
        up.post(tap: .cghidEventTap)
    }

    private static func ensureFocusedElementIsNotSecure() throws {
        let systemWide = AXUIElementCreateSystemWide()
        var focusedValue: CFTypeRef?
        guard AXUIElementCopyAttributeValue(
            systemWide,
            kAXFocusedUIElementAttribute as CFString,
            &focusedValue
        ) == .success,
        let focusedValue else { return }
        let focused = focusedValue as! AXUIElement
        var roleValue: CFTypeRef?
        guard AXUIElementCopyAttributeValue(
            focused,
            kAXSubroleAttribute as CFString,
            &roleValue
        ) == .success,
        let role = roleValue as? String else { return }
        if role == "AXSecureTextField" {
            throw ComputerUseError.secureInputBlocked
        }
    }

    private static func postUnicodeText(_ text: String) throws {
        let utf16 = Array(text.utf16)
        for start in stride(from: 0, to: utf16.count, by: 20) {
            let end = min(start + 20, utf16.count)
            let chunk = Array(utf16[start..<end])
            guard let down = CGEvent(keyboardEventSource: eventSource(), virtualKey: 0, keyDown: true),
                  let up = CGEvent(keyboardEventSource: eventSource(), virtualKey: 0, keyDown: false)
            else { throw ComputerUseError.eventCreationFailed }
            chunk.withUnsafeBufferPointer { buffer in
                guard let baseAddress = buffer.baseAddress else { return }
                down.keyboardSetUnicodeString(stringLength: buffer.count, unicodeString: baseAddress)
                up.keyboardSetUnicodeString(stringLength: buffer.count, unicodeString: baseAddress)
            }
            down.post(tap: .cghidEventTap)
            up.post(tap: .cghidEventTap)
        }
    }

    private static func postKeypress(_ rawKeys: [String]) throws {
        let keys = rawKeys.map { $0.uppercased().replacingOccurrences(of: " ", with: "") }
        var flags: CGEventFlags = []
        for key in keys {
            switch key {
            case "CMD", "COMMAND", "META": flags.insert(.maskCommand)
            case "SHIFT": flags.insert(.maskShift)
            case "CTRL", "CONTROL": flags.insert(.maskControl)
            case "OPTION", "ALT": flags.insert(.maskAlternate)
            case "FN": flags.insert(.maskSecondaryFn)
            default: break
            }
        }
        let nonModifiers = keys.filter { keyCode(for: $0) != nil }
        guard !nonModifiers.isEmpty else {
            throw ComputerUseError.invalidArguments("keypress must contain a non-modifier key")
        }
        for key in nonModifiers {
            guard let keyCode = keyCode(for: key),
                  let down = CGEvent(keyboardEventSource: eventSource(), virtualKey: keyCode, keyDown: true),
                  let up = CGEvent(keyboardEventSource: eventSource(), virtualKey: keyCode, keyDown: false)
            else { throw ComputerUseError.eventCreationFailed }
            down.flags = flags
            up.flags = flags
            down.post(tap: .cghidEventTap)
            up.post(tap: .cghidEventTap)
        }
    }

    private static func keyCode(for key: String) -> CGKeyCode? {
        let letters: [String: Int] = [
            "A": kVK_ANSI_A, "B": kVK_ANSI_B, "C": kVK_ANSI_C, "D": kVK_ANSI_D,
            "E": kVK_ANSI_E, "F": kVK_ANSI_F, "G": kVK_ANSI_G, "H": kVK_ANSI_H,
            "I": kVK_ANSI_I, "J": kVK_ANSI_J, "K": kVK_ANSI_K, "L": kVK_ANSI_L,
            "M": kVK_ANSI_M, "N": kVK_ANSI_N, "O": kVK_ANSI_O, "P": kVK_ANSI_P,
            "Q": kVK_ANSI_Q, "R": kVK_ANSI_R, "S": kVK_ANSI_S, "T": kVK_ANSI_T,
            "U": kVK_ANSI_U, "V": kVK_ANSI_V, "W": kVK_ANSI_W, "X": kVK_ANSI_X,
            "Y": kVK_ANSI_Y, "Z": kVK_ANSI_Z,
            "0": kVK_ANSI_0, "1": kVK_ANSI_1, "2": kVK_ANSI_2, "3": kVK_ANSI_3,
            "4": kVK_ANSI_4, "5": kVK_ANSI_5, "6": kVK_ANSI_6, "7": kVK_ANSI_7,
            "8": kVK_ANSI_8, "9": kVK_ANSI_9,
        ]
        if let code = letters[key] { return CGKeyCode(code) }
        let special: [String: Int] = [
            "RETURN": kVK_Return, "ENTER": kVK_Return, "TAB": kVK_Tab,
            "SPACE": kVK_Space, "ESC": kVK_Escape, "ESCAPE": kVK_Escape,
            "DELETE": kVK_ForwardDelete, "BACKSPACE": kVK_Delete,
            "LEFT": kVK_LeftArrow, "ARROWLEFT": kVK_LeftArrow,
            "RIGHT": kVK_RightArrow, "ARROWRIGHT": kVK_RightArrow,
            "UP": kVK_UpArrow, "ARROWUP": kVK_UpArrow,
            "DOWN": kVK_DownArrow, "ARROWDOWN": kVK_DownArrow,
            "HOME": kVK_Home, "END": kVK_End,
            "PAGEUP": kVK_PageUp, "PAGEDOWN": kVK_PageDown,
        ]
        return special[key].map(CGKeyCode.init)
    }
}
