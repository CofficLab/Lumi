import Foundation
import KitAgentTool
import ProviderConversation

/// 询问用户工具（KernelCore 体系）。
///
/// 复刻自旧版 `Plugins/AskUserPlugin` 的 `AskUserTool`：让 LLM 可以向用户提问
/// 并等待回答。支持是/否确认、多选项选择和自由输入。
///
/// ## 工作流程（新版）
/// 1. LLM 调用 `ask_user` 工具（必须显式传 `mode`）；
/// 2. 工具 `execute` 返回结构化的 `AskUserPendingResponse` JSON；
/// 3. 工具覆盖 `executeResult` 返回 `ToolCallResult(awaitingUserResponse: true)`，
///    由 AgentLoop 检测后创建 suspension 并暂停回合；
/// 4. UI 渲染选择界面，用户点击选项；
/// 5. 调用 `AgentLoopProviding.resumeTurn(in:request:)` 恢复，用户回答作为
///    tool result 回传给 LLM 继续处理。
///
/// 说明：`executeResult` 必须作为协议要求由宿主调用（`SuperAgentTool` 已把
/// 它提升为协议要求，存在类型动态分派到本覆盖版本）。
public struct AskUserTool: SuperAgentTool, @unchecked Sendable {
    public static let toolName = "ask_user"

    public let name: String = Self.toolName

    private let conversations: (any ConversationManaging)?

    public init(conversations: (any ConversationManaging)? = nil) {
        self.conversations = conversations
    }

    public func description(for language: LanguagePreference) -> String {
        """
        Ask the user a question and wait for their response. Use when you need a user decision instead of assuming intent.

        FIRST choose a `mode`, then fill the other parameters to match it:
        - mode="yes_no": the question can be genuinely answered with 是 or 否. Do NOT pass options. Example: "继续构建?"
        - mode="choice": the answer must be one of a fixed set. You MUST pass a non-empty `options` array. Example: options=["Debug", "Release", "Profile"].
        - mode="free_text": the question is open-ended and cannot be answered by yes/no or a fixed set. Do NOT pass options. Example: "冲突如何处理?", "接下来怎么做?", "想用什么分支名?".

        CRITICAL — do NOT use mode="yes_no" for open-ended questions (anything asking how/why/what-next/which-plan). Those MUST use mode="free_text" (single answer) or mode="choice" (you supply the candidates). A yes/no dialog rendered for an open-ended question is a bug.
        """
    }

    public func inputSchema(for language: LanguagePreference) -> [String: Any] {
        [
            "type": "object",
            "properties": [
                "question": [
                    "type": "string",
                    "description": "Question to ask the user (e.g.: Should I continue?)",
                ],
                "mode": [
                    "type": "string",
                    "enum": ["yes_no", "choice", "free_text"],
                    "description": "REQUIRED interaction mode. yes_no = answerable with 是/否 (no options); choice = pick from a fixed set (must pass options); free_text = open-ended question (no options). Pick the mode that matches the question, not yes_no for everything.",
                ],
                "options": [
                    "type": "array",
                    "items": [
                        "type": "object",
                        "properties": [
                            "label": ["type": "string", "description": "Short button text; also the value returned as the user's answer."],
                            "description": ["type": "string", "description": "Optional longer explanation shown under the label."],
                        ],
                        "required": ["label"],
                    ],
                    "description": "Required when mode=\"choice\". Each item is {label, description?} (bare strings also accepted). Ignored for yes_no / free_text.",
                ],
            ],
            "required": ["question", "mode"],
        ]
    }

    public func permissionRiskLevel(arguments: [String: ToolArgument]) -> CommandRiskLevel {
        .safe
    }

    public func displayDescription(for arguments: [String: ToolArgument]) -> String {
        guard let question = Self.string(arguments, "question"),
              !question.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else {
            return "Ask the user"
        }
        return "向用户提问：\(question)"
    }

    public func execute(arguments: [String: ToolArgument]) async throws -> String {
        guard let question = Self.string(arguments, "question"),
              !question.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else {
            return Self.errorResult(message: LumiPluginLocalization.string("question is required and cannot be empty", bundle: .module))
        }

        // mode 是必填的强制函数：LLM 必须先声明意图。
        guard let mode = Self.resolvedMode(arguments) else {
            return Self.errorResult(
                message: "mode is required. Choose one of: yes_no (是/否), choice (pick from options), free_text (open-ended)."
            )
        }

        // mode=choice 必须带 options。
        let options = Self.resolvedOptions(arguments, mode: mode)
        if mode == "choice", options.isEmpty {
            return Self.errorResult(
                message: "mode=choice requires a non-empty options array. Pass options=[...] with the candidates, or switch to free_text."
            )
        }

        let payload = AskUserPendingResponse(
            toolCallId: "ask_user",
            question: question,
            options: options,
            mode: mode,
            conversationId: "",
            verbosity: "standard"
        )
        guard let data = try? JSONEncoder().encode(payload),
              let content = String(data: data, encoding: .utf8) else {
            return Self.errorResult(message: "Failed to encode ask_user payload")
        }
        return content
    }

