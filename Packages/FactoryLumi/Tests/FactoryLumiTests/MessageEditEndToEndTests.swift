import Foundation
import KernelCore
import KitAgentTool
import KitLLM
import PluginSubagent
import PluginToolManager
import ProviderAgentLoop
import ProviderConversation
import ProviderLLMManager
import ProviderMessage
import ProviderMessageSender
import ProviderStorage
import ProviderToolManager
import Testing
@testable import FactoryLumi

/// #1331 编辑并重发：真实内核（消息、发送、AgentLoop、工具记录）下的端到端行为。
@MainActor
@Suite("FactoryLumi · 编辑并重发 端到端", .serialized)
struct MessageEditEndToEndTests {
    private static let pluginID = "com.coffic.lumi.tests.message-edit-e2e"
    private static let backgroundNotificationKey = "lumi.backgroundNotification"
    private static let timeout: TimeInterval = 15

    @Test("编辑保留附件、不动更早的回合，上下文与时间线一致")
    func editKeepsAttachmentsAndOlderTurn() async throws {
        let firstPrompt = "Explain option A."
        let secondPrompt = "Compare option A with option B."
        let editedPrompt = "Compare option A with option B in a table."
        let ctx = try await makeContext(scripts: [
            firstPrompt: .text("Option A explained."),
            secondPrompt: .text("Option A versus option B."),
            editedPrompt: .text("Option A versus option B in a table."),
        ])

        _ = try await send(firstPrompt, to: ctx)
        let firstAnswer = try #require(
            ctx.messages.messages(for: ctx.conversationID).first { $0.role == .assistant }
        )
        let image = UserImageAttachment(mimeType: "image/png", base64Data: "aW1hZ2U=", fileName: "a.png")
        let file = UserFileAttachment(fileName: "notes.txt", mimeType: "text/plain", base64Data: "bm90ZXM=")
        try await ctx.sender.sendMessage(
            secondPrompt,
            imageAttachments: [image],
            fileAttachments: [file],
            conversationID: ctx.conversationID
        )
        try await waitTurnSettled(in: ctx)

        let secondUser = try #require(latestRealUserMessage(in: ctx))
        #expect(secondUser.content == secondPrompt)
        #expect(ctx.editing.eligibility(for: secondUser, in: ctx.conversationID) == .allowed)

        var events: [MessageEditingEvent] = []
        let observer = ctx.editing.addObserver { events.append($0) }
        defer { observer.cancel() }

        #expect(ctx.editing.beginEditing(message: secondUser, in: ctx.conversationID))
        let active = try #require(beganDraft(in: events))
        #expect(active.content == secondPrompt)
        #expect(active.imageAttachments == [image])
        #expect(active.fileAttachments == [file])

        let commit = try await ctx.editing.submitEdit(MessageEditDraft(
            targetMessageID: secondUser.id,
            conversationID: ctx.conversationID,
            content: editedPrompt,
            imageAttachments: active.imageAttachments,
            fileAttachments: active.fileAttachments
        ))
        try await waitForReply("Option A versus option B in a table.", in: ctx)
        try await waitTurnSettled(in: ctx)

        #expect(events.count == 2)
        #expect(!isEditingActive(events))
        if events.count == 2 {
            guard case .began(let draft) = events[0], case .ended(let conversationID) = events[1] else {
                Issue.record("expected began then ended, got \(events)")
                return
            }
            #expect(draft.targetMessageID == secondUser.id)
            #expect(conversationID == ctx.conversationID)
        }

        let timeline = ctx.messages.messages(for: ctx.conversationID)
        #expect(timeline.contains { $0.id == firstAnswer.id })
        #expect(realUserTexts(in: ctx) == [firstPrompt, editedPrompt])
        #expect(!timeline.contains { $0.id == secondUser.id })
        #expect(!timeline.contains { $0.role == .assistant && $0.content == "Option A versus option B." })

