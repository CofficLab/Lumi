import AppKit
import ApplicationServices
import CoreGraphics

/// Only created inside a coordinator lease. Key/button releases bypass a revoked
/// lease so a cancellation halfway through a drag cannot leave the button held.
@MainActor
final class NativeInputDriver {
    private let session: NativeControlSession
    private let validateTarget: () throws -> Void
    private var releases: [CGEvent] = []
    private let source = CGEventSource(stateID: .privateState)

    init(session: NativeControlSession, validateTarget: @escaping () throws -> Void) {
        self.session = session
        self.validateTarget = validateTarget
    }

    func releaseHeldInput() {
        for event in releases { postUnchecked(event) }
        releases.removeAll()
    }

    func execute(_ action: ComputerUseAction, observation: ComputerUseObservation) async throws {
        try check()
        switch action {
        case .screenshot: break
        case .wait(let milliseconds):
            for _ in 0..<(max(0, milliseconds) / 20 + 1) {
                try check()
                try await Task.sleep(for: .milliseconds(20))
            }
        case .move(let x, let y):
            try await mouse(.mouseMoved, at: ComputerUseInputExecutor.screenPoint(x: x, y: y, observation: observation))
        case .click(let x, let y, let button, let count):
            let point = try ComputerUseInputExecutor.screenPoint(x: x, y: y, observation: observation)
            let cgButton: CGMouseButton = button == .right ? .right : button == .center ? .center : .left
            let down: CGEventType = button == .right ? .rightMouseDown : button == .center ? .otherMouseDown : .leftMouseDown
            let up: CGEventType = button == .right ? .rightMouseUp : button == .center ? .otherMouseUp : .leftMouseUp
            for index in 1...max(1, min(count, 2)) {
                let release = try mouseEvent(up, at: point, button: cgButton)
                let press = try mouseEvent(down, at: point, button: cgButton)
                press.setIntegerValueField(.mouseEventClickState, value: Int64(index))
                release.setIntegerValueField(.mouseEventClickState, value: Int64(index))
                releases.append(release)
                try await post(press)
                try await post(release)
                releases.removeAll()
            }
        case .drag(let path):
            let points = try path.map { try ComputerUseInputExecutor.screenPoint(x: $0.x, y: $0.y, observation: observation) }
            guard let first = points.first else { throw ComputerUseError.invalidArguments("Empty drag") }
            try await mouse(.mouseMoved, at: first)
            releases = [try mouseEvent(.leftMouseUp, at: first)]
            try await mouse(.leftMouseDown, at: first)
            for point in points.dropFirst() {
                releases = [try mouseEvent(.leftMouseUp, at: point)]
                try await mouse(.leftMouseDragged, at: point)
            }
            if let release = releases.first { try await post(release) }
            releases.removeAll()
        case .scroll(let x, let y, let deltaX, let deltaY):
            guard deltaX.isFinite, deltaY.isFinite, abs(deltaX) <= 100_000, abs(deltaY) <= 100_000 else {
                throw ComputerUseError.invalidArguments("Scroll deltas must be finite and <= 100000")
            }
            try await mouse(.mouseMoved, at: ComputerUseInputExecutor.screenPoint(x: x, y: y, observation: observation))
            guard let event = CGEvent(scrollWheelEvent2Source: source, units: .pixel, wheelCount: 2,
                                      wheel1: Int32(-deltaY), wheel2: Int32(-deltaX), wheel3: 0) else { throw ComputerUseError.eventCreationFailed }
            try await post(event)
        case .type(let text):
            try ensureNonSecureFocus()
            let chars = Array(text.utf16)
            for start in stride(from: 0, to: chars.count, by: 20) {
                try ensureNonSecureFocus()
                let chunk = Array(chars[start..<min(start + 20, chars.count)])
                let down = try keyboard(0, down: true)
                let up = try keyboard(0, down: false)
                chunk.withUnsafeBufferPointer { buffer in
                    if let address = buffer.baseAddress {
                        down.keyboardSetUnicodeString(stringLength: buffer.count, unicodeString: address)
                        up.keyboardSetUnicodeString(stringLength: buffer.count, unicodeString: address)
                    }
                }
                releases = [up]
                try await post(down)
                try await post(up)
                releases.removeAll()
            }
        case .keypress(let rawKeys):
            try ensureNonSecureFocus()
            let keys = rawKeys.map { $0.uppercased().replacingOccurrences(of: " ", with: "") }
            let modifiers: [String: CGEventFlags] = ["CMD": .maskCommand, "COMMAND": .maskCommand, "META": .maskCommand,
                                                   "SHIFT": .maskShift, "CTRL": .maskControl, "CONTROL": .maskControl,
                                                   "OPTION": .maskAlternate, "ALT": .maskAlternate, "FN": .maskSecondaryFn]
            let flags = keys.compactMap { modifiers[$0] }.reduce(CGEventFlags()) { $0.union($1) }
            let codes = keys.filter { modifiers[$0] == nil }
            guard !codes.isEmpty, codes.allSatisfy({ ComputerUseInputExecutor.keyCode(for: $0) != nil }) else {
                throw ComputerUseError.invalidArguments("Unsupported keypress")
            }
            for key in codes {
                let code = ComputerUseInputExecutor.keyCode(for: key)!
                let down = try keyboard(code, down: true)
                let up = try keyboard(code, down: false)
                down.flags = flags
                up.flags = []
                releases = [up]
                try await post(down)
                try await post(up)
                releases.removeAll()
            }
        }
    }

