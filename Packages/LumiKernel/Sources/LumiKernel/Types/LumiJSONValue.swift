import Foundation

// MARK: - LumiJSONValue

/// JSON 值的强类型表示。
///
/// 用于 Agent 工具的参数传递和 schema 定义。
public enum LumiJSONValue: Codable, Equatable, Sendable {
    case string(String)
    case int(Int)
    case double(Double)
    case bool(Bool)
    case object([String: LumiJSONValue])
    case array([LumiJSONValue])
    case null

    public init(from decoder: Decoder) throws {
        let container = try decoder.singleValueContainer()
        if container.decodeNil() {
            self = .null
        } else if let value = try? container.decode(Bool.self) {
            self = .bool(value)
        } else if let value = try? container.decode(Int.self) {
            self = .int(value)
        } else if let value = try? container.decode(Double.self) {
            self = .double(value)
        } else if let value = try? container.decode(String.self) {
            self = .string(value)
        } else if let value = try? container.decode([String: LumiJSONValue].self) {
            self = .object(value)
        } else if let value = try? container.decode([LumiJSONValue].self) {
            self = .array(value)
        } else {
            self = .null
        }
    }

    public func encode(to encoder: Encoder) throws {
        var container = encoder.singleValueContainer()
        switch self {
        case .string(let value):
            try container.encode(value)
        case .int(let value):
            try container.encode(value)
        case .double(let value):
            try container.encode(value)
        case .bool(let value):
            try container.encode(value)
        case .object(let value):
            try container.encode(value)
        case .array(let value):
            try container.encode(value)
        case .null:
            try container.encodeNil()
        }
    }

    public var stringValue: String? {
        if case .string(let value) = self { return value }
        return nil
    }

    public var boolValue: Bool? {
        if case .bool(let value) = self { return value }
        return nil
    }

    public var anyValue: Any {
        switch self {
        case .string(let value): value
        case .int(let value): value
        case .double(let value): value
        case .bool(let value): value
        case .object(let value): value.mapValues { $0.anyValue }
        case .array(let value): value.map(\.anyValue)
        case .null: NSNull()
        }
    }
}

// MARK: - LumiToolCall

/// 工具调用请求。
public struct LumiToolCall: Codable, Equatable, Sendable, Identifiable {
    public let id: String
    public let name: String
    public let arguments: String
    public var result: LumiToolResult?
    public var displayName: String?

    public init(
        id: String,
        name: String,
        arguments: String,
        result: LumiToolResult? = nil,
        displayName: String? = nil
    ) {
        self.id = id
        self.name = name
        self.arguments = arguments
        self.result = result
        self.displayName = displayName
    }
}

// MARK: - LumiToolResult

/// 工具执行结果。
public struct LumiToolResult: Codable, Equatable, Sendable {
    public let content: String
    public let duration: TimeInterval?
    public let isError: Bool
    public let imageAttachments: [LumiImageAttachment]

    public init(
        content: String,
        duration: TimeInterval? = nil,
        isError: Bool = false,
        imageAttachments: [LumiImageAttachment] = []
    ) {
        self.content = content
        self.duration = duration
        self.isError = isError
        self.imageAttachments = imageAttachments
    }

    private enum CodingKeys: String, CodingKey {
        case content, duration, isError, imageAttachments
    }

    public init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        content = try c.decode(String.self, forKey: .content)
        duration = try c.decodeIfPresent(TimeInterval.self, forKey: .duration)
        isError = try c.decodeIfPresent(Bool.self, forKey: .isError) ?? false
        imageAttachments = try c.decodeIfPresent([LumiImageAttachment].self, forKey: .imageAttachments) ?? []
    }

    public func encode(to encoder: Encoder) throws {
        var c = encoder.container(keyedBy: CodingKeys.self)
        try c.encode(content, forKey: .content)
        if let duration { try c.encode(duration, forKey: .duration) }
        if isError { try c.encode(isError, forKey: .isError) }
        if !imageAttachments.isEmpty { try c.encode(imageAttachments, forKey: .imageAttachments) }
    }
}

// MARK: - Argument Accessors

public extension [String: LumiJSONValue] {
    /// 字符串参数。
    func string(_ key: String) -> String? {
        self[key]?.stringValue
    }

    /// 整数参数；兼容以浮点或数字字符串传入的值。
    func int(_ key: String) -> Int? {
        guard let value = self[key] else { return nil }
        switch value {
        case .int(let intValue): return intValue
        case .double(let doubleValue): return Int(doubleValue)
        case .string(let raw): return Int(raw.trimmingCharacters(in: .whitespacesAndNewlines))
        default: return nil
        }
    }

    /// 浮点参数；兼容整数与数字字符串。
    func double(_ key: String) -> Double? {
        guard let value = self[key] else { return nil }
        switch value {
        case .double(let doubleValue): return doubleValue
        case .int(let intValue): return Double(intValue)
        case .string(let raw): return Double(raw.trimmingCharacters(in: .whitespacesAndNewlines))
        default: return nil
        }
    }

    /// 布尔参数；兼容 `0/1` 等常见字面量。
    func bool(_ key: String) -> Bool? {
        guard let value = self[key] else { return nil }
        switch value {
        case .bool(let boolValue): return boolValue
        case .int(let intValue): return intValue != 0
        case .string(let raw):
            switch raw.trimmingCharacters(in: .whitespacesAndNewlines).lowercased() {
            case "true", "yes", "1": return true
            case "false", "no", "0": return false
            default: return nil
            }
        default: return nil
        }
    }

    /// 字符串数组参数。
    func stringArray(_ key: String) -> [String]? {
        guard case .array(let values) = self[key] else { return nil }
        return values.compactMap(\.stringValue)
    }
}