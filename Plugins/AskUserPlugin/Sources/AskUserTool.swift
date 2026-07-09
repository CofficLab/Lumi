import AgentToolKit
import Foundation
import LumiCoreKit
import SuperLogKit
import os

/// 询问用户工具
///
/// 让 LLM 可以向用户提问并等待回答。支持是/否选择、多选项选择和自由输入。
/// 当 LLM 需要用户确认操作或获取用户偏好时使用此工具。
///
/// ## 使用场景
///
/// - 确认操作："是否继续执行？"
/// - 选择选项："选择哪种方案？A/B/C"
/// - 获取输入：让用户输入文本
///
/// ## 工作流程
///
/// 1. LLM 调用 ask_user 工具
/// 2. 工具立即返回 `__ASK_USER_PENDING__` 标记 + JSON
/// 3. `ToolCallExecutor` 识别标记，构造 `awaitingUserResponse = true` 的 result
/// 4. `AgentTurnService` 检测到暂停循环
/// 5. UI 渲染选择界面，用户点击选项
/// 6. 渲染器通过 `resumeToolCall` 回调写回真正结果并恢复 Agent 循环
/// 7. LLM 收到用户的回答作为 tool result，继续处理
public struct AskUserTool: SuperAgentTool, SuperLog {
    public nonisolated static let emoji = "❓"
    public nonisolated static let verbose: Bool = true
    public nonisolated static let logger = Logger(subsystem: "com.coffic.lumi", category: "tool.ask-user")

    /// 工具名称，用于在整个插件中统一引用
    public static let name = "ask_user"
    public let name: String = Self.name

    /// 工具返回值中用于标记等待用户回答的前缀。
    ///
    /// `ToolCallExecutor` 检测到此前缀后会设置 `awaitingUserResponse = true`。
    public static let pendingPrefix = LumiAskUserMarkers.pendingPrefix

    public init() {}

    public func description(for language: LanguagePreference) -> String {
        switch language {
        case .chinese:
            return "向用户提问并等待回答。可用于确认操作、获取选择等。当需要用户决策时使用此工具，不要自己假设用户意图。"
        case .english:
            return """
            Ask the user a question and wait for their response. Use this to confirm actions or get user preferences. \
            When you need user decision, use this tool instead of assuming user intent.
            """
        }
    }

    public func inputSchema(for language: LanguagePreference) -> [String: Any] {
        [
            "type": "object",
            "properties": [
                "question": [
                    "type": "string",
                    "description": language == .chinese
                        ? "向用户提出的问题（如：是否继续执行？）"
                        : "Question to ask the user (e.g.: Should I continue?)",
                ],
                "options": [
                    "type": "array",
                    "items": ["type": "string"],
                    "description": language == .chinese
                        ? "可选的选项列表（如：[\"是\", \"否\"]），默认为是/否"
                        : "List of options for user to choose (e.g.: [\"Yes\", \"No\"]), defaults to Yes/No",
                ],
                "allow_free_input": [
                    "type": "boolean",
                    "description": language == .chinese
                        ? "是否允许用户自由输入文本（默认 false，只允许选择预设选项）"
                        : "Whether to allow free text input (default false, only allow selecting preset options)",
                ],
            ],
            "required": ["question"],
        ]
    }

    public func displayDescription(for arguments: [String: ToolArgument]) -> String {
        if let question = arguments["question"]?.value as? String {
            return "询问: \(question.prefix(50))"
        }
        return "询问用户"
    }

    public func permissionRiskLevel(arguments: [String: ToolArgument]) -> CommandRiskLevel {
        .low
    }

    public func execute(arguments: [String: ToolArgument], context: ToolExecutionContext) async throws -> String {
        try context.checkCancellation()

        guard let question = arguments["question"]?.value as? String, !question.isEmpty else {
            return Self.errorResult(message: "question is required and cannot be empty")
        }

        // 解析选项
        var options: [String] = ["是", "否"]
        if let optionsArray = arguments["options"]?.value as? [String], !optionsArray.isEmpty {
            options = optionsArray
        }

        let allowFreeInput = arguments["allow_free_input"]?.value as? Bool ?? false

        // 构建等待响应的 JSON（渲染器用这个 JSON 显示选择界面）
        let pendingResponse = AskUserPendingResponse(
            toolCallId: context.toolCallId,
            question: question,
            options: options,
            allowFreeInput: allowFreeInput,
            conversationId: context.conversationId.uuidString
        )

        let encoder = JSONEncoder()
        encoder.outputFormatting = .prettyPrinted
        let jsonData = try encoder.encode(pendingResponse)
        let jsonString = String(decoding: jsonData, as: UTF8.self)

        if Self.verbose {
            Self.logger.info("\(Self.t) AskUser tool called: \(question) with options: \(options)")
        }

        // 立即返回 pending 标记 + JSON。
        // ToolCallExecutor 会识别前缀并设置 awaitingUserResponse = true，
        // AgentTurnService 据此暂停循环。
        return "\(Self.pendingPrefix)\n\(jsonString)"
    }

    static func errorResult(message: String) -> String {
        let error = AskUserErrorResponse(error: message)
        let encoder = JSONEncoder()
        do {
            let jsonData = try encoder.encode(error)
            return "\(LumiAskUserMarkers.errorPrefix)\n\(String(decoding: jsonData, as: UTF8.self))"
        } catch {
            return "\(LumiAskUserMarkers.errorPrefix)\n{\"error\":\"Failed to encode ask_user error response\"}"
        }
    }
}

// MARK: - Response Models

/// 等待用户响应的数据结构
///
/// 渲染器解析此 JSON 并显示选择界面
public struct AskUserPendingResponse: Codable {
    public let toolCallId: String
    public let question: String
    public let options: [String]
    public let allowFreeInput: Bool
    public let conversationId: String
}

/// 错误响应数据结构
public struct AskUserErrorResponse: Codable {
    public let error: String
}
