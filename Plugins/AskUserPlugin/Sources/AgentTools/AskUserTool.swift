import AgentToolKit
import Foundation
import LumiKernel
import os
import SuperLogKit

/// 询问用户工具
///
/// 让 LLM 可以向用户提问并等待回答。支持是/否确认、多选项选择和自由输入。
/// 当 LLM 需要用户确认操作或获取用户偏好时使用此工具。
///
/// ## 工作流程
///
/// 1. LLM 调用 ask_user 工具
/// 2. 工具返回结构化的 `AgentTurnControl.suspend` + JSON payload
/// 3. AgentTurnManager 记录暂停状态并结束当前 turn
/// 4. UI 渲染选择界面，用户点击选项
/// 5. AskUserBridge 直接调用 AgentTurnManager.resumeTurn
/// 7. LLM 收到用户的回答作为 tool result，继续处理
public struct AskUserTool: LumiAgentTool, SuperLog {
    public nonisolated static let emoji = "❓"

    public nonisolated static let verbose: Bool = false
    nonisolated static let logger = Logger(subsystem: "com.coffic.lumi", category: "tool.ask-user")

    public static let info = LumiAgentToolInfo(
        id: "ask_user",
        displayName: "Ask User",
        description: """
        Ask the user a question and wait for their response. Supports yes/no, multiple choice, and free text input. \
        Use when you need user decision instead of assuming intent.
        
        IMPORTANT: Choose the right mode based on your question type:
        - Yes/No: Only use the default mode (no options, no allow_free_input) when the question can be genuinely answered with 是 or 否. Example: "Should I continue building?"
        - Multiple choice: Provide `options` when the answer must be one of specific choices. Example: options=["Debug", "Release", "Profile"].
        - Free text: Set `allow_free_input: true` when the question is open-ended and cannot be answered with yes/no or a fixed set of options. Example: "What should I do next?", "How would you like to proceed?", "What branch should I create?". Do NOT use Yes/No mode for open-ended questions like "接下来怎么做?" — always use allow_free_input.
        """
    )

    public init() {}

    // MARK: - LumiAgentTool

    public var inputSchema: LumiJSONValue {
        .object([
            "type": .string("object"),
            "properties": .object([
                "question": .object([
                    "type": .string("string"),
                    "description": .string("Question to ask the user (e.g.: Should I continue?)"),
                ]),
                "options": .object([
                    "type": .string("array"),
                    "items": .object(["type": .string("string")]),
                    "description": .string("List of options for user to choose (e.g.: [\"OptionA\", \"OptionB\"]), defaults to Yes/No. Must be provided when the question is not a simple yes/no."),
                ]),
                "allow_free_input": .object([
                    "type": .string("boolean"),
                    "description": .string("Whether to allow free text input (default false)"),
                ]),
            ]),
            "required": .array([.string("question")]),
        ])
    }

    public func execute(arguments: [String: LumiJSONValue], kernel: LumiKernel) async throws -> String {
        guard let question = arguments.string("question"), !question.isEmpty else {
            return Self.errorResult(message: "question is required and cannot be empty")
        }

        // 检测是否是多选场景但没传 options
        let hasOptions = arguments["options"] != nil
        if !hasOptions && Self.lookLikeMultipleChoice(question) {
            return Self.errorResult(
                message: "Your question appears to require multiple options, but the options parameter was not provided. Please provide an options list."
            )
        }

        // 检测是否是开放式问题但既没传 options 也没允许自由输入
        let hasAllowFreeInput = arguments["allow_free_input"] != nil && Self.resolvedAllowFreeInput(arguments)
        if !hasOptions && !hasAllowFreeInput && Self.lookLikeOpenEnded(question) {
            return Self.errorResult(
                message: "Your question appears to be open-ended (e.g., asking 'how', 'what next', 'why'), but allow_free_input was not enabled. Set allow_free_input to true for open-ended questions."
            )
        }

        let options = Self.resolvedOptions(arguments)
        let allowFreeInput = Self.resolvedAllowFreeInput(arguments)

        logInvocation(question: question, options: options, allowFreeInput: allowFreeInput)

        let pendingResponse = Self.buildPendingResponse(
            kernel: kernel,
            question: question,
            options: options,
            allowFreeInput: allowFreeInput
        )

        let payload = try Self.encodePendingPayload(pendingResponse)
        return payload
    }

