import AgentToolKit
import Foundation
import LumiCoreKit

enum MemoryLumiToolSupport {
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

struct SaveMemoryLumiTool: LumiAgentTool, @unchecked Sendable {
    private let underlying = SaveMemoryTool()

    static let info = LumiAgentToolInfo(
        id: "save_memory",
        displayName: LumiPluginLocalization.string("Save Memory", bundle: .module),
        description: LumiPluginLocalization.string("Save a memory to the persistent memory system.", bundle: .module)
    )

    var inputSchema: LumiJSONValue {
        MemoryLumiToolSupport.convertSchema(underlying.inputSchema(for: .english))
    }

    func displayDescription(arguments: [String: LumiJSONValue]) -> String {
        underlying.displayDescription(for: MemoryLumiToolSupport.convertArguments(arguments))
    }

    func riskLevel(arguments: [String: LumiJSONValue], context: LumiToolExecutionContext?) -> LumiCommandRiskLevel {
        MemoryLumiToolSupport.convertRisk(
            underlying.permissionRiskLevel(arguments: MemoryLumiToolSupport.convertArguments(arguments))
        )
    }

    func execute(arguments: [String: LumiJSONValue], context: LumiToolExecutionContext) async throws -> String {
        try await underlying.execute(
            arguments: MemoryLumiToolSupport.convertArguments(arguments),
            context: MemoryLumiToolSupport.convertContext(context)
        )
    }
}

struct RecallMemoryLumiTool: LumiAgentTool, @unchecked Sendable {
    private let underlying = RecallMemoryTool()

    static let info = LumiAgentToolInfo(
        id: "recall_memory",
        displayName: LumiPluginLocalization.string("Recall Memory", bundle: .module),
        description: LumiPluginLocalization.string("Search for memories related to a query.", bundle: .module)
    )

    var inputSchema: LumiJSONValue {
        MemoryLumiToolSupport.convertSchema(underlying.inputSchema(for: .english))
    }

    func displayDescription(arguments: [String: LumiJSONValue]) -> String {
        underlying.displayDescription(for: MemoryLumiToolSupport.convertArguments(arguments))
    }

    func riskLevel(arguments: [String: LumiJSONValue], context: LumiToolExecutionContext?) -> LumiCommandRiskLevel {
        MemoryLumiToolSupport.convertRisk(
            underlying.permissionRiskLevel(arguments: MemoryLumiToolSupport.convertArguments(arguments))
        )
    }

    func execute(arguments: [String: LumiJSONValue], context: LumiToolExecutionContext) async throws -> String {
        try await underlying.execute(
            arguments: MemoryLumiToolSupport.convertArguments(arguments),
            context: MemoryLumiToolSupport.convertContext(context)
        )
    }
}

struct ListMemoriesLumiTool: LumiAgentTool, @unchecked Sendable {
    private let underlying = ListMemoriesTool()

    static let info = LumiAgentToolInfo(
        id: "list_memories",
        displayName: LumiPluginLocalization.string("List Memories", bundle: .module),
        description: LumiPluginLocalization.string("List all saved memories.", bundle: .module)
    )

    var inputSchema: LumiJSONValue {
        MemoryLumiToolSupport.convertSchema(underlying.inputSchema(for: .english))
    }

    func displayDescription(arguments: [String: LumiJSONValue]) -> String {
        underlying.displayDescription(for: MemoryLumiToolSupport.convertArguments(arguments))
    }

    func riskLevel(arguments: [String: LumiJSONValue], context: LumiToolExecutionContext?) -> LumiCommandRiskLevel {
        MemoryLumiToolSupport.convertRisk(
            underlying.permissionRiskLevel(arguments: MemoryLumiToolSupport.convertArguments(arguments))
        )
    }

    func execute(arguments: [String: LumiJSONValue], context: LumiToolExecutionContext) async throws -> String {
        try await underlying.execute(
            arguments: MemoryLumiToolSupport.convertArguments(arguments),
            context: MemoryLumiToolSupport.convertContext(context)
        )
    }
}

struct DeleteMemoryLumiTool: LumiAgentTool, @unchecked Sendable {
    private let underlying = DeleteMemoryTool()

    static let info = LumiAgentToolInfo(
        id: "delete_memory",
        displayName: LumiPluginLocalization.string("Delete Memory", bundle: .module),
        description: LumiPluginLocalization.string("Delete a memory from the persistent memory system.", bundle: .module)
    )

    var inputSchema: LumiJSONValue {
        MemoryLumiToolSupport.convertSchema(underlying.inputSchema(for: .english))
    }

    func displayDescription(arguments: [String: LumiJSONValue]) -> String {
        underlying.displayDescription(for: MemoryLumiToolSupport.convertArguments(arguments))
    }

    func riskLevel(arguments: [String: LumiJSONValue], context: LumiToolExecutionContext?) -> LumiCommandRiskLevel {
        MemoryLumiToolSupport.convertRisk(
            underlying.permissionRiskLevel(arguments: MemoryLumiToolSupport.convertArguments(arguments))
        )
    }

    func execute(arguments: [String: LumiJSONValue], context: LumiToolExecutionContext) async throws -> String {
        try await underlying.execute(
            arguments: MemoryLumiToolSupport.convertArguments(arguments),
            context: MemoryLumiToolSupport.convertContext(context)
        )
    }
}