        let editedUser = try #require(timeline.first { $0.content == editedPrompt })
        #expect(commit.userMessageID == editedUser.id)
        #expect(UserAttachmentMetadata.decodeImageAttachments(from: editedUser.metadata) == [image])
        #expect(UserAttachmentMetadata.decodeFileAttachments(from: editedUser.metadata) == [file])

        // 重发后的请求仍然带着附件说明。
        let editedRequest = try #require(ctx.stub.requests.last { Self.lastUserText(of: $0)?.hasPrefix(editedPrompt) == true })
        #expect(Self.lastUserText(of: editedRequest)?.contains("<attached_file name=\"notes.txt\"") == true)

        let contextIDs = await ctx.messages.messagesForLLM(in: ctx.conversationID).map(\.id)
        #expect(contextIDs == timeline.filter { contextIDs.contains($0.id) }.map(\.id))
        #expect(!contextIDs.contains(secondUser.id))
    }

    @Test("模型仍在流式输出时编辑：先停掉当前回合再重发")
    func editWhileStreamingStopsTurnAndResends() async throws {
        let prompt = "A slow question."
        let editedPrompt = "A slow question, rephrased."
        let ctx = try await makeContext(
            scripts: [prompt: .text("Stale answer."), editedPrompt: .text("Fresh answer.")],
            delays: [prompt: 30]
        )

        sendWithoutWaiting(prompt, to: ctx)
        try await waitUntil("streaming turn in flight") {
            ctx.agentLoop.isRunning(for: ctx.conversationID)
                && ctx.stub.requests.contains { Self.lastUserText(of: $0) == prompt }
        }

        let user = try #require(latestRealUserMessage(in: ctx))
        #expect(ctx.editing.eligibility(for: user, in: ctx.conversationID) == .allowed)
        #expect(ctx.editing.beginEditing(message: user, in: ctx.conversationID))
        _ = try await ctx.editing.submitEdit(draft(for: user, content: editedPrompt, in: ctx))

        try await waitForReply("Fresh answer.", in: ctx)
        try await waitTurnSettled(in: ctx)

        #expect(realUserTexts(in: ctx) == [editedPrompt])
        #expect(!ctx.messages.messages(for: ctx.conversationID).contains { $0.content == "Stale answer." })

        // 被取消的回合不得在截断之后补写任何消息。
        let settledIDs = ctx.messages.messages(for: ctx.conversationID).map(\.id)
        #expect(settledIDs.count == 2)
        try await Task.sleep(nanoseconds: 500_000_000)
        #expect(ctx.messages.messages(for: ctx.conversationID).map(\.id) == settledIDs)
    }

    @Test("工具授权待确认时编辑：授权挂起点被撤销，待确认工具不再执行")
    func editWhileAuthorizationPendingRevokesSuspension() async throws {
        let prompt = "Run the gated tool."
        let editedPrompt = "Run the gated tool, but ask first."
        let tool = EditE2ETool(name: "test_edit_gated_tool", needsApproval: true)
        let ctx = try await makeContext(
            scripts: [editedPrompt: .text("Edited answer.")],
            queues: [prompt: [
                .toolCalls([LLMToolCall(id: "call-gated", name: tool.name, arguments: "{}")]),
                .text("Gated tool answer."),
            ]],
            tools: [tool]
        )

        sendWithoutWaiting(prompt, to: ctx)
        try await waitUntil("authorization suspension") {
            ctx.agentLoop.state(for: ctx.conversationID) == .suspended
        }
        #expect(tool.executionCount == 0)

        let user = try #require(latestRealUserMessage(in: ctx))
        #expect(ctx.editing.eligibility(for: user, in: ctx.conversationID) == .allowed)
        #expect(ctx.editing.beginEditing(message: user, in: ctx.conversationID))
        _ = try await ctx.editing.submitEdit(draft(for: user, content: editedPrompt, in: ctx))

        try await waitForReply("Edited answer.", in: ctx)
        try await waitTurnSettled(in: ctx)

        #expect(tool.executionCount == 0)
        #expect(ctx.agentLoop.state(for: ctx.conversationID) != .suspended)
        #expect(realUserTexts(in: ctx) == [editedPrompt])
        #expect(!ctx.messages.messages(for: ctx.conversationID).contains { $0.content == "Gated tool answer." })
    }

    @Test("最后一条真实用户消息之后插入后台通知：仍可编辑，通知随旧回合一起移除")
    func backgroundNotificationAfterLastUserMessageIsStillEditable() async throws {
        let prompt = "Start the background work."
        let editedPrompt = "Start the background work with extra care."
        let notification = "Background task finished: Subagent conclusion: done."
        let ctx = try await makeContext(scripts: [
            prompt: .text("Background work started."),
            notification: .text("Noted the background result."),
            editedPrompt: .text("Background work started with care."),
        ])

        _ = try await send(prompt, to: ctx)
        let user = try #require(latestRealUserMessage(in: ctx))
        let timelineBefore = ctx.messages.messages(for: ctx.conversationID).count

        ctx.messages.insertMessage(
            Message(
                conversationID: ctx.conversationID,
                role: .user,
                content: notification,
                metadata: [Self.backgroundNotificationKey: "1"]
            ),
            to: ctx.conversationID
        )
        try await waitForReply("Noted the background result.", in: ctx)
        try await waitTurnSettled(in: ctx)
        #expect(ctx.messages.messages(for: ctx.conversationID).count == timelineBefore + 2)

        let notificationMessage = try #require(
            ctx.messages.messages(for: ctx.conversationID).first { $0.content == notification }
        )
        #expect(latestRealUserMessage(in: ctx)?.id == user.id)
        #expect(ctx.editing.eligibility(for: user, in: ctx.conversationID) == .allowed)
        #expect(ctx.editing.eligibility(for: notificationMessage, in: ctx.conversationID) == .notLatestRealUserMessage)
        var events: [MessageEditingEvent] = []
        let observer = ctx.editing.addObserver { events.append($0) }
        defer { observer.cancel() }
        #expect(ctx.editing.beginEditing(message: user, in: ctx.conversationID))
        #expect(beganDraft(in: events)?.content == prompt)

        _ = try await ctx.editing.submitEdit(draft(for: user, content: editedPrompt, in: ctx))
        try await waitForReply("Background work started with care.", in: ctx)
        try await waitTurnSettled(in: ctx)

        let timeline = ctx.messages.messages(for: ctx.conversationID)
        #expect(realUserTexts(in: ctx) == [editedPrompt])
        #expect(!timeline.contains { $0.content == notification })
        #expect(!timeline.contains { $0.content == "Noted the background result." })
        #expect(!timeline.contains { $0.content == "Background work started." })
    }

    @Test("自动回复被抑制的会话（ACP 托管）不可编辑，时间线保持原样")
    func autoReplySuppressedConversationIsNotEditable() async throws {
        let prompt = "A message in an ACP hosted conversation."
        let ctx = try await makeContext(scripts: [prompt: .text("Never sent.")])

        var events: [MessageEditingEvent] = []
        let observer = ctx.editing.addObserver { events.append($0) }
        defer { observer.cancel() }
        ctx.agentLoop.setAutoReplySuppressed(true, for: ctx.conversationID)
        ctx.messages.insertMessage(
            Message(conversationID: ctx.conversationID, role: .user, content: prompt),
            to: ctx.conversationID
        )
        let timelineBefore = ctx.messages.messages(for: ctx.conversationID).map(\.id)
        #expect(timelineBefore.count == 1)

        let user = try #require(latestRealUserMessage(in: ctx))
        #expect(ctx.editing.eligibility(for: user, in: ctx.conversationID) == .autoReplySuppressed)
        #expect(!ctx.editing.beginEditing(message: user, in: ctx.conversationID))
        #expect(events.isEmpty)

        try await Task.sleep(nanoseconds: 300_000_000)
        #expect(ctx.messages.messages(for: ctx.conversationID).map(\.id) == timelineBefore)
        #expect(!ctx.stub.requests.contains { Self.lastUserText(of: $0) == prompt })
    }

    @Test("只删除被编辑回合的工具记录，后台任务不被停止")
    func editDeletesOnlyEditedTurnToolRecordsAndKeepsBackgroundTasks() async throws {
        let firstPrompt = "First turn with a tool."
        let secondPrompt = "Second turn with a tool."
        let editedPrompt = "Second turn with a tool, edited."
        let backgroundTask = "Background task surviving an edit."
        let tool = EditE2ETool()
        let ctx = try await makeContext(
            scripts: [
                editedPrompt: .text("Second turn redone."),
                backgroundTask: .text("Edit survivor conclusion."),
            ],
            delays: [backgroundTask: 4],
            queues: [
                firstPrompt: [
                    .toolCalls([LLMToolCall(id: "call-first", name: tool.name, arguments: "{}")]),
                    .text("First turn done."),
                ],
                secondPrompt: [
                    .toolCalls([LLMToolCall(id: "call-second", name: tool.name, arguments: "{}")]),
                    .text("Second turn done."),
                ],
            ],
            tools: [tool]
        )

        _ = try await send(firstPrompt, to: ctx)
        _ = try await send(secondPrompt, to: ctx)
        #expect(tool.executionCount == 2)

        let timeline = ctx.messages.messages(for: ctx.conversationID)
        let secondIndex = try #require(timeline.firstIndex { $0.content == secondPrompt })
        let keptTurnIDs = Array(Set(timeline[..<secondIndex].compactMap(\.turnID)))
        let removedTurnIDs = Array(Set(timeline[secondIndex...].compactMap(\.turnID)))
        #expect(!keptTurnIDs.isEmpty)
        #expect(!removedTurnIDs.isEmpty)
        #expect(await ctx.toolManager.toolCalls(forTurnIDs: keptTurnIDs).count == 1)
        #expect(await ctx.toolManager.toolCalls(forTurnIDs: removedTurnIDs).count == 1)

        let registry = try #require(ctx.kernel.resolveProvider(BackgroundTaskRegistry.self))
        let result = try await dispatchBackgroundTask(backgroundTask, in: ctx)
        #expect(!result.isError)
        let record = try #require(await registry.tasks(forConversationID: ctx.conversationID).first)
        #expect(record.status == .running)

        let user = try #require(latestRealUserMessage(in: ctx))
        #expect(ctx.editing.beginEditing(message: user, in: ctx.conversationID))
        _ = try await ctx.editing.submitEdit(draft(for: user, content: editedPrompt, in: ctx))
        try await waitForReply("Second turn redone.", in: ctx)
        try await waitTurnSettled(in: ctx)

        #expect(await ctx.toolManager.toolCalls(forTurnIDs: keptTurnIDs).count == 1)
        #expect(await ctx.toolManager.toolCalls(forTurnIDs: removedTurnIDs).isEmpty)
        #expect(await registry.task(for: record.id)?.status == .running)

        try await waitUntil("background task finishes") {
            await registry.task(for: record.id)?.status != .running
        }
        #expect(await registry.task(for: record.id)?.status == .completed)
    }

    @Test("编辑后立即追加发送：新回合先跑，追加消息排在其后")
    func messageSentRightAfterEditRunsAfterEditedTurn() async throws {
        let prompt = "Original question."
        let editedPrompt = "Original question, edited."
        let followUp = "And one more thing."
        let ctx = try await makeContext(scripts: [
            prompt: .text("Original answer."),
            editedPrompt: .text("Edited answer."),
            followUp: .text("Follow-up answer."),
        ], delays: [editedPrompt: 0.6])

        _ = try await send(prompt, to: ctx)
        let user = try #require(latestRealUserMessage(in: ctx))
        #expect(ctx.editing.beginEditing(message: user, in: ctx.conversationID))
        // 与输入框一致：提交成功后立刻为这次提交启动回合跟踪。
        let submission = EditSubmission()
        Task { @MainActor in
            do {
                let commit = try await ctx.editing.submitEdit(draft(for: user, content: editedPrompt, in: ctx))
                submission.commit = commit
                await ctx.sender.startTurn(for: commit)
            } catch {
                submission.error = error
            }
        }
        try await waitUntil("edited turn streaming") {
            submission.commit != nil && ctx.agentLoop.isRunning(for: ctx.conversationID)
        }
        #expect(ctx.sender.pendingMessages(for: ctx.conversationID).isEmpty)

        // 重发的回合还在流式输出，此时追加的消息必须排队而不是丢失或抢跑。
        try await ctx.sender.sendMessage(followUp, conversationID: ctx.conversationID)
        #expect(submission.error == nil)

        try await waitForReply("Follow-up answer.", in: ctx)
        try await waitTurnSettled(in: ctx)

        let timeline = ctx.messages.messages(for: ctx.conversationID)
        let orderedTexts = timeline.filter { $0.role == .user || $0.role == .assistant }.map(\.content)
        #expect(orderedTexts == [editedPrompt, "Edited answer.", followUp, "Follow-up answer."])
        #expect(!timeline.contains { $0.content == prompt })

        let requested = ctx.stub.requests.compactMap { request -> String? in
            [editedPrompt, followUp].first { Self.lastUserText(of: request) == $0 }
        }
        #expect(requested == [editedPrompt, followUp])
    }

    // MARK: - Helpers

    private struct Context {
        let kernel: KernelCoreContainer
        let stub: EditScriptedLLMManager
        let conversationID: UUID
        let messages: any MessageManaging
        let sender: any MessageSendingProviding
        let editing: any MessageEditingProviding
        let agentLoop: any AgentLoopProviding
        let toolManager: any ToolManagerProviding
    }

    private static func lastUserText(of request: LLMRequest) -> String? {
        request.messages.last(where: { $0.role == .user })?.content
    }

    private func makeContext(
        scripts: [String: EditScript] = [:],
        delays: [String: TimeInterval] = [:],
        queues: [String: [EditScript]] = [:],
        tools: [EditE2ETool] = []
    ) async throws -> Context {
        let stub = EditScriptedLLMManager()
        stub.scripts = scripts
        stub.delays = delays
        stub.scriptQueues = queues
        let root = FileManager.default.temporaryDirectory
            .appendingPathComponent("MessageEditE2ETests-\(UUID().uuidString)", isDirectory: true)
        let kernel = try KernelFactory.makeKernel(
            providerFactory: DefaultProviderFactory(dataRootDirectory: root),
            pluginFactory: DefaultPluginFactory(),
            additionalPlugins: [EditStubLLMInstallerPlugin(stub: stub)]
        )
        let toolManager = try #require(kernel.resolveProvider((any ToolManagerProviding).self))
        for tool in tools {
            toolManager.add(tool, pluginID: Self.pluginID)
        }
        let conversations = try #require(kernel.resolveProvider((any ConversationManaging).self))
        let conversationID = try await conversations.createConversationAndWait(
            title: "Edit and resend", projectPath: nil, modelID: nil, parentConversationID: nil
        )
        return Context(
            kernel: kernel,
            stub: stub,
            conversationID: conversationID,
            messages: try #require(kernel.resolveProvider((any MessageManaging).self)),
            sender: try #require(kernel.resolveProvider((any MessageSendingProviding).self)),
            editing: try #require(kernel.resolveProvider((any MessageEditingProviding).self)),
            agentLoop: try #require(kernel.resolveProvider((any AgentLoopProviding).self)),
            toolManager: toolManager
        )
    }

    private func draft(for message: Message, content: String, in ctx: Context) -> MessageEditDraft {
        MessageEditDraft(
            targetMessageID: message.id,
            conversationID: ctx.conversationID,
            content: content,
            imageAttachments: UserAttachmentMetadata.decodeImageAttachments(from: message.metadata),
            fileAttachments: UserAttachmentMetadata.decodeFileAttachments(from: message.metadata)
        )
    }

    /// 真实用户消息：排除时间线卡片与后台任务通知。
    private func realUserTexts(in ctx: Context) -> [String] {
        ctx.messages.messages(for: ctx.conversationID)
            .filter {
                $0.role == .user
                    && !MessageTimelineEvent.isTimelineEvent($0)
                    && $0.metadata[Self.backgroundNotificationKey] == nil
            }
            .map(\.content)
    }

    private func latestRealUserMessage(in ctx: Context) -> Message? {
        let texts = realUserTexts(in: ctx)
        guard let last = texts.last else { return nil }
        return ctx.messages.messages(for: ctx.conversationID)
            .last { $0.role == .user && $0.content == last }
    }

    private func send(_ text: String, to ctx: Context) async throws -> Message {
        try await ctx.sender.sendMessage(text, conversationID: ctx.conversationID)
        try await waitTurnSettled(in: ctx)
        return try #require(latestRealUserMessage(in: ctx))
    }

    /// 只落库、不等回合结束：用于「回合进行中」的窗口。
    private func sendWithoutWaiting(_ text: String, to ctx: Context) {
        ctx.messages.insertMessage(
            Message(conversationID: ctx.conversationID, role: .user, content: text),
            to: ctx.conversationID
        )
    }

    private func beganDraft(in events: [MessageEditingEvent]) -> MessageEditDraft? {
        for event in events.reversed() {
            if case .began(let draft) = event { return draft }
        }
        return nil
    }

    private func isEditingActive(_ events: [MessageEditingEvent]) -> Bool {
        var balance = 0
        for event in events {
            switch event {
            case .began: balance += 1
            case .ended: balance -= 1
            }
        }
        return balance > 0
    }

    private func waitForReply(_ text: String, in ctx: Context) async throws {
        try await waitUntil("reply “\(text)”") {
            ctx.messages.messages(for: ctx.conversationID).contains {
                $0.role == .assistant && $0.content.contains(text)
            }
        }
    }

    private func waitTurnSettled(in ctx: Context) async throws {
        try await waitUntil("turn settled") { !ctx.agentLoop.isRunning(for: ctx.conversationID) }
    }

    private func waitUntil(
        _ what: String,
        _ condition: @MainActor () async -> Bool
    ) async throws {
        let deadline = Date().addingTimeInterval(Self.timeout)
        while Date() < deadline {
            if await condition() { return }
            try await Task.sleep(nanoseconds: 50_000_000)
        }
        throw EditE2ETimeout(what: what)
    }

    /// 后台派发一个子代理任务；立即返回，子回合继续在后台跑。
    private func dispatchBackgroundTask(_ task: String, in ctx: Context) async throws -> ToolCallResult {
        let arguments = try JSONSerialization.data(withJSONObject: [
            "task": task,
            "description": "Edit survivor",
            "run_in_background": true,
        ])
        let call = KitAgentTool.ToolCall(
            id: UUID().uuidString,
            name: "run_subagent",
            arguments: String(decoding: arguments, as: UTF8.self)
        )
        return try await ctx.toolManager.execute(call, conversationID: ctx.conversationID, turnID: UUID())
    }
}

