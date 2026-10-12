import Foundation
import MCP

/// 跨 actor 边界的 Sendable JSON 值类型。
///
/// MCP 的 `Value` 本身是 `Sendable`，但上层（LLM 工具协议）惯用 `[String: Any]`；
/// 桥接层需要一种既是 `Sendable`、又能无损映射到 `Value` 与 JSON 的表示。
/// `MCPJSONValue` 同时提供两条转换路径：
/// - `MCPJSONValue.fromFoundation(_:)`：把 `[String: Any]` 尽力转换为本类型；
/// - `mcpValue()`：转换为 MCP `Value` 用于 `callTool`；
/// - `foundationValue()` / `jsonString()`：转为上层可用的 Foundation 表示。
public enum MCPJSONValue: Sendable, Hashable {
    case null
    case bool(Bool)
    case int(Int)
    case double(Double)
    case string(String)
    case array([MCPJSONValue])
    case object([String: MCPJSONValue])

    // MARK: - MCP Value 转换

    public init(from value: Value) {
        switch value {
        case .null:
            self = .null
        case .bool(let bool):
            self = .bool(bool)
        case .int(let int):
            self = .int(int)
        case .double(let double):
            self = .double(double)
        case .string(let string):
            self = .string(string)
        case .data(_, let data):
            // JSON 场景不承载二进制；退化为 base64 字符串。
            self = .string(data.base64EncodedString())
        case .array(let values):
            self = .array(values.map(MCPJSONValue.init(from:)))
        case .object(let object):
            self = .object(object.mapValues(MCPJSONValue.init(from:)))
        }
    }

    public func mcpValue() -> Value {
        switch self {
        case .null:
            return .null
        case .bool(let bool):
            return .bool(bool)
        case .int(let int):
            return .int(int)
        case .double(let double):
            return .double(double)
        case .string(let string):
            return .string(string)
        case .array(let values):
            return .array(values.map { $0.mcpValue() })
        case .object(let object):
            return .object(object.mapValues { $0.mcpValue() })
        }
    }

    // MARK: - Foundation 转换

    /// 转换为 Foundation 可表示对象（`[String: Any]` 风格，兼容 JSONSerialization）。
    public func foundationValue() -> Any {
        switch self {
        case .null:
            return NSNull()
        case .bool(let bool):
            return bool
        case .int(let int):
            return int
        case .double(let double):
            return double
        case .string(let string):
            return string
        case .array(let values):
            return values.map { $0.foundationValue() }
        case .object(let object):
            var result: [String: Any] = [:]
            for (key, value) in object {
                result[key] = value.foundationValue()
            }
            return result
        }
    }

    /// 尽力把任意 Foundation 值转换为 `MCPJSONValue`；不支持的容器返回 `nil`。
    public static func fromFoundation(_ any: Any?) -> MCPJSONValue? {
        guard let any else { return .null }
        switch any {
        case let value as MCPJSONValue:
            return value
        case let value as Value:
            return MCPJSONValue(from: value)
        case is NSNull:
            return .null
        case let value as Bool:
            return .bool(value)
        case let value as Int:
            return .int(value)
        case let value as Double:
            return .double(value)
        case let value as String:
            return .string(value)
        case let value as [Any]:
            return .array(value.compactMap { fromFoundation($0) })
        case let value as [String: Any]:
            var result: [String: MCPJSONValue] = [:]
            for (key, item) in value {
                guard let converted = fromFoundation(item) else { return nil }
                result[key] = converted
            }
            return .object(result)
        case let value as [String: MCPJSONValue]:
            return .object(value)
        default:
            return nil
        }
    }

    /// 序列化为 JSON 字符串（用于 schema 传递）；失败返回 `nil`。
    public func jsonString() -> String? {
        guard JSONSerialization.isValidJSONObject(foundationValue()) else { return nil }
        guard
            let data = try? JSONSerialization.data(
                withJSONObject: foundationValue(),
                options: [.sortedKeys]
            )
        else { return nil }
        return String(data: data, encoding: .utf8)
    }
}

/// 便捷工具：`[String: Any]` 参数与 MCP `Value` 之间的转换。
public enum MCPValueCoding {
    /// 把上层参数字典（`[String: Any]`）转换为 MCP `Value` 字典（供 `callTool`）。
    public static func mcpArguments(from dictionary: [String: Any]) -> [String: Value] {
        var result: [String: Value] = [:]
        for (key, value) in dictionary {
            guard let jsonValue = MCPJSONValue.fromFoundation(value) else { continue }
            result[key] = jsonValue.mcpValue()
        }
        return result
    }
}