    private func check() throws { try session.check(); try validateTarget() }
    private func post(_ event: CGEvent) async throws {
        try check()
        if [.mouseMoved, .leftMouseDown, .rightMouseDown, .otherMouseDown, .leftMouseDragged].contains(event.type) {
            NativeControlCoordinator.shared.avoidBanner(at: event.location)
        }
        postUnchecked(event)
        // Give event delivery and physical-input revocation a chance between events.
        try await Task.sleep(for: .milliseconds(12))
    }
    private func postUnchecked(_ event: CGEvent) {
        event.setIntegerValueField(.eventSourceUserData, value: NativeControlSession.eventMarker)
        event.post(tap: .cghidEventTap)
    }
    private func mouseEvent(_ type: CGEventType, at point: CGPoint, button: CGMouseButton = .left) throws -> CGEvent {
        guard let event = CGEvent(mouseEventSource: source, mouseType: type, mouseCursorPosition: point, mouseButton: button) else {
            throw ComputerUseError.eventCreationFailed
        }
        return event
    }
    private func mouse(_ type: CGEventType, at point: CGPoint) async throws { try await post(mouseEvent(type, at: point)) }
    private func keyboard(_ code: CGKeyCode, down: Bool) throws -> CGEvent {
        guard let event = CGEvent(keyboardEventSource: source, virtualKey: code, keyDown: down) else { throw ComputerUseError.eventCreationFailed }
        return event
    }
    private func ensureNonSecureFocus() throws {
        let system = AXUIElementCreateSystemWide()
        var value: CFTypeRef?
        guard AXUIElementCopyAttributeValue(system, kAXFocusedUIElementAttribute as CFString, &value) == .success,
              let value, CFGetTypeID(value) == AXUIElementGetTypeID() else { throw ComputerUseError.secureInputBlocked }
        let element = value as! AXUIElement
        var role: CFTypeRef?
        guard AXUIElementCopyAttributeValue(element, kAXRoleAttribute as CFString, &role) == .success else { throw ComputerUseError.secureInputBlocked }
        var subrole: CFTypeRef?
        let result = AXUIElementCopyAttributeValue(element, kAXSubroleAttribute as CFString, &subrole)
        if (subrole as? String) == kAXSecureTextFieldSubrole || (result != .success && result != .attributeUnsupported && result != .noValue) {
            throw ComputerUseError.secureInputBlocked
        }
    }
}
