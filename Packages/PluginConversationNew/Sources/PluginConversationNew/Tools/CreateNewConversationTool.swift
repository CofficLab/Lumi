import Foundation
import KitAgentTool
import LumiLoggingKit
import os

/// 卡片 payload：工具返回给 UI 的结构化数据。
///
/// 编码为 JSON 代码块追加在 `ToolCallResult.content` 末尾，由
/// `NewConversationRowRenderer` 解码并渲染成可点击卡片。
struct NewConversationSuggestion: Codable, Equatable {
    /// 新对话 ID。
    let conversationID: UUID
    /// 新对话标题。
    let title: String
    /// 用户点击后自动发送的首条消息（即 LLM 传入的 task）。
    let starter: String
}

/// 「换个话题聊」工具：让 LLM 建议用户在当前对话之外另开一个新对话。
///
/// 设计要点见 README「回合内只备料，不在回合内切换」一节：工具在回合中只创建
/// 对话并回传结构化 payload，**不修改 `selectedConversationID`**；切换与发送
/// 由用户点击卡片后触发，发生在回合之外。
public struct CreateNewConversationTool: SuperAgentTool, SuperLog, @unchecked Sendable {
    nonisolated static let logger = Logger(
        subsystem: "com.coffic.lumi.plugin.new-conversation",
        category: "CreateNewConversationTool"
    )

    /// Agent 调用的工具名。
    public static let toolName = "create_new_conversation"

    public let name: String = Self.toolName

    private let conversations: NewChatCapability?

    /// 依赖能力协议为插件内部类型，故初始化器同为 internal。
    init(conversations: NewChatCapability? = nil) {
        self.conversations = conversations
    }

    public func description(for language: LanguagePreference) -> String {
        """
        Prepare a separate conversation for a task that is unrelated to the current topic, \
        and offer the user a one-click button to switch to it.

        Use this ONLY when you notice a distinct task that is substantially different from what \
        the current conversation is about (for example: the user asks about a feature while you are \
        debugging a build failure). This keeps each conversation's context focused.

        Do NOT use this when: the task continues the current topic, the task is a small follow-up \
        question, or you merely want to run a quick sub-task.

        The `task` argument must be a complete, self-contained instruction: it is sent verbatim as \
        the first user message of the new conversation. If the new task depends on conclusions from \
        the current conversation, include those conclusions directly in `task`.

        At most one call per turn. After calling this tool, keep answering the user's original \
        question in the current conversation.
        """
    }

    public func inputSchema(for language: LanguagePreference) -> [String: Any] {
        [
            "type": "object",
            "properties": [
                "task": [
                    "type": "string",
                    "description": "A complete, self-contained instruction describing what the new conversation should do. Sent verbatim as its first user message. If it depends on conclusions from the current conversation, include those conclusions here.",
                ],
                "title": [
                    "type": "string",
                    "description": "Optional short title for the new conversation. Defaults to a title derived from `task`.",
                ],
            ],
            "required": ["task"],
        ]
    }

    /// 只创建一个空对话，不修改任何文件或外部状态。
    public func permissionRiskLevel(arguments: [String: ToolArgument]) -> CommandRiskLevel {
        .low
    }

    public func displayDescription(for arguments: [String: ToolArgument]) -> String {
        let task = Self.taskArgument(from: arguments)
        let title = Self.titleArgument(from: arguments)
        let subject = title ?? task.map(Self.derivedTitle(from:)) ?? ""
        guard !subject.isEmpty else {
            return pluginLocalization.string("Prepare new conversation")
        }
        return "\(pluginLocalization.string("New conversation")): \(subject)"
    }

