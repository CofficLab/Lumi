import Combine
import Foundation
import MagicKit
import SwiftData

/// 窗口内 Agent 对话的命令与副作用（消息、轮次、runtimeStore 等）。
/// 编排时机由 `RootView` / `Handler` 触发；配置面见 `AgentSessionConfig`，流式刷新信号见 `AgentStreamingRender`。
@MainActor
final class WindowAgentCommands: ObservableObject, SuperLog {
    nonisolated static let emoji = "🤖"
    nonisolated static let verbose = false

    let promptService: PromptService
    let toolService: ToolService
    let chatHistoryService: ChatHistoryService

    let runtimeStore: ConversationRuntimeStore
    let streamingRender: AgentStreamingRender
    let sessionConfig: AgentSessionConfig

    let messageViewModel: MessagePendingVM
    let ConversationVM: ConversationVM
    let messageSenderVM: MessageQueueVM
    let projectVM: ProjectVM
    let conversationTurnViewModel: ConversationTurnVM
    let uiHandler: AgentUIHandler

    private var cancellables = Set<AnyCancellable>()

    init(
        runtimeStore: ConversationRuntimeStore,
        streamingRender: AgentStreamingRender,
        sessionConfig: AgentSessionConfig,
        promptService: PromptService,
        toolService: ToolService,
        chatHistoryService: ChatHistoryService,
        messageViewModel: MessagePendingVM,
        ConversationVM: ConversationVM,
        MessageSenderVM: MessageQueueVM,
        projectVM: ProjectVM,
        conversationTurnViewModel: ConversationTurnVM,
        uiHandler: AgentUIHandler
    ) {
        self.runtimeStore = runtimeStore
        self.streamingRender = streamingRender
        self.sessionConfig = sessionConfig
        self.promptService = promptService
        self.toolService = toolService
        self.chatHistoryService = chatHistoryService
        self.messageViewModel = messageViewModel
        self.ConversationVM = ConversationVM
        self.messageSenderVM = MessageSenderVM
        self.projectVM = projectVM
        self.conversationTurnViewModel = conversationTurnViewModel
        self.uiHandler = uiHandler

        runtimeStore.objectWillChange
            .sink { [weak self] _ in
                self?.objectWillChange.send()
            }
            .store(in: &cancellables)
    }

    private typealias StreamSessionState = ConversationRuntimeStore.StreamSessionState
    private var turnTaskPipelineByConversation: [UUID: Task<Void, Never>] = [:]
    private var turnTaskGenerationByConversation: [UUID: Int] = [:]
    /// 单条消息思考内容最大保留字符数，超出部分在累积时截断、不会落库（reasoner 等模型可能输出较长思考）
    private let maxThinkingTextLength = 100_000
    private let streamUIFlushInterval: TimeInterval = 0.08
    private let thinkingUIFlushInterval: TimeInterval = 0.12
    private let immediateStreamFlushChars = 80
    private let immediateThinkingFlushChars = 120
    private let captureThinkingContent = true

    /// 由 `RootView.task` 挂接轮次事件流水线。
    func makeConversationTurnPipelineHandler() -> ConversationTurnPipelineHandler {
        ConversationTurnPipelineHandler(
            conversationTurnViewModel: conversationTurnViewModel,
            runtimeStore: runtimeStore,
            env: .init(
                selectedConversationId: { [weak self] in self?.ConversationVM.selectedConversationId },
                maxThinkingTextLength: maxThinkingTextLength,
                immediateStreamFlushChars: immediateStreamFlushChars,
                immediateThinkingFlushChars: immediateThinkingFlushChars,
                captureThinkingContent: captureThinkingContent
            ),
            messages: .init(
                messages: { [weak self] in self?.messages ?? [] },
                appendMessage: { [weak self] m in self?.appendMessage(m) },
                updateMessage: { [weak self] m, idx in self?.updateMessage(m, at: idx) },
                saveMessage: { [weak self] m, cid in
                    guard let self else { return }
                    await self.saveMessage(m, conversationId: cid)
                },
                flushPendingStreamText: { [weak self] cid, force in
                    self?.flushPendingStreamTextIfNeeded(for: cid, force: force)
                },
                flushPendingThinkingText: { [weak self] cid, force in
                    self?.flushPendingThinkingTextIfNeeded(for: cid, force: force)
                },
                updateRuntimeState: { [weak self] cid in
                    self?.updateRuntimeState(for: cid)
                }
            ),
            ui: conversationTurnPipelineUIActions(),
            onFallbackEvent: { [weak self] event in
                guard let self else { return }
                await self.handleConversationTurnEventFallback(event)
            }
        )
    }

