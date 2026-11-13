import Foundation
import KitAgentTool
import ProviderAgentLoop
import ProviderLifecycleHooks
import ProviderMessage
import Testing
@testable import PluginToolManager

/// 后台任务完成通知的投递契约。
///
/// 核心约定：
/// - 空闲时插入 `role == .user` 消息 → `MessageObserver` 起回合 → 模型被唤醒
/// - 忙时入队，由 `turnFinished` 排空
/// - 通知**恰好一次**（重复的完成事件不重复投递）
/// - `isAutoReplySuppressed` 期间暂存，抑制解除后才投递
@Suite("BackgroundTaskNotification")
@MainActor
struct BackgroundTaskNotificationTests {

    // MARK: - 空闲路径

    @Test("空闲时插入 user 消息唤醒模型")
    func idleConversationGetsUserMessage() async throws {
        let conversationID = UUID()
        let agentLoop = NotificationTestAgentLoop()
        let messages = NotificationTestMessages()
        let coordinator = BackgroundTaskNotificationCoordinator(
            agentLoop: agentLoop,
            messages: messages,
            registry: nil
        )

        coordinator.handle(makeRecord(conversationID: conversationID))
        await settle()

        let inserted = messages.insertedMessages
        #expect(inserted.count == 1)
        #expect(inserted.first?.role == .user)
        #expect(inserted.first?.conversationID == conversationID)
        #expect(inserted.first?.content.contains("task-1") == true)
        #expect(inserted.first?.content.contains("/tmp/task-1.log") == true)
    }

    @Test("通知消息带 metadata 供渲染器识别")
    func notificationCarriesRendererMetadata() async throws {
        let agentLoop = NotificationTestAgentLoop()
        let messages = NotificationTestMessages()
        let coordinator = BackgroundTaskNotificationCoordinator(
            agentLoop: agentLoop,
            messages: messages,
            registry: nil
        )

        coordinator.handle(makeRecord(conversationID: UUID()))
        await settle()

        let metadata = messages.insertedMessages.first?.metadata
        #expect(metadata?[BackgroundTaskNotification.metadataKey] == "1")
        #expect(metadata?[BackgroundTaskNotification.taskIDKey] == "task-1")
        #expect(metadata?[BackgroundTaskNotification.statusKey] == BackgroundTaskStatus.completed.rawValue)
        #expect(metadata?[BackgroundTaskNotification.exitCodeKey] == "0")
        #expect(metadata?[BackgroundTaskNotification.outputPathKey] == "/tmp/task-1.log")
    }

    // MARK: - 恰好一次

    @Test("同一任务的完成事件只投递一次")
    func duplicateCompletionEventsDeliverOnlyOnce() async throws {
        let agentLoop = NotificationTestAgentLoop()
        let messages = NotificationTestMessages()
        let coordinator = BackgroundTaskNotificationCoordinator(
            agentLoop: agentLoop,
            messages: messages,
            registry: nil
        )

        let record = makeRecord(conversationID: UUID())
        coordinator.handle(record)
        coordinator.handle(record)
        coordinator.handle(record)
        await settle()

        #expect(messages.insertedMessages.count == 1)
    }

    // MARK: - 忙时排队

    @Test("会话正忙时通知入队而不是直接插入")
    func busyConversationQueuesNotification() async throws {
        let conversationID = UUID()
        let agentLoop = NotificationTestAgentLoop()
        agentLoop.setRunning(true, for: conversationID)
        let messages = NotificationTestMessages()
        let coordinator = BackgroundTaskNotificationCoordinator(
            agentLoop: agentLoop,
            messages: messages,
            registry: nil
        )

        coordinator.handle(makeRecord(conversationID: conversationID))
        await settle()

        #expect(messages.insertedMessages.isEmpty)
        #expect(coordinator.pendingNotificationCount == 1)
    }

    @Test("回合结束后排队的通知被排空")
    func turnFinishedDrainsQueuedNotification() async throws {
        let conversationID = UUID()
        let agentLoop = NotificationTestAgentLoop()
        agentLoop.setRunning(true, for: conversationID)
        let messages = NotificationTestMessages()
        let coordinator = BackgroundTaskNotificationCoordinator(
            agentLoop: agentLoop,
            messages: messages,
            registry: nil
        )

        coordinator.handle(makeRecord(conversationID: conversationID))
        await settle()
        #expect(messages.insertedMessages.isEmpty)

        // 回合结束：会话变为空闲，通知排空。
        agentLoop.setRunning(false, for: conversationID)
        coordinator.handleTurnFinished(conversationID: conversationID)
        await settle()

        #expect(messages.insertedMessages.count == 1)
        #expect(messages.insertedMessages.first?.role == .user)
        #expect(coordinator.pendingNotificationCount == 0)
    }

