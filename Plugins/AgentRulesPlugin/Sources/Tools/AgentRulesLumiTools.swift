import AgentToolKit
import LumiCoreKit

enum AgentRulesLumiToolSupport {
    static func convertSchema(_ schema: [String: Any]) -> LumiJSONValue {
        convertValue(schema)
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
            allowedDirectories: context.allowedDirectories
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

    private static func convertValue(_ value: Any) -> LumiJSONValue {
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
}

struct CreateAgentRuleLumiTool: LumiAgentTool, @unchecked Sendable {
    private let underlying = CreateAgentRuleTool()

    static let info = LumiAgentToolInfo(
        id: "create_agent_rule",
        displayName: "Create Agent Rule",
        description: "Create a new rule document in the .agent/rules directory."
    )

    var inputSchema: LumiJSONValue {
        AgentRulesLumiToolSupport.convertSchema(underlying.inputSchema(for: .english))
    }

    func displayDescription(arguments: [String: LumiJSONValue]) -> String {
        underlying.displayDescription(for: AgentRulesLumiToolSupport.convertArguments(arguments))
    }

    func riskLevel(arguments: [String: LumiJSONValue], context: LumiToolExecutionContext?) -> LumiCommandRiskLevel {
        AgentRulesLumiToolSupport.convertRisk(
            underlying.permissionRiskLevel(arguments: AgentRulesLumiToolSupport.convertArguments(arguments))
        )
    }

    func execute(arguments: [String: LumiJSONValue], context: LumiToolExecutionContext) async throws -> String {
        try await underlying.execute(
            arguments: AgentRulesLumiToolSupport.convertArguments(arguments),
            context: AgentRulesLumiToolSupport.convertContext(context)
        )
    }
}

struct ListAgentRulesLumiTool: LumiAgentTool, @unchecked Sendable {
    private let underlying = ListAgentRulesTool()

    static let info = LumiAgentToolInfo(
        id: "list_agent_rules",
        displayName: "List Agent Rules",
        description: "List rule documents in the .agent/rules directory."
    )

    var inputSchema: LumiJSONValue {
        AgentRulesLumiToolSupport.convertSchema(underlying.inputSchema(for: .english))
    }

    func displayDescription(arguments: [String: LumiJSONValue]) -> String {
        underlying.displayDescription(for: AgentRulesLumiToolSupport.convertArguments(arguments))
    }

    func riskLevel(arguments: [String: LumiJSONValue], context: LumiToolExecutionContext?) -> LumiCommandRiskLevel {
        AgentRulesLumiToolSupport.convertRisk(
            underlying.permissionRiskLevel(arguments: AgentRulesLumiToolSupport.convertArguments(arguments))
        )
    }

    func execute(arguments: [String: LumiJSONValue], context: LumiToolExecutionContext) async throws -> String {
        try await underlying.execute(
            arguments: AgentRulesLumiToolSupport.convertArguments(arguments),
            context: AgentRulesLumiToolSupport.convertContext(context)
        )
    }
}