/// 跨 Task 传递编辑提交结果的盒子；读写都在 MainActor 上。
@MainActor
private final class EditSubmission {
    var commit: MessageSendCommit?
    var error: (any Error)?
}

private struct EditE2ETimeout: Error {
    let what: String
}

// MARK: - Scripted LLM

/// 按「最后一条用户消息文本」路由响应的 LLM 替身。
private enum EditScript {
    case text(String)
    case toolCalls([LLMToolCall])
}

@MainActor
private final class EditScriptedLLMManager: LLMManaging, LLMStreamingProviding, @unchecked Sendable {
    var scripts: [String: EditScript] = [:]
    var scriptQueues: [String: [EditScript]] = [:]
    var delays: [String: TimeInterval] = [:]
    private(set) var requests: [LLMRequest] = []

    var providerID: String { "stub-provider" }
    var providerInfo: LLMProviderInfo {
        LLMProviderInfo(
            id: providerID,
            displayName: "Stub",
            defaultModel: "stub-model",
            models: [LLMModelInfo(id: "stub-model")],
            isLocal: true
        )
    }
    var selectedProviderID: String? { providerID }
    var selectedModel: String? { "stub-model" }
    var providerCount: Int { 1 }

    func allProviders() -> [any SuperLLMProvider] { [self] }
    func provider(id: String) -> (any SuperLLMProvider)? { id == providerID ? self : nil }
    func register(_ provider: any SuperLLMProvider) throws {}
    func unregister(id: String) {}
    func models(for providerID: String) -> [String] { ["stub-model"] }
    func select(providerID: String, model: String?, reason: ModelSelectionReason) {}