    public func execute(arguments: [String: ToolArgument]) async throws -> String {
        guard let task = Self.taskArgument(from: arguments) else {
            Self.logger.error("\(Self.t)create_new_conversation called without a non-empty 'task' argument")
            throw ToolExecutionError.executionFailed(
                toolName: name,
                reason: "Missing 'task' argument"
            )
        }

        // NewChatCapability 是 MainActor 隔离；工具是 Sendable，
        // 经 MainActor.run 跳回主线程访问。
        let outcome = await MainActor.run { () -> Result<NewConversationSuggestion, Error> in
            guard let conversations else {
                Self.logger.error("\(Self.t)create_new_conversation cannot proceed because the conversation capability is unavailable")
                return .failure(NewChatCapabilityError.providerUnavailable)
            }

            // 记录调用前的选中态：创建顶层对话会把它抢到新对话上。
            let previousSelection = conversations.selectedConversationID

            do {
                let title = Self.titleArgument(from: arguments) ?? Self.derivedTitle(from: task)
                let newID = try conversations.createTopLevelConversation(
                    title: title,
                    projectPath: conversations.currentProjectPath,
                    modelID: conversations.currentModelID
                )
                // 立刻恢复选中态：用户在当前对话里可能正在输入，不能被甩进空对话。
                conversations.restoreSelection(to: previousSelection)
                Self.logger.info("\(Self.t)prepared new conversation id=\(newID.uuidString, privacy: .public), restored selection to \(previousSelection?.uuidString ?? "nil", privacy: .public)")
                return .success(NewConversationSuggestion(
                    conversationID: newID,
                    title: title,
                    starter: task
                ))
            } catch {
                // 失败路径同样要恢复选中态，避免把用户留在新建的空对话里。
                conversations.restoreSelection(to: previousSelection)
                Self.logger.error("\(Self.t)failed to create new conversation: \(error.localizedDescription, privacy: .public)")
                return .failure(error)
            }
        }

        switch outcome {
        case .success(let suggestion):
            return Self.resultText(for: suggestion)
        case .failure:
            return """
            ## New Conversation Not Prepared ❌

            **Status**: The conversation service is unavailable. \
            Keep working on the current task in this conversation.
            """
        }
    }

    // MARK: - Arguments

    /// 读取并规范化 `task` 参数；空白视为缺省。
    static func taskArgument(from arguments: [String: ToolArgument]) -> String? {
        (arguments["task"]?.value as? String)?
            .trimmingCharacters(in: .whitespacesAndNewlines)
            .nilIfEmpty
    }

    /// 读取并规范化 `title` 参数；缺省或空白返回 nil（交由调用方推导）。
    static func titleArgument(from arguments: [String: ToolArgument]) -> String? {
        (arguments["title"]?.value as? String)?
            .trimmingCharacters(in: .whitespacesAndNewlines)
            .nilIfEmpty
    }

    /// 由 task 推导标题：取首个句子，长度上限 48 字符。
    static func derivedTitle(from task: String) -> String {
        let firstSentence = task
            .split(whereSeparator: { ".!?\n".contains($0) })
            .first
            .map(String.init)?
            .trimmingCharacters(in: .whitespacesAndNewlines) ?? task
        let base = firstSentence.isEmpty ? task : firstSentence
        guard base.count > Self.maxDerivedTitleLength else { return base }
        return String(base.prefix(Self.maxDerivedTitleLength)).trimmingCharacters(in: .whitespacesAndNewlines)
    }

    /// 由 task 推导标题时的长度上限。
    static let maxDerivedTitleLength = 48

    // MARK: - Result

    /// 构造工具返回文本：人类可读正文 + 末尾 JSON 代码块。
    ///
    /// 正文供 LLM 直接理解；JSON 块供 `NewConversationRowRenderer` 解码成卡片。
    /// 无法编码时静默回退，保证 LLM 始终拿到正文。
    static func resultText(for suggestion: NewConversationSuggestion) -> String {
        """
        ## New Conversation Prepared ✅

        A separate conversation has been prepared for an unrelated task, and the user now sees a \
        button in this conversation to open it.

        **Suggested title**: \(suggestion.title)

        Nothing has been sent yet. Keep answering the user's original question here; the new \
        task only starts if the user clicks the button.

        \(structuredPayload(suggestion))
        """
    }

    /// 把结构化 payload 编码为 JSON 代码块追加到返回内容末尾。
    static func structuredPayload(_ suggestion: NewConversationSuggestion) -> String {
        guard let data = try? JSONEncoder().encode(suggestion),
              let json = String(data: data, encoding: .utf8) else {
            return ""
        }
        return "```json\n\(json)\n```"
    }
}

private extension String {
    /// 空白字符串视为缺省值。
    var nilIfEmpty: String? { isEmpty ? nil : self }
}
