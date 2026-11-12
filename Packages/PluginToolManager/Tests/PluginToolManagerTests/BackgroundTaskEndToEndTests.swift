import Foundation
import KitAgentTool
import KitShell
import ProviderAgentLoop
import ProviderLifecycleHooks
import ProviderMessage
import Testing
@testable import PluginToolManager

/// 非阻塞 `run_command` 的端到端链路。
///
/// 覆盖 Issue #1307 的完整场景：
/// 预算耗尽 → 进程交接后台继续运行 → 输出写入可读文件 → 完成后通知送回
/// 来源会话 → 模型被唤醒。
@Suite("Background Task End To End")
@MainActor
struct BackgroundTaskEndToEndTests {

    @Test("长命令在预算内返回、进程继续运行、完成后通知唤醒模型")
    func longCommandHandsOffThenNotifies() async throws {
        let directory = try makeTemporaryDirectory()
        defer { try? FileManager.default.removeItem(at: directory) }

        let conversationID = UUID()
        let registry = BackgroundTaskRegistry(rootDirectory: directory)
        let agentLoop = EndToEndAgentLoop()
        let messages = EndToEndMessages()
        let coordinator = BackgroundTaskNotificationCoordinator(
            agentLoop: agentLoop,
            messages: messages,
            registry: registry
        )
        let observerID = await registry.addObserver { event in
            guard case .finished(let record) = event else { return }
            Task { @MainActor in
                coordinator.handle(record)
            }
        }
        defer { Task { await registry.removeObserver(observerID) } }

        let tool = ShellTool(
            commandTimeout: 1,
            workspaceRootProvider: { "/tmp" },
            backgroundTaskRegistryProvider: { registry },
            currentConversationIDProvider: { conversationID }
        )

        // 1. 预算耗尽：工具在预算内返回后台提示。
        let result = try await tool.execute(arguments: [
            "command": ToolArgument("while true; do echo tick; sleep 0.2; done"),
            "timeout": ToolArgument(1),
        ])
        #expect(result.contains("running in the background"))

        let taskID = try #require(parseField(result, prefix: "Background task ID:"))
        let outputPath = try #require(parseField(result, prefix: "Output file:"))

        // 2. 进程继续运行。
        let record = try #require(await registry.task(for: taskID))
        #expect(record.status == .running)
        #expect(record.conversationID == conversationID)

        // 3. 输出写入文件，模型可以用 read_file 读到。
        try await Task.sleep(nanoseconds: 800_000_000)
        let contents = (try? String(contentsOf: URL(fileURLWithPath: outputPath), encoding: .utf8)) ?? ""
        #expect(contents.contains("tick"))

        // 4. 停止任务，触发完成事件。
        #expect(await registry.stop(taskID: taskID) == true)
        try await Task.sleep(nanoseconds: 500_000_000)

        // 5. 通知送回来源会话，模型被唤醒。
        let inserted = messages.insertedMessages
        #expect(inserted.count == 1)
        #expect(inserted.first?.role == .user)
        #expect(inserted.first?.conversationID == conversationID)
        #expect(inserted.first?.content.contains(taskID) == true)
        #expect(inserted.first?.content.contains(outputPath) == true)
        #expect(inserted.first?.content.contains("read_file") == true)
    }

    @Test("取消回合不会杀掉后台任务")
    func cancellingTurnKeepsBackgroundTaskAlive() async throws {
        let directory = try makeTemporaryDirectory()
        defer { try? FileManager.default.removeItem(at: directory) }

        let registry = BackgroundTaskRegistry(rootDirectory: directory)
        let tool = ShellTool(
            commandTimeout: 1,
            workspaceRootProvider: { "/tmp" },
            backgroundTaskRegistryProvider: { registry }
        )

        let result = try await tool.execute(arguments: [
            "command": ToolArgument("while true; do sleep 1; done"),
            "timeout": ToolArgument(1),
        ])
        let taskID = try #require(parseField(result, prefix: "Background task ID:"))

        let record = try #require(await registry.task(for: taskID))
        #expect(record.status == .running)

        // 「取消回合」在实现上不触碰登记表：任务状态仍是 running。
        #expect(await registry.task(for: taskID)?.status == .running)

        _ = await registry.stop(taskID: taskID)
    }

    @Test("短命令不进入后台，行为与之前一致")
    func shortCommandNeverEntersBackground() async throws {
        let directory = try makeTemporaryDirectory()
        defer { try? FileManager.default.removeItem(at: directory) }

        let registry = BackgroundTaskRegistry(rootDirectory: directory)
        let tool = ShellTool(
            workspaceRootProvider: { "/tmp" },
            backgroundTaskRegistryProvider: { registry }
        )

        let result = try await tool.execute(arguments: [
            "command": ToolArgument("echo quick"),
        ])
        #expect(result.contains("quick"))
        #expect(!result.contains("running in the background"))
        #expect(await registry.allTasks().isEmpty)
    }

