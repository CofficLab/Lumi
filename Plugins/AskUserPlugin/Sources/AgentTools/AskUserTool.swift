import Foundation
import LumiKernel
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
/// 3. `AgentTurnRunner` 执行工具后检测到该标记，把 turn 标记为
///    `.awaitingUserResponse` 并暂停循环
/// 4. UI 渲染选择界面（`AskUserRowRenderer`），用户点击选项
/// 5. `AskUserBridge` 发送 `.lumiAskUserDidAnswer` 通知，
///    `AskUserAnswerObserver` 监听后回写答案并恢复 Agent 循环
/// 6. LLM 收到用户的回答作为 tool result，继续处理
public struct AskUserTool: LumiAgentTool, SuperLog {
    public nonisolated static let emoji = "❓"
    public nonisolated static let verbose: Bool = true
    public nonisolated static let logger = Logger(subsystem: "com.coffic.lumi", category: "tool.ask-user")

    /// 工具名称，用于在整个插件中统一引用
    public static let name = "ask_user"

    /// 工具返回值中用于标记等待用户回答的前缀。
    ///
    /// `AgentTurnRunner` 检测到此前缀后会以 `.awaitingUserResponse` 结束 turn。
    public static let pendingPrefix = LumiAskUserMarkers.pendingPrefix

    public static let info = LumiAgentToolInfo(
        id: name,
        displayName: "Ask User",
        description: "Ask the user a question and wait for their response. Supports yes/no confirmation, multiple choice, and free text input. Use it whenever a user decision is required instead of assuming user intent."
    )

    public init() {}

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
                    "description": .string("List of options for user to choose (e.g.: [\"OptionA\", \"OptionB\"]), defaults to Yes/No. Must be provided when the question is not a simple yes/no confirmation."),
                ]),
                "allow_free_input": .object([
                    "type": .string("boolean"),
                    "description": .string("Whether to allow free text input (default false, only allow selecting preset options)"),
                ]),
            ]),
            "required": .array([.string("question")]),
        ])
    }

    public func displayDescription(arguments: [String: LumiJSONValue]) -> String {
        if let question = arguments.string("question") {
            return "询问: \(question.prefix(50))"
        }
        return "询问用户"
    }

    public func riskLevel(
        arguments: [String: LumiJSONValue],
        context: LumiToolExecutionContext?
    ) -> LumiCommandRiskLevel {
        .low
    }

    public func execute(arguments: [String: LumiJSONValue], context: LumiToolExecutionContext) async throws -> String {
        try context.checkCancellation()

        guard let question = arguments.string("question"), !question.isEmpty else {
            return Self.errorResult(message: "question is required and cannot be empty")
        }

        // 检测是否是多选场景但没传 options
        let hasOptions = arguments.stringArray("options") != nil
        if !hasOptions && Self.looksLikeMultipleChoice(question) {
            return Self.errorResult(
                message: "Your question appears to require multiple options, but the options parameter was not provided. Please provide an options list."
            )
        }

        let options = Self.resolvedOptions(arguments)
        let allowFreeInput = Self.resolvedAllowFreeInput(arguments)

        logInvocation(
            question: question,
            options: options,
            allowFreeInput: allowFreeInput
        )

        let pendingResponse = Self.buildPendingResponse(
            context: context,
            question: question,
            options: options,
            allowFreeInput: allowFreeInput
        )

        let payload = try Self.encodePendingPayload(pendingResponse)
        return "\(Self.pendingPrefix)\n\(payload)"
    }

    /// 解析并归一化 `options` 参数。
    ///
    /// 仅当 `options` 是非空字符串数组时才使用；
    /// 其他情况（缺失、非数组、为空数组）都回退到 `Self.defaultOptions`。
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

    /// 构建 `AskUserPendingResponse`，集中所有字段归一化逻辑（verbosity 默认值等）。
    static func buildPendingResponse(
        context: LumiToolExecutionContext,
        question: String,
        options: [String],
        allowFreeInput: Bool
    ) -> AskUserPendingResponse {
        AskUserPendingResponse(
            toolCallId: context.toolCallID,
            question: question,
            options: options,
            allowFreeInput: allowFreeInput,
            conversationId: context.conversationID.uuidString,
            verbosity: context.verbosity ?? LumiResponseVerbosity.defaultVerbosity.rawValue
        )
    }

    /// 将 `AskUserPendingResponse` 编码为 pretty-printed JSON 字符串。
    ///
    /// 与 `AskUserPendingResponse.init` + `JSONEncoder` 路径完全等价，
    /// 单独暴露便于精确断言和单元测试。
    static func encodePendingPayload(_ response: AskUserPendingResponse) throws -> String {
        let data = try jsonEncoder.encode(response)
        return String(decoding: data, as: UTF8.self)
    }

    /// 将 `AskUserErrorResponse` 编码为 JSON 字符串。
    static func encodeErrorPayload(_ response: AskUserErrorResponse) throws -> String {
        let data = try jsonEncoder.encode(response)
        return String(decoding: data, as: UTF8.self)
    }

    /// 输出 verbose 日志（仅在 `Self.verbose == true` 时）。
    ///
    /// 提取为单独方法便于子类覆盖以注入测试断言。
    func logInvocation(question: String, options: [String], allowFreeInput: Bool) {
        guard Self.verbose else { return }
        Self.logger.info(
            "\(Self.t) AskUser tool called: \(question) options=\(options) freeInput=\(allowFreeInput)"
        )
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
}

// MARK: - Multiple Choice Detection

extension AskUserTool {
    /// 检测 question 是否看起来像多选场景
    ///
    /// 当 question 包含选择类关键词（如"哪个"、"哪些"、"选择"等）时返回 true。
    /// 用于在 options 缺失时给出纠错提示，避免默默回退到是/否。
    static func looksLikeMultipleChoice(_ question: String) -> Bool {
        let chineseKeywords = ["哪个", "哪些", "哪一个", "哪一", "选择", "方案", "选项", "模式"]
        let englishKeywords = ["which", "choose", "select", "option", "pick"]

        let lowercased = question.lowercased()
        return chineseKeywords.contains { question.contains($0) }
            || englishKeywords.contains { lowercased.contains($0) }
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
    public let verbosity: String

    public init(
        toolCallId: String,
        question: String,
        options: [String],
        allowFreeInput: Bool,
        conversationId: String,
        verbosity: String
    ) {
        self.toolCallId = toolCallId
        self.question = question
        self.options = options
        self.allowFreeInput = allowFreeInput
        self.conversationId = conversationId
        self.verbosity = verbosity
    }
}

/// 错误响应数据结构
public struct AskUserErrorResponse: Codable {
    public let error: String
}
