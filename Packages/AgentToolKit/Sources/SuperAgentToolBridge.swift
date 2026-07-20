import Foundation
import LumiCoreMessage
import LumiKernel

/// 将 legacy `SuperAgentTool` 适配为 `LumiAgentTool`，便于插件系统注册。
public struct SuperAgentToolBridge: LumiAgentTool, @unchecked Sendable {
    public static var info: LumiAgentToolInfo {
        LumiAgentToolInfo(id: "super-agent-tool-bridge", displayName: "Tool", description: "")
    }

    private let underlying: any SuperAgentTool
    private let storedInfo: LumiAgentToolInfo

    public init(_ underlying: any SuperAgentTool) {
        self.underlying = underlying
        self.storedInfo = LumiAgentToolInfo(
            id: underlying.name,
            displayName: underlying.name,
            description: underlying.description
        )
    }

    public var name: String { storedInfo.id }

    public var toolDescription: String { storedInfo.description }

    public var inputSchema: LumiJSONValue {
        Self.convertSchema(underlying.inputSchema)
    }

    public func displayDescription(arguments: [String: LumiJSONValue]) -> String {
        underlying.displayDescription(for: Self.convertArguments(arguments))
    }

    public func riskLevel(
        arguments: [String: LumiJSONValue],
        context: LumiToolExecutionContext?
    ) -> LumiCommandRiskLevel {
        let legacyContext = context.map(Self.convertContext)
        return Self.convertRisk(
            underlying.permissionRiskLevel(
                arguments: Self.convertArguments(arguments),
                context: legacyContext
            )
        )
    }

    public func execute(
        arguments: [String: LumiJSONValue],
        context: LumiToolExecutionContext
    ) async throws -> String {
        try await underlying.execute(
            arguments: Self.convertArguments(arguments),
            context: Self.convertContext(context)
        )
    }
}

public extension SuperAgentTool {
    func asLumiAgentTool() -> SuperAgentToolBridge {
        SuperAgentToolBridge(self)
    }
}

private extension SuperAgentToolBridge {
    static func convertSchema(_ schema: [String: Any]) -> LumiJSONValue {
        convertValue(schema)
    }

    static func convertValue(_ value: Any) -> LumiJSONValue {
        switch value {
        case let string as String:
            return .string(string)
        case let int as Int:
            return .int(int)
        case let double as Double:
            return .double(double)
        case let bool as Bool:
            return .bool(bool)
        case let dict as [String: Any]:
            return .object(dict.mapValues { convertValue($0) })
        case let array as [Any]:
            return .array(array.map { convertValue($0) })
        default:
            return .null
        }
    }

    static func convertArguments(_ arguments: [String: LumiJSONValue]) -> [String: ToolArgument] {
        arguments.mapValues { ToolArgument($0.anyValue) }
    }

    static func convertContext(_ context: LumiToolExecutionContext) -> ToolExecutionContext {
        ToolExecutionContext(
            conversationId: context.conversationID,
            toolCallId: context.toolCallID,
            toolName: context.toolName,
            currentProjectPath: context.currentProjectPath,
            allowedDirectories: context.allowedDirectories,
            verbosity: context.verbosity
        )
    }

    static func convertRisk(_ level: CommandRiskLevel) -> LumiCommandRiskLevel {
        switch level {
        case .safe: .safe
        case .low: .low
        case .medium: .medium
        case .high: .high
        }
    }
}