    private func conversationTurnPipelineUIActions() -> ConversationTurnMiddlewareUIActions {
        let ui = uiHandler
        return .init(
            setPendingPermissionRequest: { request, conversationId in
                ui.setPendingPermissionRequest(request, conversationId: conversationId)
            },
            setDepthWarning: { warning, conversationId in
                ui.setDepthWarning(warning, conversationId: conversationId)
            },
            onTurnFinishedUI: { conversationId in
                ui.onTurnFinishedUI(conversationId: conversationId)
            },
            onTurnFailedUI: { conversationId, errorMessage in
                ui.onTurnFailedUI(conversationId: conversationId, errorMessage: errorMessage)
            },
            onStreamStartedUI: { [weak self] messageId, conversationId in
                guard let self else { return }
                ui.onStreamStartedUI(messageId: messageId, conversationId: conversationId)
                if self.ConversationVM.selectedConversationId == conversationId {
                    self.streamingRender.bump()
                }
            },
            onStreamFirstTokenUI: { conversationId, ttftMs in
                ui.onStreamFirstTokenUI(conversationId: conversationId, ttftMs: ttftMs)
            },
            onStreamFinishedUI: { [weak self] conversationId in
                guard let self else { return }
                ui.setThinkingText(
                    self.runtimeStore.thinkingTextByConversation[conversationId] ?? "",
                    for: conversationId
                )
                ui.setIsThinking(false, for: conversationId)
                ui.onStreamFinishedUI(conversationId: conversationId)
                self.runtimeStore.streamingTextByConversation[conversationId] = nil
                if self.ConversationVM.selectedConversationId == conversationId {
                    self.streamingRender.bump()
                }
            },
            onThinkingStartedUI: { conversationId in
                ui.onThinkingStartedUI(conversationId: conversationId)
            },
            setLastHeartbeatTime: { date in
                ui.setLastHeartbeatTime(date)
            },
            setIsThinking: { isThinking, cid in
                ui.setIsThinking(isThinking, for: cid)
            },
            setThinkingText: { text, cid in
                ui.setThinkingText(text, for: cid)
            }
        )
    }

    /// Fallback：未下沉到 Coordinator 的事件仍由此处理
    private func handleConversationTurnEventFallback(_ event: ConversationTurnEvent) async {
        switch event {
        case let .shouldContinue(depth, conversationId):
            enqueueTurnProcessing(conversationId: conversationId, depth: depth)
        default:
            break
        }
    }

