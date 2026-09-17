import AppKit
import ApplicationServices
import Foundation

/// AX references never leave this actor. Model-facing IDs belong to one snapshot
/// and are consumed before mutation, including when the app returns an error.
@MainActor
final class AccessibilityService {
    static let shared = AccessibilityService()

    struct Element: Codable, Sendable {
        let id: String
        let parent: String?
        let role: String
        let label: String
        let value: String?
        let enabled: Bool
        let actions: [String]
        let valueSettable: Bool
        let secure: Bool
    }

    struct Snapshot: Codable, Sendable {
        let observationID: String
        let application: String
        let bundleIdentifier: String
        let elements: [Element]
        let truncated: Bool
    }

    private struct Stored {
        let snapshot: Snapshot
        let pid: pid_t
        let launchDate: Date?
        let date: Date
        let refs: [String: AXUIElement]
    }

    private var snapshots: [String: Stored] = [:]
    private var inspections: [String: Date] = [:]
    private let authorization: ComputerUseAuthorizationStore

    init(authorization: ComputerUseAuthorizationStore = .shared) {
        self.authorization = authorization
    }

    func hasRecentInspection(_ bundleID: String) -> Bool {
        inspections[bundleID].map { Date().timeIntervalSince($0) < 120 } ?? false
    }

    func observe(application query: String) throws -> String {
        guard ComputerUsePermissionService.hasAccessibilityPermission else {
            throw ComputerUseError.accessibilityPermissionRequired
        }
        let query = query.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !query.isEmpty else { throw ComputerUseError.invalidArguments("application is required") }
        let apps = NSWorkspace.shared.runningApplications.filter {
            $0.processIdentifier != ProcessInfo.processInfo.processIdentifier &&
            ($0.bundleIdentifier == query || $0.localizedName?.localizedCaseInsensitiveCompare(query) == .orderedSame)
        }
        guard apps.count == 1, let app = apps.first, let bundleID = app.bundleIdentifier else {
            throw ComputerUseError.invalidArguments("Use the exact bundle identifier of one running application.")
        }
        guard authorization.isAllowed(bundleID) else {
            throw ComputerUseError.applicationNotAllowed(app.localizedName ?? bundleID)
        }
        let root = AXUIElementCreateApplication(app.processIdentifier)
        AXUIElementSetMessagingTimeout(root, 0.2)
        var refs: [String: AXUIElement] = [:]
        var elements: [Element] = []
        var visited: [AXUIElement] = []
        var queue: [(AXUIElement, String?, Int)] = [(root, nil, 0)]
        let start = ContinuousClock.now
        var index = 0
        while index < queue.count, elements.count < 200, start.duration(to: .now) < .seconds(3) {
            try Task.checkCancellation()
            let (ref, parent, depth) = queue[index]
            index += 1
            guard !visited.contains(where: { CFEqual($0, ref) }) else { continue }
            visited.append(ref)
            let role = string(ref, kAXRoleAttribute) ?? "unknown"
            let secure = string(ref, kAXSubroleAttribute) == kAXSecureTextFieldSubrole
            let id = "e\(elements.count + 1)"
            let actions = actionNames(ref)
            var settable = DarwinBoolean(false)
            AXUIElementIsAttributeSettable(ref, kAXValueAttribute as CFString, &settable)
            let element = Element(
                id: id, parent: parent, role: role,
                label: String((string(ref, kAXTitleAttribute) ?? string(ref, kAXDescriptionAttribute) ?? "").prefix(200)),
                value: secure ? nil : valueText(ref),
                enabled: (attribute(ref, kAXEnabledAttribute) as? Bool) ?? true,
                actions: secure ? [] : actions.filter { Self.allowedActions.contains($0) },
                valueSettable: !secure && settable.boolValue, secure: secure
            )
            refs[id] = ref
            elements.append(element)
            if depth < 12 && !secure {
                // Bound allocation as well as traversal; don't copy huge table children.
                for key in depth == 0 ? [kAXChildrenAttribute, kAXWindowsAttribute] : [kAXChildrenAttribute] {
                    var children: CFArray?
                    var count: CFIndex = 0
                    guard AXUIElementGetAttributeValueCount(ref, key as CFString, &count) == .success, count > 0 else { continue }
                    if AXUIElementCopyAttributeValues(ref, key as CFString, 0, min(count, 200), &children) == .success,
                       let children = children as? [AXUIElement] {
                        queue.append(contentsOf: children.prefix(max(0, 400 - queue.count)).map { ($0, id, depth + 1) })
                    }
                }
            }
        }
        let snapshot = Snapshot(observationID: UUID().uuidString,
                                application: app.localizedName ?? bundleID, bundleIdentifier: bundleID,
                                elements: elements, truncated: index < queue.count || elements.count >= 200)
        snapshots = snapshots.filter { Date().timeIntervalSince($0.value.date) < 60 && $0.value.snapshot.bundleIdentifier != bundleID }
        if snapshots.count >= 8 { snapshots.removeAll() }
        snapshots[snapshot.observationID] = Stored(snapshot: snapshot, pid: app.processIdentifier,
                                                  launchDate: app.launchDate, date: Date(), refs: refs)
        inspections[bundleID] = Date()
        return try json(snapshot)
    }

