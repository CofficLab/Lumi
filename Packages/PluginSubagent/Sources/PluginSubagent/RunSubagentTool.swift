import Foundation
import KitAgentTool
import PluginToolManager
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
/// 并行与防递归（#1313 Task 3）：声明 `.parallelReadOnly`，同一回合的
/// 多个委托可由调度器并发执行；子会话工具表经 `SubagentToolPolicy`
/// 过滤为只读且不含本工具，执行入口也拒绝来自子会话的调用。
/// 取消父 Job 时，`runTurn` 的等待器自带取消传播，会级联取消子回合。
///
/// 后台模式（#1313 Task 5）：`run_in_background` 为 true 时立即返回任务 ID，
/// 子回合在非结构化 Task 里跑——父回合取消不得级联到它。结论写进登记表
/// 的输出文件，复用 #1307 的完成通知链路（空闲唤醒 / 忙时排空）送回父会话。
///
/// 失败一律 `throw ToolExecutionError`，由 ToolExecutionManager 标记 isError。
public struct RunSubagentTool: SuperAgentTool, @unchecked Sendable {
    public static let toolName = SubagentToolPolicy.delegationToolName

    /// 回流到父上下文的结论字符硬上限；超出部分截断，避免撑爆父上下文。
    /// 模型可经 `max_characters` 向下收紧，但不得突破该上限。
    public static let conclusionCharacterLimit = 8_000

    /// `max_characters` 的下限：再小也要保住一段可读结论。
    public static let conclusionCharacterFloor = 500

    public let name = Self.toolName

    /// 委托本身不产生副作用（子会话隔离），允许同一回合内并发派发。
    public var executionCapability: ToolExecutionCapability { .parallelReadOnly }

    private let conversations: any ConversationManaging
    private let messages: any MessageManaging
    private let agentLoop: any AgentLoopProviding
    private let toolManager: any ToolManagerProviding

    /// 后台任务登记表（#1307 机制）；未装配时后台模式显式失败。
    private let backgroundRegistryProvider: @MainActor @Sendable () -> BackgroundTaskRegistry?

    /// 后台任务登记成功后的回调：插件用它记录 任务 ID → 子会话，
    /// 以便显式停止时级联取消子回合。
    private let onBackgroundTaskStarted: (@MainActor (String, UUID) -> Void)?

    public init(
        conversations: any ConversationManaging,
        messages: any MessageManaging,
        agentLoop: any AgentLoopProviding,
        toolManager: any ToolManagerProviding,
        backgroundRegistryProvider: @escaping @MainActor @Sendable () -> BackgroundTaskRegistry? = { nil },
        onBackgroundTaskStarted: (@MainActor (String, UUID) -> Void)? = nil
    ) {
        self.conversations = conversations
        self.messages = messages
        self.agentLoop = agentLoop
        self.toolManager = toolManager
        self.backgroundRegistryProvider = backgroundRegistryProvider
        self.onBackgroundTaskStarted = onBackgroundTaskStarted
    }

