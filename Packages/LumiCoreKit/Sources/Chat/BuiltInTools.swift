import Foundation

// MARK: - Built-in Tools

/// No-Op Tool: 空操作工具，用于满足某些 LLM 的"必须调用工具"需求
public struct NoOpTool: LumiAgentTool, @unchecked Sendable {
    public static let info = LumiAgentToolInfo(
        id: "no_op",
        displayName: "No Operation",
        description: "Perform no operation. Use this when the task is complete and no further action is needed."
    )

    public init() {}

    public var name: String { Self.info.id }
    public var toolDescription: String { Self.info.description }

    public var inputSchema: LumiJSONValue {
        .object([
            "type": .string("object"),
            "properties": .object([
                "message": .object([
                    "type": .string("string"),
                    "description": .string("Optional message to include")
                ])
            ]),
            "required": .array([])
        ])
    }

    public func riskLevel(
        arguments: [String: LumiJSONValue],
        context: LumiToolExecutionContext?
    ) -> LumiCommandRiskLevel {
        .safe
    }

    public func execute(
        arguments: [String: LumiJSONValue],
        context: LumiToolExecutionContext
    ) async throws -> String {
        "No operation performed."
    }
}

// MARK: - ConversationInfoTool

/// 返回当前会话的元信息（会话 ID、标题、项目路径等）。
public struct ConversationInfoTool: LumiAgentTool, @unchecked Sendable {
    public static let info = LumiAgentToolInfo(
        id: "conversation_info",
        displayName: "Conversation Info",
        description: "Get information about the current conversation"
    )

    public init() {}

    public var name: String { Self.info.id }
    public var toolDescription: String { Self.info.description }

    public var inputSchema: LumiJSONValue {
        .object([
            "type": .string("object"),
            "properties": .object([:])
        ])
    }

    public func riskLevel(
        arguments: [String: LumiJSONValue],
        context: LumiToolExecutionContext?
    ) -> LumiCommandRiskLevel {
        .safe
    }

    public func execute(
        arguments: [String: LumiJSONValue],
        context: LumiToolExecutionContext
    ) async throws -> String {
        let info: [String: Any] = [
            "conversationID": context.conversationID.uuidString,
            "projectPath": context.currentProjectPath ?? "None"
        ]

        if let data = try? JSONSerialization.data(withJSONObject: info, options: [.prettyPrinted]),
           let string = String(data: data, encoding: .utf8) {
            return string
        }
        return "Conversation ID: \(context.conversationID.uuidString)\nProject Path: \(context.currentProjectPath ?? "None")"
    }
}

// MARK: - Built-in Tools Collection

extension LumiCore {
    /// 内置工具列表
    public static let builtInTools: [any LumiAgentTool] = [
        NoOpTool(),
        ConversationInfoTool(),
    ]
}