    func complete(_ request: LLMRequest) async throws -> LLMResponse {
        try await respond(to: request)
    }

    func streamComplete(
        _ request: LLMRequest,
        onChunk: @escaping @Sendable (LLMStreamChunk) async -> Void
    ) async throws -> LLMResponse {
        let response = try await respond(to: request)
        await onChunk(LLMStreamChunk(content: response.content))
        await onChunk(LLMStreamChunk(isDone: true))
        return response
    }

    private func respond(to request: LLMRequest) async throws -> LLMResponse {
        requests.append(request)
        let task = request.messages.last(where: { $0.role == .user })?.content ?? ""
        if let delay = delays[task] {
            // Task.sleep 响应取消：cancelTurn 取消回合 Task 时这里立刻抛出。
            try await Task.sleep(nanoseconds: UInt64(delay * 1_000_000_000))
        }
        var queue = scriptQueues[task] ?? []
        // 附件会追加在用户消息文本之后，按键的前缀匹配。
        let matched = scripts[task] ?? scripts
            .filter { task.hasPrefix($0.key) }
            .max { $0.key.count < $1.key.count }?
            .value
        let script: EditScript = queue.isEmpty ? (matched ?? .text("ok")) : queue.removeFirst()
        scriptQueues[task] = queue
        switch script {
        case .text(let text):
            return LLMResponse(content: text, model: request.model)
        case .toolCalls(let calls):
            return LLMResponse(content: "", model: request.model, toolCalls: calls)
        }
    }
}

