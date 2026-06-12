import Foundation

public struct LumiAgentToolInfo: Identifiable, Equatable, Sendable {
    public let id: String
    public let displayName: String
    public let description: String

    public init(id: String, displayName: String, description: String) {
        self.id = id
        self.displayName = displayName
        self.description = description
    }
}

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
        if case .string(let value) = self {
            return value
        }
        return nil
    }

    public var boolValue: Bool? {
        if case .bool(let value) = self {
            return value
        }
        return nil
    }

    public var anyValue: Any {
        switch self {
        case .string(let value):
            value
        case .int(let value):
            value
        case .double(let value):
            value
        case .bool(let value):
            value
        case .object(let value):
            value.mapValues { $0.anyValue }
        case .array(let value):
            value.map(\.anyValue)
        case .null:
            NSNull()
        }
    }
}

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

public struct LumiToolResult: Codable, Equatable, Sendable {
    public let content: String
    public let duration: TimeInterval?
    public let isError: Bool

    public init(content: String, duration: TimeInterval? = nil, isError: Bool = false) {
        self.content = content
        self.duration = duration
        self.isError = isError
    }
}

public enum LumiCommandRiskLevel: String, Codable, Equatable, Sendable, CaseIterable {
    case safe
    case low
    case medium
    case high

    public var requiresPermission: Bool {
        self == .high
    }
}

public final class LumiToolExecutionContext: @unchecked Sendable {
    public let conversationID: UUID
    public let toolCallID: String
    public let toolName: String
    public let currentProjectPath: String?
    public let allowedDirectories: [String]

    public init(
        conversationID: UUID,
        toolCallID: String,
        toolName: String,
        currentProjectPath: String? = nil,
        allowedDirectories: [String] = []
    ) {
        self.conversationID = conversationID
        self.toolCallID = toolCallID
        self.toolName = toolName
        self.currentProjectPath = currentProjectPath
        self.allowedDirectories = allowedDirectories.map(Self.resolvePath)
    }

    public func isPathAllowed(_ path: String) -> Bool {
        guard !allowedDirectories.isEmpty else {
            return true
        }

        let resolvedPath = Self.resolvePath(path)
        return allowedDirectories.contains { allowedDirectory in
            resolvedPath == allowedDirectory || resolvedPath.hasPrefix("\(allowedDirectory)/")
        }
    }

    public static func resolvePath(_ path: String) -> String {
        let expanded = (path as NSString).expandingTildeInPath
        let resolved = URL(fileURLWithPath: expanded).resolvingSymlinksInPath().standardizedFileURL.path
        return resolved.hasSuffix("/") ? String(resolved.dropLast()) : resolved
    }
}

public protocol LumiAgentTool: Sendable {
    static var info: LumiAgentToolInfo { get }

    var name: String { get }
    var toolDescription: String { get }
    var inputSchema: LumiJSONValue { get }

    func execute(arguments: [String: LumiJSONValue], context: LumiToolExecutionContext) async throws -> String
    func riskLevel(arguments: [String: LumiJSONValue], context: LumiToolExecutionContext?) -> LumiCommandRiskLevel
    func displayDescription(arguments: [String: LumiJSONValue]) -> String
}

public extension LumiAgentTool {
    var name: String {
        Self.info.id
    }

    var toolDescription: String {
        Self.info.description
    }

    func riskLevel(arguments: [String: LumiJSONValue], context: LumiToolExecutionContext?) -> LumiCommandRiskLevel {
        .low
    }

    func displayDescription(arguments: [String: LumiJSONValue]) -> String {
        Self.info.displayName
    }
}

@MainActor
public protocol LumiToolServicing: AnyObject {
    var tools: [any LumiAgentTool] { get }

    func registerTools(_ tools: [any LumiAgentTool])
    func tool(named name: String) -> (any LumiAgentTool)?
    func execute(_ toolCall: LumiToolCall, conversationID: UUID) async -> LumiToolResult
}