    @Test("忙时两个任务完成都会被送达")
    func twoCompletionsWhileBusyBothDelivered() async throws {
        let conversationID = UUID()
        let agentLoop = NotificationTestAgentLoop()
        agentLoop.setRunning(true, for: conversationID)
        let messages = NotificationTestMessages()
        let coordinator = BackgroundTaskNotificationCoordinator(
            agentLoop: agentLoop,
            messages: messages,
            registry: nil
        )

        coordinator.handle(makeRecord(conversationID: conversationID, taskID: "task-a"))
        coordinator.handle(makeRecord(conversationID: conversationID, taskID: "task-b"))
        await settle()
        #expect(messages.insertedMessages.isEmpty)

        agentLoop.setRunning(false, for: conversationID)
        coordinator.handleTurnFinished(conversationID: conversationID)
        await settle()

        #expect(messages.insertedMessages.count == 2)
        let contents = messages.insertedMessages.map(\.content)
        #expect(contents.contains { $0.contains("task-a") })
        #expect(contents.contains { $0.contains("task-b") })
    }

    // MARK: - 抑制

    @Test("自动回复被抑制时通知被暂存而不是丢弃")
    func suppressedConversationHoldsNotification() async throws {
        let conversationID = UUID()
        let agentLoop = NotificationTestAgentLoop()
        agentLoop.setAutoReplySuppressed(true, for: conversationID)
        let messages = NotificationTestMessages()
        let coordinator = BackgroundTaskNotificationCoordinator(
            agentLoop: agentLoop,
            messages: messages,
            registry: nil
        )

        coordinator.handle(makeRecord(conversationID: conversationID))
        await settle()

        #expect(messages.insertedMessages.isEmpty)
        #expect(coordinator.pendingNotificationCount == 1)
    }

    @Test("抑制解除后暂存的通知被投递")
    func suppressedNotificationDeliveredAfterSuppressionEnds() async throws {
        let conversationID = UUID()
        let agentLoop = NotificationTestAgentLoop()
        agentLoop.setAutoReplySuppressed(true, for: conversationID)
        let messages = NotificationTestMessages()
        let coordinator = BackgroundTaskNotificationCoordinator(
            agentLoop: agentLoop,
            messages: messages,
            registry: nil
        )

        coordinator.handle(makeRecord(conversationID: conversationID))
        await settle()
        #expect(messages.insertedMessages.isEmpty)

        agentLoop.setAutoReplySuppressed(false, for: conversationID)
        coordinator.handleTurnFinished(conversationID: conversationID)
        await settle()

        #expect(messages.insertedMessages.count == 1)
    }

    // MARK: - 文案

    @Test("失败任务的通知写明退出码")
    func failedNotificationIncludesExitCode() {
        let message = BackgroundTaskNotification.message(
            conversationID: UUID(),
            taskID: "task-9",
            status: .failed,
            exitCode: 3,
            outputPath: "/tmp/task-9.log",
            tailExcerpt: "boom",
            isSubagentTask: false
        )
        #expect(message.content.contains("task-9"))
        #expect(message.content.contains("failed"))
        #expect(message.content.contains("Exit code: 3"))
        #expect(message.content.contains("boom"))
        #expect(message.content.contains("read_file"))
    }

    @Test("子代理任务的完成通知直接给出结论并要求转述")
    func subagentNotificationCarriesConclusionWithoutPollingHint() {
        let conclusion = String(repeating: "结论", count: 3_000)
        let message = BackgroundTaskNotification.message(
            conversationID: UUID(),
            taskID: "task-sub",
            status: .completed,
            exitCode: 0,
            outputPath: "/tmp/task-sub.log",
            tailExcerpt: conclusion,
            isSubagentTask: true
        )
        #expect(message.content.contains("Subagent conclusion:"))
        #expect(message.content.contains(conclusion))
        #expect(message.content.contains("Relay the conclusion"))
        #expect(!message.content.contains("read_file"))
        #expect(!message.content.contains("Last output:"))
    }

    @Test("后台子代理的完成通知带完整结论而不是 2000 字截断")
    func subagentNotificationTailIsNotTruncated() async throws {
        let directory = FileManager.default.temporaryDirectory
            .appendingPathComponent("LumiSubagentNotification-\(UUID())")
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: directory) }

        let conversationID = UUID()
        let agentLoop = NotificationTestAgentLoop()
        let messages = NotificationTestMessages()
        let registry = BackgroundTaskRegistry(rootDirectory: directory)
        let coordinator = BackgroundTaskNotificationCoordinator(
            agentLoop: agentLoop,
            messages: messages,
            registry: registry
        )
        let conclusion = String(repeating: "x", count: 8_000)
        let taskID = await registry.allocateTaskID()
        _ = await registry.adoptInProcess(
            taskID: taskID,
            conversationID: conversationID,
            command: "run_subagent: research"
        )
        await registry.appendOutput(taskID: taskID, text: conclusion)
        await registry.finishInProcess(taskID: taskID, exitCode: 0)
        let record = try #require(await registry.task(for: taskID))

        coordinator.handle(record)
        await settle()

        let content = try #require(messages.insertedMessages.first?.content)
        #expect(content.contains(conclusion))
        #expect(content.contains("Subagent conclusion:"))
    }
}

// MARK: - Helpers