    public func executeResult(arguments: [String: ToolArgument]) async throws -> ToolCallResult {
        let content = try await execute(arguments: arguments)
        guard let data = content.data(using: .utf8),
              let response = try? JSONDecoder().decode(AskUserPendingResponse.self, from: data),
              !response.question.isEmpty else {
            return ToolCallResult(content: content, isError: content.hasPrefix(Self.errorPrefix))
        }
        // 挂起：AgentLoop 检测 awaitingUserResponse 后创建 suspension 暂停回合。
        return ToolCallResult(
            content: content,
            isError: false,
            awaitingUserResponse: true,
            interactionState: .waiting
        )
    }

    // MARK: - Mode & Option Resolution

    private static let allowedModes: Set<String> = ["yes_no", "choice", "free_text"]

    private static let defaultOptions: [AskUserOption] = [
        AskUserOption(label: "是"),
        AskUserOption(label: "否"),
    ]

    private static let errorPrefix = "❌"

    static func resolvedMode(_ arguments: [String: ToolArgument]) -> String? {
        guard let raw = string(arguments, "mode") else { return nil }
        return allowedModes.contains(raw) ? raw : nil
    }

    static func resolvedOptions(_ arguments: [String: ToolArgument], mode: String) -> [AskUserOption] {
        switch mode {
        case "yes_no":
            return defaultOptions
        case "free_text":
            return []
        case "choice":
            return parseOptions(arguments["options"]?.value)
        default:
            return defaultOptions
        }
    }

    /// 宽容解析 options：对象（label/description）、裸字符串均可。
    static func parseOptions(_ value: Any?) -> [AskUserOption] {
        guard let array = value as? [Any] else { return [] }
        var result: [AskUserOption] = []
        for element in array {
            if let string = element as? String {
                if !string.isEmpty { result.append(AskUserOption(label: string)) }
            } else if let dict = element as? [String: Any] {
                let label = (dict["label"] as? String)
                    ?? (dict["description"] as? String)
                    ?? (dict["value"] as? String)
                    ?? (dict["text"] as? String)
                guard let label, !label.isEmpty else { continue }
                let description = dict["description"] as? String
                result.append(AskUserOption(label: label, description: description))
            }
        }
        return result
    }

    private static func string(_ arguments: [String: ToolArgument], _ key: String) -> String? {
        arguments[key]?.value as? String
    }

    static func errorResult(message: String) -> String {
        "\(errorPrefix) \(message)"
    }
}

/// AskUser 的单个候选项（复刻旧版模型）。
public struct AskUserOption: Codable, Equatable, Sendable, Identifiable, Hashable {
    public let label: String
    public let description: String?

    public init(label: String, description: String? = nil) {
        self.label = label
        self.description = description
    }

    public var id: String { label }

    public init(from decoder: Decoder) throws {
        if let container = try? decoder.container(keyedBy: CodingKeys.self) {
            self.label = try container.decode(String.self, forKey: .label)
            self.description = try container.decodeIfPresent(String.self, forKey: .description)
        } else {
            let container = try decoder.singleValueContainer()
            self.label = try container.decode(String.self)
            self.description = nil
        }
    }

    public func encode(to encoder: Encoder) throws {
        if let description {
            var container = encoder.container(keyedBy: CodingKeys.self)
            try container.encode(label, forKey: .label)
            try container.encode(description, forKey: .description)
        } else {
            var container = encoder.singleValueContainer()
            try container.encode(label)
        }
    }

    private enum CodingKeys: String, CodingKey {
        case label, description
    }
}

/// 等待用户响应的数据结构（复刻旧版模型）。
public struct AskUserPendingResponse: Codable, Equatable {
    public let toolCallId: String
    public let question: String
    public let options: [AskUserOption]
    public let mode: String?
    public let conversationId: String
    public let verbosity: String

    public init(
        toolCallId: String,
        question: String,
        options: [AskUserOption],
        mode: String?,
        conversationId: String,
        verbosity: String
    ) {
        self.toolCallId = toolCallId
        self.question = question
        self.options = options
        self.mode = mode
        self.conversationId = conversationId
        self.verbosity = verbosity
    }
}
