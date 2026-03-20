import Combine
import Foundation
import MagicKit
/// 窗口内对话轮次编排：续轮任务队列、流水线构建、流式 flush、落库代理等。
/// 服务类依赖（`promptService` / `toolService`）仅因部分视图仍通过本对象读取；其余请直接使用对应 VM / Service。
@MainActor
final class AgentTurnCoordinator: ObservableObject, SuperLog {
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

    private var turnTaskPipelineByConversation: [UUID: Task<Void, Never>] = [:]
    private var turnTaskGenerationByConversation: [UUID: Int] = [:]
    private let maxThinkingTextLength = 100_000
    private let streamUIFlushInterval: TimeInterval = 0.08
    private let thinkingUIFlushInterval: TimeInterval = 0.12
    private let immediateStreamFlushChars = 80
    private let immediateThinkingFlushChars = 120
    private let captureThinkingContent = true

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
                messages: { [weak self] in self?.messageViewModel.messages ?? [] },
                appendMessage: { [weak self] m in self?.messageViewModel.appendMessage(m) },
                updateMessage: { [weak self] m, idx in self?.messageViewModel.updateMessage(m, at: idx) },
                saveMessage: { [weak self] m, cid in
                    guard let self else { return }
                    await self.ConversationVM.saveMessage(m, to: cid)
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

    private func handleConversationTurnEventFallback(_ event: ConversationTurnEvent) async {
        switch event {
        case let .shouldContinue(depth, conversationId):
            enqueueTurnProcessing(conversationId: conversationId, depth: depth)
        default:
            break
        }
    }

    func enqueueTurnProcessing(conversationId: UUID, depth: Int) {
        let previousTask: Task<Void, Never>?
        if depth == 0 {
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

    func appendMessage(_ message: ChatMessage) {
        messageViewModel.appendMessage(message)
    }

    func cancelTurnPipeline(for conversationId: UUID) {
        turnTaskPipelineByConversation[conversationId]?.cancel()
        turnTaskPipelineByConversation[conversationId] = nil
    }

    func processTurn(conversationId: UUID, depth: Int = 0) async {
        let messages = await chatHistoryService.loadMessagesAsync(forConversationId: conversationId) ?? []

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
}