    /// 触发指定会话的轮次处理
    /// - Parameters:
    ///   - conversationId: 会话 ID
    ///   - depth: 递归深度
    func enqueueTurnProcessing(conversationId: UUID, depth: Int) {
        let previousTask: Task<Void, Never>?
        if depth == 0 {
            // 新的用户消息应当抢占旧的续轮链路，避免被历史任务阻塞。
            if Self.verbose, turnTaskPipelineByConversation[conversationId] != nil {
                AppLogger.core.info("\(Self.t)🧵 [\(conversationId)] 新消息到达，取消旧轮次链路")
            }
            turnTaskPipelineByConversation[conversationId]?.cancel()
            turnTaskPipelineByConversation[conversationId] = nil
            previousTask = nil
        } else {
            previousTask = turnTaskPipelineByConversation[conversationId]
        }
        let generation = (turnTaskGenerationByConversation[conversationId] ?? 0) + 1
        turnTaskGenerationByConversation[conversationId] = generation
        if Self.verbose {
            AppLogger.core.info("\(Self.t)🧵 [\(conversationId)] 轮次入队 depth=\(depth), gen=\(generation)")
        }

        let task = Task { [weak self] in
            if let previousTask {
                await previousTask.value
            }
            guard let self else { return }
            if Self.verbose {
                AppLogger.core.info("\(Self.t)🧵 [\(conversationId)] 开始执行轮次 depth=\(depth), gen=\(generation)")
            }
            await self.processTurn(conversationId: conversationId, depth: depth)

            await MainActor.run { [weak self] in
                guard let self else { return }
                if self.turnTaskGenerationByConversation[conversationId] == generation {
                    self.turnTaskPipelineByConversation[conversationId] = nil
                }
            }
        }

        turnTaskPipelineByConversation[conversationId] = task
    }

    func runtimeSnapshot(for conversationId: UUID) -> AgentRuntimeSnapshot {
        .init(
            isProcessing: runtimeStore.processingConversationIds.contains(conversationId),
            lastHeartbeatTime: runtimeStore.lastHeartbeatByConversation[conversationId] ?? nil,
            isThinking: runtimeStore.thinkingConversationIds.contains(conversationId),
            thinkingText: runtimeStore.thinkingTextByConversation[conversationId] ?? "",
            pendingPermissionRequest: runtimeStore.pendingPermissionByConversation[conversationId],
            depthWarning: runtimeStore.depthWarningByConversation[conversationId]
        )
    }

    func runtimeState(for conversationId: UUID) -> ConversationRuntimeState {
        runtimeStore.runtimeState(for: conversationId)
    }

    func updateRuntimeState(for conversationId: UUID) {
        runtimeStore.updateRuntimeState(for: conversationId)
    }

    func flushPendingStreamTextIfNeeded(for conversationId: UUID, force: Bool = false) {
        guard let pending = runtimeStore.pendingStreamTextByConversation[conversationId], !pending.isEmpty else {
            return
        }
        let now = Date()
        let lastFlush = runtimeStore.lastStreamFlushAtByConversation[conversationId] ?? .distantPast
        guard force || now.timeIntervalSince(lastFlush) >= streamUIFlushInterval else {
            return
        }
        runtimeStore.streamingTextByConversation[conversationId, default: ""] += pending
        if ConversationVM.selectedConversationId == conversationId {
            streamingRender.bump()
        }
        runtimeStore.pendingStreamTextByConversation[conversationId] = ""
        runtimeStore.lastStreamFlushAtByConversation[conversationId] = now
    }

    func flushPendingThinkingTextIfNeeded(for conversationId: UUID, force: Bool = false) {
        guard let pending = runtimeStore.pendingThinkingTextByConversation[conversationId], !pending.isEmpty else {
            return
        }
        let now = Date()
        let lastFlush = runtimeStore.lastThinkingFlushAtByConversation[conversationId] ?? .distantPast
        guard force || now.timeIntervalSince(lastFlush) >= thinkingUIFlushInterval else {
            return
        }
        guard ConversationVM.selectedConversationId == conversationId else { return }
        uiHandler.appendThinkingText(pending, for: conversationId)
        runtimeStore.pendingThinkingTextByConversation[conversationId] = ""
        runtimeStore.lastThinkingFlushAtByConversation[conversationId] = now
    }

    // MARK: - 业务方法

    /// 当前会话的消息列表（代理到 MessageViewModel）
    var messages: [ChatMessage] {
        messageViewModel.messages
    }

    /// 语言偏好（代理到 projectVM）
    var languagePreference: LanguagePreference {
        projectVM.languagePreference
    }