private func makeRecord(
    conversationID: UUID,
    taskID: String = "task-1"
) -> BackgroundTaskRecord {
    BackgroundTaskRecord(
        id: taskID,
        conversationID: conversationID,
        command: "swift build",
        outputPath: "/tmp/\(taskID).log",
        processIdentifier: 4242,
        startedAt: Date(),
        status: .completed,
        exitCode: 0,
        finishedAt: Date()
    )
}

/// 让挂起的 Task 有机会跑完。
private func settle() async {
    for _ in 0..<5 {
        await Task.yield()
        try? await Task.sleep(nanoseconds: 10_000_000)
    }
}

/// 只实现协调器用到的最小 AgentLoop 能力。
@MainActor
private final class NotificationTestAgentLoop: AgentLoopProviding {
    private var running: Set<UUID> = []
    private var suppressed: Set<UUID> = []
    private var turnCounter = 0

    func setRunning(_ isRunning: Bool, for conversationID: UUID) {
        if isRunning {
            running.insert(conversationID)
        } else {
            running.remove(conversationID)
        }
    }

    func setAutoReplySuppressed(_ suppressed: Bool, for conversationID: UUID) {
        if suppressed {
            self.suppressed.insert(conversationID)
        } else {
            self.suppressed.remove(conversationID)
        }
    }

    func isAutoReplySuppressed(for conversationID: UUID) -> Bool {
        suppressed.contains(conversationID)
    }

    func isRunning(for conversationID: UUID) -> Bool {
        running.contains(conversationID)
    }

    func runTurn(in conversationID: UUID) async throws -> AgentLoopOutcome {
        turnCounter += 1
        return .completed
    }

    func resumeTurn(in conversationID: UUID, request: AgentTurnResumeRequest) async throws -> AgentLoopOutcome {
        .completed
    }

    func cancelTurn(in conversationID: UUID) {}

    func state(for conversationID: UUID) -> AgentLoopState {
        running.contains(conversationID) ? .running : .idle
    }

    func suspension(for conversationID: UUID) -> AgentLoopSuspension? { nil }

    func lastFailure(for conversationID: UUID) -> AgentLoopFailure? { nil }

    func currentTurnID(for conversationID: UUID) -> UUID? { nil }

    func setLifecycleHooks(_ hooks: (any LifecycleHooksProviding)?) {}
}

/// 记录插入消息的最小 MessageManaging 实现。
@MainActor
private final class NotificationTestMessages: MessageManaging {
    private(set) var insertedMessages: [Message] = []

    func insertMessage(_ message: Message, to conversationID: UUID) {
        insertedMessages.append(message)
    }

    func messages(for conversationID: UUID) -> [Message] {
        insertedMessages.filter { $0.conversationID == conversationID }
    }

    func messagesSnapshot(in conversationID: UUID) async -> [Message] {
        messages(for: conversationID)
    }

    func firstUserMessage(in conversationID: UUID) async -> Message? { nil }

    func messagesForLLM(in conversationID: UUID) async -> [Message] {
        messages(for: conversationID)
    }

    func messagePage(
        for conversationID: UUID,
        limit: Int,
        beforeMessageID: UUID?,
        includesToolMessages: Bool
    ) -> [Message] {
        []
    }

    func messagePageAsync(
        for conversationID: UUID,
        limit: Int,
        beforeMessageID: UUID?,
        includesToolMessages: Bool
    ) async -> [Message] {
        []
    }

    func hasEarlierMessages(
        for conversationID: UUID,
        beforeMessageID: UUID?,
        includesToolMessages: Bool
    ) -> Bool {
        false
    }

    func hasEarlierMessagesAsync(
        for conversationID: UUID,
        beforeMessageID: UUID?,
        includesToolMessages: Bool
    ) async -> Bool {
        false
    }

    func message(id: UUID, in conversationID: UUID) -> Message? { nil }

    func lastMessage(in conversationID: UUID) -> Message? { nil }

    func messageCount(for conversationID: UUID) -> Int {
        messages(for: conversationID).count
    }

    func dailyMessageCounts(since: Date) -> [Date: Int] { [:] }

    func dailyMessageCountsAsync(since: Date) async -> [Date: Int] { [:] }

    func dailyTokenCounts(since: Date) -> [Date: Int] { [:] }

    func dailyTokenCountsAsync(since: Date) async -> [Date: Int] { [:] }

    func updateMessage(id: UUID, in conversationID: UUID, content: String) {}

    func deleteMessage(id: UUID, in conversationID: UUID) {}

    func clearMessages(in conversationID: UUID) {}

    func updateToolCallResult(
        _ result: MessageToolResult,
        toolCallID: String,
        assistantMessageID: UUID,
        in conversationID: UUID,
        authorizationState: String?
    ) {}

    @discardableResult
    func addMessageInsertedObserver(
        _ callback: @escaping (Message, UUID) -> Void
    ) -> any MessageInsertedObserverHandle {
        NotificationTestObserverHandle()
    }

    @discardableResult
    func addMessageChangeObserver(
        _ callback: @escaping (MessageChange) -> Void
    ) -> any MessageChangeObserverHandle {
        NotificationTestObserverHandle()
    }
}

@MainActor
private final class NotificationTestObserverHandle: MessageInsertedObserverHandle, MessageChangeObserverHandle {
    func cancel() {}
}