    public func description(for language: LanguagePreference) -> String {
        """
        Delegate a self-contained task to a subagent running in an isolated hidden conversation. \
        Returns only the subagent's final conclusion plus a usage summary; the subagent's transcript \
        never enters this conversation.

        When to delegate: independent work that can run in parallel (dispatch several run_subagent \
        calls in one message), or reading across many files / broad research where only the \
        conclusion matters. When NOT to delegate: single-fact lookups or one-file reads — search \
        directly instead; and never duplicate work already delegated.

        The task prompt must be self-contained: the subagent cannot see this conversation's history, \
        so include all needed context (paths, constraints, expected output). Ask for conclusions, \
        not file dumps. The subagent only has read-only tools and cannot edit files or run \
        side-effecting commands.

        For long-running tasks, set run_in_background to true: the call returns immediately with a \
        background task ID, and you are notified with the conclusion when the subagent finishes. \
        Keep working on other things meanwhile; do not poll or re-dispatch the same task.
        """
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
                "max_characters": [
                    "type": "integer",
                    "minimum": Self.conclusionCharacterFloor,
                    "maximum": Self.conclusionCharacterLimit,
                    "description": "Maximum characters of the returned conclusion; defaults to 8000. Values outside 500-8000 are clamped.",
                ],
                "run_in_background": [
                    "type": "boolean",
                    "description": "Optional. Run the subagent in the background: returns immediately with a task ID, and you are notified with the conclusion when it finishes. Defaults to false.",
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
        // JSON 数字统一桥接为 Double，直接 Int(...) 越界会陷阱崩溃；
        // toolInt 安全转换并钳制到 schema 声明的区间，非法值回退默认。
        let conclusionLimit = arguments.toolInt(
            "max_characters",
            clampedTo: Self.conclusionCharacterFloor...Self.conclusionCharacterLimit,
            default: Self.conclusionCharacterLimit
        )

        // 防递归兜底：子会话工具表虽已过滤掉本工具，执行入口仍须拒绝
        // 来自子会话的调用，杜绝任何路径下的嵌套委托。
        if await conversations.fetchConversation(id: context.conversationID)?.parentConversationID != nil {
            throw ToolExecutionError.executionFailed(
                toolName: Self.toolName,
                reason: "run_subagent cannot be called from a subagent conversation (recursion is not allowed)."
            )
        }

        if (arguments["run_in_background"]?.value as? Bool) == true {
            return try await runInBackground(
                context: context,
                task: task,
                label: label,
                conclusionLimit: conclusionLimit
            )
        }

        let bridge = SubagentConversationBridge(conversations: conversations)
        let childID = try await bridge.createChildConversation(
            parentID: context.conversationID,
            description: label
        )
        insertTimelineCard(context: context, label: label, childID: childID)
        let conclusion = try await runChildTurn(
            childID: childID,
            task: task,
            conclusionLimit: conclusionLimit
        )
        return ToolCallResult(content: conclusion)
    }

    /// 后台路径：登记进程内任务后立即返回，子回合在非结构化 Task 里跑完。
    ///
    /// 非结构化 Task 不是父回合任务的子任务：取消父回合不会级联到这里，
    /// 后台子代理因此跨回合存活。结论写进登记表输出文件，完成事件经
    /// #1307 的协调器变成父会话的通知（空闲唤醒 / 忙时排空）。
    @MainActor
    private func runInBackground(
        context: ToolExecutionContext,
        task: String,
        label: String,
        conclusionLimit: Int
    ) async throws -> ToolCallResult {
        guard let registry = backgroundRegistryProvider() else {
            throw ToolExecutionError.executionFailed(
                toolName: Self.toolName,
                reason: "Background execution is unavailable: no background task registry is configured."
            )
        }

        let bridge = SubagentConversationBridge(conversations: conversations)
        let childID = try await bridge.createChildConversation(
            parentID: context.conversationID,
            description: label
        )
        insertTimelineCard(context: context, label: label, childID: childID)
        let taskID = await registry.allocateTaskID()
        let record = await registry.adoptInProcess(
            taskID: taskID,
            conversationID: context.conversationID,
            command: "run_subagent: \(label)"
        )
        onBackgroundTaskStarted?(taskID, childID)

        Task { @MainActor [weak registry] in
            guard let registry else { return }
            let text: String
            let exitCode: Int32
            do {
                text = try await self.runChildTurn(
                    childID: childID,
                    task: task,
                    conclusionLimit: conclusionLimit
                )
                exitCode = 0
            } catch {
                text = "Subagent task failed: \(error.localizedDescription)"
                exitCode = 1
            }
            await registry.appendOutput(taskID: taskID, text: text)
            // 显式停止已把状态改成 .stopped 时，这里的状态守卫会挡住
            // 第二次完成事件——通知恰好一次。
            await registry.finishInProcess(taskID: taskID, exitCode: exitCode)
        }

        return ToolCallResult(
            content: """
            Subagent is running in the background.
            Background task ID: \(record.id)
            Output file: \(record.outputPath)
            The subagent keeps running; you will be notified when it completes.
            To check interim output, use read_file on the output file path.
            """
        )
    }

    /// 派发即插入时间线卡片（#1313 Task 6）：只给人看，不进 LLM 上下文。
    ///
    /// 卡片载荷只存标识；状态、工具数与耗时由卡片视图从工具管理器实时读取，
    /// 失败/取消的委托同样留下卡片，Job 终态即卡片终态。
    @MainActor
    private func insertTimelineCard(
        context: ToolExecutionContext,
        label: String,
        childID: UUID
    ) {
        let payload = SubagentTimeline.Payload(
            label: label,
            parentConversationID: context.conversationID,
            childConversationID: childID,
            jobID: context.jobID
        )
        messages.insertMessage(
            SubagentTimeline.message(
                conversationID: context.conversationID,
                turnID: context.turnID,
                payload: payload
            ),
            to: context.conversationID
        )
    }

    /// 在子会话里跑完一个回合并返回格式化结论；同步与后台路径共用。
    @MainActor
    private func runChildTurn(
        childID: UUID,
        task: String,
        conclusionLimit: Int
    ) async throws -> String {
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

        return Self.formatConclusion(
            conclusion,
            toolUseCount: toolUseCount,
            duration: duration,
            characterLimit: conclusionLimit
        )
    }

    /// 结论 + 截断标记 + 用量摘要。
    private static func formatConclusion(
        _ text: String,
        toolUseCount: Int,
        duration: TimeInterval,
        characterLimit: Int
    ) -> String {
        var body = text
        if body.count > characterLimit {
            body = String(body.prefix(characterLimit)) + "\n[truncated]"
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