import AgentToolKit
import LumiCoreKit

enum RAGLumiToolSupport {
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

struct RAGCodeSearchLumiTool: LumiAgentTool, @unchecked Sendable {
    private let underlying = RAGCodeSearchTool()

    static let info = LumiAgentToolInfo(
        id: "search_code",
        displayName: "Search Code",
        description: "Search code snippets in the current project."
    )

    var inputSchema: LumiJSONValue {
        RAGLumiToolSupport.convertSchema(underlying.inputSchema(for: .english))
    }

    func displayDescription(arguments: [String: LumiJSONValue]) -> String {
        underlying.displayDescription(for: RAGLumiToolSupport.convertArguments(arguments))
    }

    func riskLevel(arguments: [String: LumiJSONValue], context: LumiToolExecutionContext?) -> LumiCommandRiskLevel {
        let legacyContext = context.map(RAGLumiToolSupport.convertContext)
        return RAGLumiToolSupport.convertRisk(
            underlying.permissionRiskLevel(
                arguments: RAGLumiToolSupport.convertArguments(arguments),
                context: legacyContext
            )
        )
    }

    func execute(arguments: [String: LumiJSONValue], context: LumiToolExecutionContext) async throws -> String {
        try await underlying.execute(
            arguments: RAGLumiToolSupport.convertArguments(arguments),
            context: RAGLumiToolSupport.convertContext(context)
        )
    }
}