    func act(observationID: String, elementID: String, action: String, value: String?) throws -> String {
        guard !NativeControlCoordinator.shared.isBusy else {
            throw ComputerUseError.invalidArguments("A native operation is active or paused. Wait for the user; do not change its target through Accessibility.")
        }
        guard ComputerUsePermissionService.hasAccessibilityPermission else { throw ComputerUseError.accessibilityPermissionRequired }
        guard let stored = snapshots[observationID], Date().timeIntervalSince(stored.date) < 60,
              let app = NSRunningApplication(processIdentifier: stored.pid),
              app.bundleIdentifier == stored.snapshot.bundleIdentifier, app.launchDate == stored.launchDate,
              let ref = stored.refs[elementID] else {
            throw ComputerUseError.invalidArguments("Expired or invalid AX element. Call accessibility_observe again.")
        }
        guard authorization.isAllowed(stored.snapshot.bundleIdentifier) else {
            throw ComputerUseError.applicationNotAllowed(stored.snapshot.application)
        }
        guard string(ref, kAXSubroleAttribute) != kAXSecureTextFieldSubrole else { throw ComputerUseError.secureInputBlocked }
        guard attribute(ref, kAXRoleAttribute) != nil,
              (attribute(ref, kAXEnabledAttribute) as? Bool) != false else {
            throw ComputerUseError.invalidArguments("Element is unavailable or disabled. Observe again.")
        }
        let before = valueText(ref)
        let result: AXError
        if action == "set_value" {
            guard let value, value.utf8.count <= 20_000 else { throw ComputerUseError.invalidArguments("set_value requires text <= 20 KB") }
            var settable = DarwinBoolean(false)
            guard AXUIElementIsAttributeSettable(ref, kAXValueAttribute as CFString, &settable) == .success, settable.boolValue else {
                throw ComputerUseError.invalidArguments("This element does not support setting its value.")
            }
            snapshots.removeValue(forKey: observationID)
            result = AXUIElementSetAttributeValue(ref, kAXValueAttribute as CFString, value as CFString)
        } else {
            guard Self.allowedActions.contains(action), actionNames(ref).contains(action) else {
                throw ComputerUseError.invalidArguments("Unsupported AX action. Inspect the element's actions; do not guess.")
            }
            snapshots.removeValue(forKey: observationID)
            result = AXUIElementPerformAction(ref, action as CFString)
        }
        let after = valueText(ref)
        let response: [String: String] = [
            "status": result == .success ? "action_dispatched" : "outcome_uncertain",
            "ax_error": String(result.rawValue), "before": before ?? "unavailable", "after": after ?? "unavailable",
            "next_step": "Call accessibility_observe to verify the expected state. Do not repeat or fall back to a click until you verify whether the action took effect."
        ]
        return try json(response)
    }

    static let allowedActions = [kAXPressAction, kAXPickAction, kAXIncrementAction, kAXDecrementAction, kAXConfirmAction]

    private func attribute(_ ref: AXUIElement, _ key: String) -> CFTypeRef? {
        var value: CFTypeRef?
        return AXUIElementCopyAttributeValue(ref, key as CFString, &value) == .success ? value : nil
    }
    private func string(_ ref: AXUIElement, _ key: String) -> String? { attribute(ref, key) as? String }
    private func valueText(_ ref: AXUIElement) -> String? {
        // Recheck because controls can change role after a previous observation.
        guard string(ref, kAXSubroleAttribute) != kAXSecureTextFieldSubrole else { return nil }
        if let text = attribute(ref, kAXValueAttribute) as? String { return String(text.prefix(500)) }
        if let number = attribute(ref, kAXValueAttribute) as? NSNumber { return number.stringValue }
        return nil
    }
    private func actionNames(_ ref: AXUIElement) -> [String] {
        var value: CFArray?
        return AXUIElementCopyActionNames(ref, &value) == .success ? (value as? [String] ?? []) : []
    }
    private func json<T: Encodable>(_ value: T) throws -> String {
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.sortedKeys]
        return String(decoding: try encoder.encode(value), as: UTF8.self)
    }
}