    /// 是否已选择项目（代理到 projectVM）
    var isProjectSelected: Bool {
        projectVM.isProjectSelected
    }

    /// 追加消息到列表
    func appendMessage(_ message: ChatMessage) {
        messageViewModel.appendMessage(message)
    }

    /// 更新指定位置的消息
    func updateMessage(_ message: ChatMessage, at index: Int) {
        messageViewModel.updateMessage(message, at: index)
    }

    /// 保存消息到当前会话
    func saveMessage(_ message: ChatMessage) async {
        await ConversationVM.saveMessage(message)
    }

    /// 保存消息到指定会话
    func saveMessage(_ message: ChatMessage, conversationId: UUID) async {
        await ConversationVM.saveMessage(message, to: conversationId)
    }

    /// 取消指定会话正在进行的生成（队列、轮次任务、流式缓存与相关 UI）。
    func cancelTask(for conversationId: UUID) {
        messageSenderVM.cancelProcessing(for: conversationId, clearQueue: true)
        turnTaskPipelineByConversation[conversationId]?.cancel()
        turnTaskPipelineByConversation[conversationId] = nil
        runtimeStore.processingConversationIds.remove(conversationId)
        runtimeStore.streamStateByConversation[conversationId] = StreamSessionState(messageId: nil, messageIndex: nil)
        runtimeStore.pendingStreamTextByConversation[conversationId] = nil
        runtimeStore.streamingTextByConversation[conversationId] = nil
        runtimeStore.thinkingConversationIds.remove(conversationId)
        runtimeStore.pendingPermissionByConversation[conversationId] = nil
        streamingRender.bump()
        updateRuntimeState(for: conversationId)

        AppLogger.core.info("\(Self.t)🛑 任务已取消 [\(String(conversationId.uuidString.prefix(8)))]")
        uiHandler.setIsProcessing(false)
        uiHandler.setIsThinking(false, for: conversationId)
        uiHandler.setPendingPermissionRequest(nil, conversationId: conversationId)
        let cancelMessage = projectVM.languagePreference == .chinese ? "⚠️ 生成已取消" : "⚠️ Generation cancelled"
        appendMessage(ChatMessage(role: .assistant, content: cancelMessage))
    }

    // MARK: - 对话轮次处理

    func processTurn(conversationId: UUID, depth: Int = 0) async {
        let messages = await getMessagesForLLM(conversationId: conversationId)

        await conversationTurnViewModel.processTurn(
            conversationId: conversationId,
            depth: depth,
            config: sessionConfig.getCurrentConfig(),
            messages: messages,
            chatMode: projectVM.chatMode,
            tools: toolService.tools,
            languagePreference: projectVM.languagePreference,
            autoApproveRisk: projectVM.autoApproveRisk
        )
    }

    /// 获取发送给 LLM 的消息列表
    private func getMessagesForLLM(conversationId: UUID) async -> [ChatMessage] {
        await chatHistoryService.loadMessagesAsync(forConversationId: conversationId) ?? []
    }

    func getMessageCount(forConversationId conversationId: UUID) async -> Int {
        await chatHistoryService.getMessageCount(forConversationId: conversationId)
    }

    func loadMessagesPage(
        forConversationId conversationId: UUID,
        limit: Int,
        beforeTimestamp: Date? = nil
    ) async -> (messages: [ChatMessage], hasMore: Bool) {
        await chatHistoryService.loadMessagesPage(
            forConversationId: conversationId,
            limit: limit,
            beforeTimestamp: beforeTimestamp
        )
    }

    func loadToolOutputMessages(
        forConversationId conversationId: UUID,
        toolCallIDs: [String]
    ) async -> [ChatMessage] {
        await chatHistoryService.loadToolOutputMessages(
            forConversationId: conversationId,
            toolCallIDs: toolCallIDs
        )
    }
}
