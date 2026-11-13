import Foundation
import KitAgentTool
import ProviderAgentLoop
import ProviderConversation
import ProviderMessage
import ProviderToolManager

/// 把一段自包含任务委托给隐藏子会话里的子代理，只把结论带回父上下文。
///
/// 同步执行路径（#1313 Task 2）：
/// 1. 经 `SubagentConversationBridge` 创建继承父会话绑定/模型/自动化等级的子会话；
/// 2. 抑制子会话自动回复后插入任务消息，由本工具显式启动且只启动一次回合；
/// 3. 等待子回合终态，取最后一条助手消息作为结论，附用量摘要；
/// 4. 子回合的完整转录留在子会话里，绝不进入父会话历史。
///
/// 失败一律 `throw ToolExecutionError`，由 ToolExecutionManager 标记 isError。
public struct RunSubagentTool: SuperAgentTool, @unchecked Sendable {
    public static let toolName = "run_subagent"

    /// 回流到父上下文的结论字符上限；超出部分截断，避免撑爆父上下文。
    public static let conclusionCharacterLimit = 8_000

    public let name = Self.toolName

    private let conversations: any ConversationManaging
    private let messages: any MessageManaging
    private let agentLoop: any AgentLoopProviding
    private let toolManager: any ToolManagerProviding

    public init(
        conversations: any ConversationManaging,
        messages: any MessageManaging,
        agentLoop: any AgentLoopProviding,
        toolManager: any ToolManagerProviding
    ) {
        self.conversations = conversations
        self.messages = messages
        self.agentLoop = agentLoop
        self.toolManager = toolManager
    }

    public func description(for language: LanguagePreference) -> String {
        "Delegate a self-contained task to a subagent running in an isolated hidden conversation. Returns only the subagent's final conclusion plus a usage summary; the subagent's transcript never enters this conversation. The task prompt must be self-contained because the subagent cannot see this conversation's history."
    }

    public func inputSchema(for language: LanguagePreference) -> [String: Any] {
        [
            "type": "object",
            "properties": [
                "task": [
                    "type": "string",
                    "description": "The full task prompt for the subagent. Must be self-contained: the subagent cannot see this conversation's history.",
                ],
                "description": [
                    "type": "string",
                    "description": "A short 3-5 word label for the delegation, shown in the timeline.",
                ],
            ],
            "required": ["task"],
        ]
    }

    public func permissionRiskLevel(arguments: [String: ToolArgument]) -> CommandRiskLevel {
        .low
    }

    public func displayDescription(for arguments: [String: ToolArgument]) -> String {
        let label = Self.string(from: arguments, key: "description") ?? "task"
        return "Delegate to subagent: \(label)"
    }

    /// 无会话上下文的入口：子会话必须挂在父会话下，缺上下文时直接失败。
    public func execute(arguments: [String: ToolArgument]) async throws -> String {
        throw ToolExecutionError.executionFailed(
            toolName: Self.toolName,
            reason: "run_subagent requires a conversation context."
        )
    }

    public func executeResult(
        context: ToolExecutionContext,
        arguments: [String: ToolArgument]
    ) async throws -> ToolCallResult {
        try await run(context: context, arguments: arguments)
    }

    // MARK: - Core

    @MainActor
    private func run(
        context: ToolExecutionContext,
        arguments: [String: ToolArgument]
    ) async throws -> ToolCallResult {
        guard let task = Self.string(from: arguments, key: "task") else {
            throw ToolExecutionError.executionFailed(
                toolName: Self.toolName,
                reason: "Missing or empty task."
            )
        }
        let label = Self.string(from: arguments, key: "description") ?? "Subagent task"

        let bridge = SubagentConversationBridge(conversations: conversations)
        let childID = try await bridge.createChildConversation(
            parentID: context.conversationID,
            description: label
        )

        // 先抑制自动回复再插任务消息：回合由本工具显式启动，且只启动一次。
        agentLoop.setAutoReplySuppressed(true, for: childID)

        var childTurnID: UUID?
        let observer = agentLoop.addAgentLoopObserver { event in
            if case .started(let conversationID, let turnID) = event, conversationID == childID {
                childTurnID = turnID
            }
        }
        defer { observer.cancel() }

        messages.insertMessage(
            Message(conversationID: childID, role: .user, content: task),
            to: childID
        )

        let startedAt = Date()
        let outcome: AgentLoopOutcome
        do {
            outcome = try await agentLoop.runTurn(in: childID)
        } catch {
            throw ToolExecutionError.executionFailed(
                toolName: Self.toolName,
                reason: "Subagent turn failed: \(error.localizedDescription)"
            )
        }
        let duration = Date().timeIntervalSince(startedAt)

        switch outcome {
        case .completed:
            break
        case .failed(let reason):
            throw ToolExecutionError.executionFailed(
                toolName: Self.toolName,
                reason: "Subagent turn failed: \(reason)"
            )
        case .cancelled:
            throw ToolExecutionError.executionFailed(
                toolName: Self.toolName,
                reason: "Subagent turn failed: cancelled."
            )
        case .suspended:
            agentLoop.cancelTurn(in: childID)
            throw ToolExecutionError.executionFailed(
                toolName: Self.toolName,
                reason: "Subagent turn failed: suspended waiting for user input."
            )
        }

        guard let conclusion = messages.messages(for: childID)
            .last(where: { $0.role == .assistant })?.content,
            !conclusion.isEmpty
        else {
            throw ToolExecutionError.executionFailed(
                toolName: Self.toolName,
                reason: "Subagent turn failed: no conclusion produced."
            )
        }

        var toolUseCount = 0
        if let childTurnID {
            toolUseCount = await toolManager.toolCalls(for: childTurnID).count
        }

        return ToolCallResult(
            content: Self.formatConclusion(
                conclusion,
                toolUseCount: toolUseCount,
                duration: duration
            )
        )
    }

    /// 结论 + 截断标记 + 用量摘要。
    private static func formatConclusion(
        _ text: String,
        toolUseCount: Int,
        duration: TimeInterval
    ) -> String {
        var body = text
        if body.count > conclusionCharacterLimit {
            body = String(body.prefix(conclusionCharacterLimit)) + "\n[truncated]"
        }
        let seconds = String(format: "%.1f", duration)
        return body + "\n\n[subagent] tool calls: \(toolUseCount) · duration: \(seconds)s"
    }

    /// 读取字符串参数并去掉首尾空白；缺失或空白返回 nil。
    private static func string(from arguments: [String: ToolArgument], key: String) -> String? {
        guard let value = arguments[key]?.value as? String else { return nil }
        let trimmed = value.trimmingCharacters(in: .whitespacesAndNewlines)
        return trimmed.isEmpty ? nil : trimmed
    }
}