/// 记录执行次数的测试工具；`needsApproval` 让它在默认 build 模式下进入授权确认。
private final class EditE2ETool: SuperAgentTool, @unchecked Sendable {
    let name: String
    private let needsApproval: Bool
    private let lock = NSLock()
    private var executions = 0

    var executionCount: Int {
        lock.lock()
        defer { lock.unlock() }
        return executions
    }

    private func recordExecution() {
        lock.lock()
        defer { lock.unlock() }
        executions += 1
    }

    init(name: String = "test_edit_e2e_tool", needsApproval: Bool = false) {
        self.name = name
        self.needsApproval = needsApproval
    }

    var executionCapability: ToolExecutionCapability { .serialSideEffect }
    func description(for language: LanguagePreference) -> String { name }
    func inputSchema(for language: LanguagePreference) -> [String: Any] { ["type": "object"] }
    func permissionRiskLevel(arguments: [String: ToolArgument]) -> CommandRiskLevel { .safe }
    func requiresExplicitApproval(arguments: [String: ToolArgument]) -> Bool { needsApproval }
    func displayDescription(for arguments: [String: ToolArgument]) -> String { name }
    func execute(arguments: [String: ToolArgument]) async throws -> String {
        recordExecution()
        return "edit e2e tool done"
    }
}

/// 在 PluginAgentLoop（order 8）启动前把内核的 LLMManaging 换成替身。
@MainActor
private final class EditStubLLMInstallerPlugin: SuperPlugin {
    let id = "com.coffic.lumi.tests.stub-llm-installer"
    let order = 7
    let metadata = PluginMetadata(
        id: "com.coffic.lumi.tests.stub-llm-installer",
        name: "Stub LLM Installer",
        description: "",
        category: .core,
        stage: .stable,
        policy: .alwaysOn
    )

    private let stub: EditScriptedLLMManager

    init(stub: EditScriptedLLMManager) {
        self.stub = stub
    }

    func onBoot(kernel: KernelCoreContainer) throws {
        kernel.unregisterProvider((any LLMManaging).self)
        try kernel.registerProvider((any LLMManaging).self, stub)
    }
}