    public func executeResult(
        arguments: [String: LumiJSONValue],
        kernel: LumiKernel
    ) async throws -> LumiToolExecutionResult {
        let content = try await execute(arguments: arguments, kernel: kernel)
        guard let data = content.data(using: .utf8),
              let response = try? JSONDecoder().decode(AskUserPendingResponse.self, from: data),
              let conversationID = UUID(uuidString: response.conversationId)
        else {
            return LumiToolExecutionResult(
                content: content,
                isError: content.hasPrefix(LumiAskUserMarkers.errorPrefix)
            )
        }

        let suspension = AgentTurnSuspension(
            suspensionID: response.toolCallId,
            conversationID: conversationID,
            toolCallID: response.toolCallId,
            kind: "userInput",
            payload: content
        )
        return LumiToolExecutionResult(
            content: content,
            turnControl: .suspend(suspension)
        )
    }

    // MARK: - Option Resolution

    /// 解析并归一化 `options` 参数。
    /// 仅当 `options` 是非空字符串数组时才使用；其他情况都回退到 `defaultOptions`。
    static func resolvedOptions(_ arguments: [String: LumiJSONValue]) -> [String] {
        guard let array = arguments.stringArray("options"), !array.isEmpty else {
            return defaultOptions
        }
        return array
    }

    /// 解析 `allow_free_input` 参数；缺失或非 Bool 时默认为 `false`。
    static func resolvedAllowFreeInput(_ arguments: [String: LumiJSONValue]) -> Bool {
        arguments.bool("allow_free_input") ?? false
    }

    // MARK: - Pending Response Building

    /// 构建 `AskUserPendingResponse`，集中所有字段归一化逻辑。
    static func buildPendingResponse(
        kernel: LumiKernel,
        question: String,
        options: [String],
        allowFreeInput: Bool
    ) -> AskUserPendingResponse {
        AskUserPendingResponse(
            toolCallId: kernel.toolCallID,
            question: question,
            options: options,
            allowFreeInput: allowFreeInput,
            conversationId: kernel.conversationID.uuidString,
            verbosity: kernel.verbosity ?? "standard"
        )
    }

    /// 将 `AskUserPendingResponse` 编码为 pretty-printed JSON 字符串。
    static func encodePendingPayload(_ response: AskUserPendingResponse) throws -> String {
        let data = try jsonEncoder.encode(response)
        return String(decoding: data, as: UTF8.self)
    }

    /// 将 `AskUserErrorResponse` 编码为 JSON 字符串。
    static func encodeErrorPayload(_ response: AskUserErrorResponse) throws -> String {
        let data = try jsonEncoder.encode(response)
        return String(decoding: data, as: UTF8.self)
    }

    // MARK: - Logging

    func logInvocation(question: String, options: [String], allowFreeInput: Bool) {
        guard Self.verbose else { return }
        Self.logger.info("\(Self.t) AskUser tool called: \(question) options=\(options) freeInput=\(allowFreeInput)")
    }

    static func errorResult(message: String) -> String {
        let error = AskUserErrorResponse(error: message)
        let payload: String
        do {
            payload = try Self.encodeErrorPayload(error)
        } catch {
            payload = "{\"error\":\"Failed to encode ask_user error response\"}"
        }
        return "\(LumiAskUserMarkers.errorPrefix)\n\(payload)"
    }

    // MARK: - Constants

    /// 当用户没有提供 `options` 参数（或提供非法值）时使用的默认选项。
    static let defaultOptions: [String] = ["是", "否"]

    /// 所有 JSON 编解码共享一个 encoder，配置为 pretty-printed 以便人工检查日志。
    private static let jsonEncoder: JSONEncoder = {
        let encoder = JSONEncoder()
        encoder.outputFormatting = .prettyPrinted
        return encoder
    }()

    // MARK: - Multiple Choice Detection

    /// 检测 question 是否看起来像多选场景。
    /// 当 question 包含选择类关键词时返回 true。
    static func lookLikeMultipleChoice(_ question: String) -> Bool {
        let chineseKeywords = ["哪个", "哪些", "哪一个", "哪一", "选择", "方案", "选项", "模式"]
        let englishKeywords = ["which", "choose", "select", "option", "pick"]

        let lowercased = question.lowercased()
        return chineseKeywords.contains { question.contains($0) }
            || englishKeywords.contains { lowercased.contains($0) }
    }

    /// 检测 question 是否是开放式问题（不能简单用是/否回答）。
    /// 用于拦截 LLM 未传 `allow_free_input` 但问了开放式问题的情况。
    static func lookLikeOpenEnded(_ question: String) -> Bool {
        let chinesePatterns = [
            "怎么办", "做什么", "怎么", "如何", "下一步", "接下来",
            "为什么", "原因", "说明", "解释", "描述", "告诉我",
        ]
        let englishPatterns = [
            "how", "what should", "what do", "what would", "why",
            "explain", "describe", "tell me", "what's", "what is",
        ]

        let lowercased = question.lowercased()
        return chinesePatterns.contains { question.contains($0) }
            || englishPatterns.contains { lowercased.contains($0) }
    }
}
