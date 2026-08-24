import CoreGraphics
import Foundation
import KernelLumi

enum ComputerUseActionParser {
    static func parse(_ value: LumiJSONValue?) throws -> [ComputerUseAction] {
        guard case .array(let rawActions) = value else {
            throw ComputerUseError.invalidArguments("actions must be an array")
        }
        guard !rawActions.isEmpty else {
            throw ComputerUseError.invalidArguments("actions must not be empty")
        }
        guard rawActions.count <= 20 else {
            throw ComputerUseError.invalidArguments("a batch may contain at most 20 actions")
        }
        return try rawActions.map(parseAction)
    }

    private static func parseAction(_ value: LumiJSONValue) throws -> ComputerUseAction {
        guard case .object(let object) = value,
              let type = object.string("type")?.lowercased()
        else {
            throw ComputerUseError.invalidArguments("every action requires a type")
        }

        switch type {
        case "screenshot":
            return .screenshot
        case "click", "double_click":
            let point = try coordinate(in: object)
            let button = ComputerMouseButton(rawValue: object.string("button") ?? "left") ?? .left
            return .click(x: point.x, y: point.y, button: button, count: type == "double_click" ? 2 : 1)
        case "move":
            let point = try coordinate(in: object)
            return .move(x: point.x, y: point.y)
        case "drag":
            guard case .array(let rawPath) = object["path"] else {
                throw ComputerUseError.invalidArguments("drag requires path")
            }
            let path = try rawPath.map { value -> CGPoint in
                guard case .object(let point) = value else {
                    throw ComputerUseError.invalidArguments("drag path entries must contain x and y")
                }
                let coordinate = try coordinate(in: point)
                return CGPoint(x: coordinate.x, y: coordinate.y)
            }
            guard path.count >= 2, path.count <= 100 else {
                throw ComputerUseError.invalidArguments("drag path must contain 2...100 points")
            }
            return .drag(path: path)
        case "scroll":
            let point = try coordinate(in: object)
            return .scroll(
                x: point.x,
                y: point.y,
                deltaX: object.double("delta_x") ?? object.double("scroll_x") ?? 0,
                deltaY: object.double("delta_y") ?? object.double("scroll_y") ?? 0
            )
        case "type":
            guard let text = object.string("text"), text.utf8.count <= 20_000 else {
                throw ComputerUseError.invalidArguments("type requires text no larger than 20 KB")
            }
            return .type(text)
        case "keypress":
            guard let keys = object.stringArray("keys"), !keys.isEmpty, keys.count <= 8 else {
                throw ComputerUseError.invalidArguments("keypress requires 1...8 keys")
            }
            return .keypress(keys)
        case "wait":
            let milliseconds = object.int("milliseconds") ?? 1_000
            return .wait(milliseconds: min(max(milliseconds, 0), 10_000))
        default:
            throw ComputerUseError.invalidArguments("unsupported action type: \(type)")
        }
    }

    private static func coordinate(in object: [String: LumiJSONValue]) throws -> (x: Double, y: Double) {
        guard let x = object.double("x"), let y = object.double("y"),
              x.isFinite, y.isFinite, x >= 0, y >= 0
        else {
            throw ComputerUseError.invalidArguments("action requires non-negative finite x and y")
        }
        return (x, y)
    }
}