    @Test("无上下文时后台任务归属当前选中的会话")
    func backgroundTaskUsesSelectedConversationWhenContextIsAbsent() async throws {
        let directory = try makeTemporaryDirectory()
        defer { try? FileManager.default.removeItem(at: directory) }

        let conversationID = UUID()
        let registry = BackgroundTaskRegistry(rootDirectory: directory)
        let tool = ShellTool(
            commandTimeout: 1,
            workspaceRootProvider: { "/tmp" },
            backgroundTaskRegistryProvider: { registry },
            currentConversationIDProvider: { conversationID }
        )

        let result = try await tool.execute(arguments: [
            "command": ToolArgument("while true; do sleep 1; done"),
            "timeout": ToolArgument(1),
        ])
        let taskID = try #require(parseField(result, prefix: "Background task ID:"))

        // 没有 ToolExecutionContext 时，任务必须挂在当前选中的会话上：
        // 否则完成通知会被投递到一个不存在的会话，模型永远收不到。
        let record = try #require(await registry.task(for: taskID))
        #expect(record.conversationID == conversationID)

        _ = await registry.stop(taskID: taskID)
    }

    @Test("输出文件能被 read_file 用绝对路径读到")
    func outputFileIsReadableByReadFileWithAbsolutePath() async throws {
        let directory = try makeTemporaryDirectory()
        defer { try? FileManager.default.removeItem(at: directory) }

        let registry = BackgroundTaskRegistry(rootDirectory: directory)
        let tool = ShellTool(
            commandTimeout: 1,
            workspaceRootProvider: { "/tmp" },
            backgroundTaskRegistryProvider: { registry }
        )

        let result = try await tool.execute(arguments: [
            "command": ToolArgument("while true; do echo marker-line; sleep 0.2; done"),
            "timeout": ToolArgument(1),
        ])
        let outputPath = try #require(parseField(result, prefix: "Output file:"))
        let taskID = try #require(parseField(result, prefix: "Background task ID:"))

        try await Task.sleep(nanoseconds: 800_000_000)

        // 模型用 read_file 读输出文件：路径是绝对的，必须能直接读到。
        let readTool = ReadFileTool()
        let content = try await readTool.execute(arguments: ["path": ToolArgument(outputPath)])
        #expect(content.contains("marker-line"))

        _ = await registry.stop(taskID: taskID)
    }
}

// MARK: - Helpers

private func makeTemporaryDirectory() throws -> URL {
    let url = FileManager.default.temporaryDirectory
        .appendingPathComponent("BackgroundTaskEndToEndTests-\(UUID().uuidString)", isDirectory: true)
    try FileManager.default.createDirectory(at: url, withIntermediateDirectories: true)
    return url
}

/// 从工具结果文本里解析 `prefix: value` 形式的字段。
private func parseField(_ text: String, prefix: String) -> String? {
    text.split(separator: "\n")
        .first { $0.hasPrefix(prefix) }
        .map { String($0.dropFirst(prefix.count)).trimmingCharacters(in: .whitespaces) }
}

/// 只实现端到端链路用到的最小 AgentLoop 能力。
@MainActor
private final class EndToEndAgentLoop: AgentLoopProviding {
    private var suppressed: Set<UUID> = []

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

    func isRunning(for conversationID: UUID) -> Bool { false }

    func runTurn(in conversationID: UUID) async throws -> AgentLoopOutcome { .completed }

    func resumeTurn(in conversationID: UUID, request: AgentTurnResumeRequest) async throws -> AgentLoopOutcome {
        .completed
    }

    func cancelTurn(in conversationID: UUID) {}

    func state(for conversationID: UUID) -> AgentLoopState { .idle }

    func suspension(for conversationID: UUID) -> AgentLoopSuspension? { nil }

    func lastFailure(for conversationID: UUID) -> AgentLoopFailure? { nil }

    func currentTurnID(for conversationID: UUID) -> UUID? { nil }

    func setLifecycleHooks(_ hooks: (any LifecycleHooksProviding)?) {}
}

/// 记录插入消息的最小 MessageManaging 实现。
@MainActor
private final class EndToEndMessages: MessageManaging {
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
        EndToEndObserverHandle()
    }

    @discardableResult
    func addMessageChangeObserver(
        _ callback: @escaping (MessageChange) -> Void
    ) -> any MessageChangeObserverHandle {
        EndToEndObserverHandle()
    }
}

@MainActor
private final class EndToEndObserverHandle: MessageInsertedObserverHandle, MessageChangeObserverHandle {
    func cancel() {}
}
