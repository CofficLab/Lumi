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
    let registry: ProviderRegistry
    let toolService: ToolService
    let chatHistoryService: ChatHistoryService

    let runtimeStore: ConversationRuntimeStore
    let streamingRender: AgentStreamingRender
    let sessionConfig: AgentSessionConfig

    let messageViewModel: MessagePendingVM
    let ConversationVM: ConversationVM
    var messageSenderVM: MessageQueueVM
    let projectVM: ProjectVM
    let conversationTurnViewModel: ConversationTurnVM
    let slashCommandService: SlashCommandService
    let uiHandler: AgentUIHandler

    private var cancellables = Set<AnyCancellable>()

    init(
        runtimeStore: ConversationRuntimeStore,
        streamingRender: AgentStreamingRender,
        sessionConfig: AgentSessionConfig,
        promptService: PromptService,
        registry: ProviderRegistry,
        toolService: ToolService,
        chatHistoryService: ChatHistoryService,
        messageViewModel: MessagePendingVM,
        ConversationVM: ConversationVM,
        MessageSenderVM: MessageQueueVM,
        projectVM: ProjectVM,
        conversationTurnViewModel: ConversationTurnVM,
        slashCommandService: SlashCommandService,
        uiHandler: AgentUIHandler
    ) {
        self.runtimeStore = runtimeStore
        self.streamingRender = streamingRender
        self.sessionConfig = sessionConfig
        self.promptService = promptService
        self.registry = registry
        self.toolService = toolService
        self.chatHistoryService = chatHistoryService
        self.messageViewModel = messageViewModel
        self.ConversationVM = ConversationVM
        self.messageSenderVM = MessageSenderVM
        self.projectVM = projectVM
        self.conversationTurnViewModel = conversationTurnViewModel
        self.slashCommandService = slashCommandService
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

    private func conversationTurnPipelineUIActions() -> ConversationTurnPipelineHandler.UIActions {
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

    /// 清理与指定会话相关的所有运行时状态，避免内存泄漏
    private func cleanupConversationState(_ conversationId: UUID) {
        runtimeStore.cleanupConversationState(conversationId)

        // 取消并移除轮次任务管线
        if let task = turnTaskPipelineByConversation[conversationId] {
            task.cancel()
        }
        turnTaskPipelineByConversation.removeValue(forKey: conversationId)
        turnTaskGenerationByConversation.removeValue(forKey: conversationId)
    }

    /// Fallback：未下沉到 Coordinator 的事件仍由此处理
    private func handleConversationTurnEventFallback(_ event: ConversationTurnEvent) async {
        switch event {
        case let .shouldContinue(depth, conversationId):
            // 继续下一轮
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

    // MARK: - 偏好设置加载
    // 已迁移到 AgentUIHandler / 各 UI VM

    // MARK: - Setter 方法

    // MARK: - 公开 Setter 方法
    /// 设置是否正在处理
    func setIsProcessing(_ processing: Bool) {
        uiHandler.setIsProcessing(processing)
    }

    /// 设置最后心跳时间
    func setLastHeartbeatTime(_ date: Date?) {
        uiHandler.setLastHeartbeatTime(date)
    }

    /// 设置思考状态
    func setIsThinking(_ thinking: Bool, for conversationId: UUID) {
        uiHandler.setIsThinking(thinking, for: conversationId)
    }

    /// 追加思考文本
    func appendThinkingText(_ text: String, for conversationId: UUID) {
        uiHandler.appendThinkingText(text, for: conversationId)
    }

    /// 设置思考文本
    func setThinkingText(_ text: String, for conversationId: UUID) {
        uiHandler.setThinkingText(text, for: conversationId)
    }

    /// 设置待处理权限请求
    func setPendingPermissionRequest(_ request: PermissionRequest?) {
        guard let conversationId = ConversationVM.selectedConversationId else { return }
        uiHandler.setPendingPermissionRequest(request, conversationId: conversationId)
    }

    /// 设置深度警告
    func setDepthWarning(_ warning: DepthWarning?) {
        guard let conversationId = ConversationVM.selectedConversationId else { return }
        uiHandler.setDepthWarning(warning, conversationId: conversationId)
    }

    /// 关闭深度警告
    func dismissDepthWarning() {
        uiHandler.dismissDepthWarning()
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

    /// 提供给 Root 协调器创建消息发送编排器的 runtimeStore 引用。
    /// - Note: Root 负责"从队列触发执行"，因此需要访问 runtimeStore（但不负责其内部结构）。
    var runtimeStoreReference: ConversationRuntimeStore { runtimeStore }

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
        appendThinkingText(pending, for: conversationId)
        runtimeStore.pendingThinkingTextByConversation[conversationId] = ""
        runtimeStore.lastThinkingFlushAtByConversation[conversationId] = now
    }

    // MARK: - 业务方法

    /// 当前会话的消息列表（代理到 MessageViewModel）
    var messages: [ChatMessage] {
        messageViewModel.messages
    }

    // MARK: - 代理 ProjectVM 属性

    /// 语言偏好（代理到 projectVM）
    var languagePreference: LanguagePreference {
        projectVM.languagePreference
    }

    /// 聊天模式（代理到 projectVM）
    var chatMode: ChatMode {
        projectVM.chatMode
    }

    /// 是否已选择项目（代理到 projectVM）
    var isProjectSelected: Bool {
        projectVM.isProjectSelected
    }

    /// 自动批准风险（代理到 projectVM）
    var autoApproveRisk: Bool {
        projectVM.autoApproveRisk
    }

    // MARK: - 消息便捷方法（代理到 ConversationVM）

    /// 追加消息到列表
    func appendMessage(_ message: ChatMessage) {
        messageViewModel.appendMessage(message)
    }

    /// 插入消息到指定位置
    func insertMessage(_ message: ChatMessage, at index: Int) {
        messageViewModel.insertMessage(message, at: index)
    }

    /// 更新指定位置的消息
    func updateMessage(_ message: ChatMessage, at index: Int) {
        messageViewModel.updateMessage(message, at: index)
    }

    /// 设置聊天消息列表
    func setMessages(_ messages: [ChatMessage], reason: String = "设置消息列表") {
        messageViewModel.setMessages(messages, reason: reason)
    }

    /// 保存消息到存储
    func saveMessage(_ message: ChatMessage) async {
        await ConversationVM.saveMessage(message)
    }

    /// 保存消息到指定会话
    func saveMessage(_ message: ChatMessage, conversationId: UUID) async {
        await ConversationVM.saveMessage(message, to: conversationId)
    }

    /// 删除指定对话
    /// 协调多个 ViewModel 完成删除操作：
    /// 1. 清理消息发送队列
    /// 2. 删除会话记录
    /// - Parameter conversation: 要删除的对话
    func deleteConversation(_ conversation: Conversation) {
        if Self.verbose {
            AppLogger.core.info("\(Self.t)🗑️ 开始删除对话：\(conversation.title)")
        }

        // 1. 清理该会话的待发送队列
        messageSenderVM.removeConversationQueue(conversation.id)

        // 如果删除的是选中的对话，清理当前队列
        if ConversationVM.selectedConversationId == conversation.id {
            messageSenderVM.clearCurrentConversationQueue()
        }

        // 2. 清理该会话的运行时状态（流式缓存、思考文本、任务管线等）
        cleanupConversationState(conversation.id)

        // 3. 删除会话记录
        ConversationVM.deleteConversation(conversation)

        if Self.verbose {
            AppLogger.core.info("\(Self.t)✅ 对话已删除：\(conversation.title)")
        }
    }

    // MARK: - 消息发送协调

    /// 发送单条消息到 Agent
    /// - Note: 此方法已废弃，消息发送流程现在由 SenderPendingMessagesHandler 完全负责
    /// - Parameters:
    ///   - message: 要发送的消息
    ///   - conversationId: 会话 ID
    func sendMessageToAgent(message: ChatMessage, conversationId: UUID) async {
        // 空实现，消息发送已由 SenderPendingMessagesHandler 直接处理
    }

    // MARK: - Cancel Support

    /// 取消当前正在进行的任务
    public func cancelCurrentTask() {
        guard let conversationId = ConversationVM.selectedConversationId else { return }

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

        AppLogger.core.info("\(Self.t)🛑 任务已取消")
        // 重置处理状态
        setIsProcessing(false)
        setIsThinking(false, for: conversationId)
        setPendingPermissionRequest(nil)
        // 添加取消提示消息
        let cancelMessage = projectVM.languagePreference == .chinese ? "⚠️ 生成已取消" : "⚠️ Generation cancelled"
        appendMessage(ChatMessage(role: .assistant, content: cancelMessage))
    }

    // MARK: - SlashCommandService API

    public func appendSystemMessage(_ content: String) {
        appendMessage(ChatMessage(role: .assistant, content: content))
    }

    public func triggerPlanningMode(task: String) {
        Task {
            let planPrompt = await promptService.getPlanningModePrompt(task: task)
            // 添加计划模式消息
            appendMessage(ChatMessage(role: .user, content: planPrompt))
            // 直接处理对话轮次
            if let conversationId = ConversationVM.selectedConversationId {
                await processTurn(conversationId: conversationId)
            }
        }
    }

    // MARK: - 对话轮次处理

    /// 处理对话轮次
    /// - Parameter depth: 当前递归深度
    public func processTurn(conversationId: UUID, depth: Int = 0) async {
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
    /// 如果当前是分页加载且还有更多消息未加载，需要加载完整上下文
    private func getMessagesForLLM(conversationId: UUID) async -> [ChatMessage] {
        // 从数据库全量加载
        return await chatHistoryService.loadMessagesAsync(forConversationId: conversationId) ?? []
    }

    /// 获取指定会话的消息总数
    /// - Parameter conversationId: 会话 ID
    /// - Returns: 消息总数
    func getMessageCount(forConversationId conversationId: UUID) async -> Int {
        return await chatHistoryService.getMessageCount(forConversationId: conversationId)
    }

    // MARK: - 会话管理

    /// 分页加载会话消息
    /// - Parameters:
    ///   - conversationId: 会话 ID
    ///   - limit: 每页数量限制
    ///   - beforeTimestamp: 在此时间戳之前的消息（用于加载更早的消息）
    /// - Returns: (消息列表, 是否还有更多)
    func loadMessagesPage(
        forConversationId conversationId: UUID,
        limit: Int,
        beforeTimestamp: Date? = nil
    ) async -> (messages: [ChatMessage], hasMore: Bool) {
        return await chatHistoryService.loadMessagesPage(
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

    // MARK: - 模式切换通知

    public func notifyModeChangeToChat() async {
        let message: String
        switch projectVM.languagePreference {
        case .chinese:
            message = "已切换到对话模式。在此模式下，我将只与您进行对话，不会执行任何工具或修改代码。有什么问题我可以帮您解答？"
        case .english:
            message = "Switched to Chat mode. In this mode, I will only chat with you without executing any tools or modifying code. How can I help you today?"
        }

        appendMessage(ChatMessage(role: .assistant, content: message))
    }

    // MARK: - 历史记录管理

    public func clearHistory() {
        let languagePreference = projectVM.languagePreference
        let isProjectSelected = projectVM.isProjectSelected

        Task {
            let fullSystemPrompt = await promptService.buildSystemPrompt(
                languagePreference: languagePreference,
                includeContext: isProjectSelected
            )
            setMessages([ChatMessage(role: .system, content: fullSystemPrompt)], reason: "切换项目更新系统提示词")
        }
    }

    // MARK: - 项目管理

    // MARK: - 图片/附件相关逻辑已下沉到 `AgentAttachmentsVM`
}
