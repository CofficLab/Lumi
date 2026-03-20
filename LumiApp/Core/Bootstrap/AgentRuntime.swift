import Combine
import Foundation
import MagicKit
import SwiftData

/// 单窗口内 Agent 对话的**运行时状态与副作用**（`runtimeStore`、轮次入队、消息读写等）。
///
/// - **不放 `ViewModels/`**：此处不是"再包一层的协调 VM"；跨 VM 的编排入口在 `RootView`（`onChange` / `.task`）与各 `Handler`。
/// - 本类型仍持有各 VM/服务引用并执行具体业务方法，供环境注入与中间件闭包使用。
///
/// ## 相关类型
///
/// - **ConversationVM** / **MessagePendingVM**：会话与消息列表
/// - **RootView** + **RootViewContainer**：注入环境并挂接发送事件、轮次流水线等
@MainActor
final class AgentRuntime: ObservableObject, SuperLog, SuperLLMConfigProvider {
    nonisolated static let emoji = "🤖"
    nonisolated static let verbose = false

    // MARK: - 服务依赖

    /// 提示词服务
    let promptService: PromptService

    /// 供应商注册表
    let registry: ProviderRegistry

    /// 工具服务
    let toolService: ToolService

    /// 聊天历史服务
    let chatHistoryService: ChatHistoryService

    /// 会话运行态存储（按会话隔离的临时状态）
    private let runtimeStore = ConversationRuntimeStore()

    // MARK: - ViewModel 引用

    /// 消息 ViewModel
    let messageViewModel: MessagePendingVM

    /// 会话 ViewModel
    let ConversationVM: ConversationVM

    /// 消息发送 ViewModel
    var messageSenderVM: MessageQueueVM

    /// 项目 ViewModel
    let ProjectVM: ProjectVM

    /// 对话轮次 ViewModel
    let conversationTurnViewModel: ConversationTurnVM

    /// Slash 命令服务
    let slashCommandService: SlashCommandService

    /// UI 状态投影处理器（窗口场景为 `DefaultAgentUIHandler`）
    let uiHandler: AgentUIHandler

    // MARK: - 订阅管理

    private var cancellables = Set<AnyCancellable>()

    // MARK: - 初始化

    /// 初始化 AgentRuntime
    /// - Parameters:
    ///   - promptService: 提示词服务
    ///   - registry: 供应商注册表
    ///   - toolService: 工具服务
    ///   - mcpService: MCP 服务
    ///   - chatHistoryService: 聊天历史服务
    ///   - messageViewModel: 消息 ViewModel
    ///   - ConversationVM: 会话 ViewModel
    ///   - MessageSenderVM: 消息发送 ViewModel
    ///   - ProjectVM: 项目 ViewModel
    ///   - conversationTurnViewModel: 对话轮次 ViewModel
    init(
        promptService: PromptService,
        registry: ProviderRegistry,
        toolService: ToolService,
        chatHistoryService: ChatHistoryService,
        messageViewModel: MessagePendingVM,
        ConversationVM: ConversationVM,
        MessageSenderVM: MessageQueueVM,
        ProjectVM: ProjectVM,
        conversationTurnViewModel: ConversationTurnVM,
        slashCommandService: SlashCommandService,
        uiHandler: AgentUIHandler
    ) {
        self.promptService = promptService
        self.registry = registry
        self.toolService = toolService
        self.chatHistoryService = chatHistoryService
        self.messageViewModel = messageViewModel
        self.ConversationVM = ConversationVM
        self.messageSenderVM = MessageSenderVM
        self.ProjectVM = ProjectVM
        self.conversationTurnViewModel = conversationTurnViewModel
        self.slashCommandService = slashCommandService
        self.uiHandler = uiHandler

        // runtimeStore 变化需要触发刷新（例如会话列表上的 runtimeState 徽标）
        runtimeStore.objectWillChange
            .sink { [weak self] _ in
                self?.objectWillChange.send()
            }
            .store(in: &cancellables)
    }

    /// 当前会话的流式消息 ID（用于 UI 渲染）
    public var currentStreamingMessageId: UUID? {
        guard let selectedId = ConversationVM.selectedConversationId else { return nil }
        return runtimeStore.streamStateByConversation[selectedId]?.messageId
    }

    /// 当前选中会话的流式消息快照（仅用于 UI 渲染，不进历史数组）。
    public var activeStreamingMessageForSelectedConversation: ChatMessage? {
        guard let conversationId = ConversationVM.selectedConversationId,
              let state = runtimeStore.streamStateByConversation[conversationId],
              let messageId = state.messageId
        else { return nil }
        let text = runtimeStore.streamingTextByConversation[conversationId] ?? ""
        return ChatMessage(id: messageId, role: .assistant, content: text, timestamp: Date())
    }

    /// 流式渲染版本号：流式文本变化时递增，供 UI 精准订阅。
    @Published public private(set) var streamingRenderVersion: Int = 0

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
                    self.bumpStreamingRenderVersion()
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
                    self.bumpStreamingRenderVersion()
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

    func bumpStreamingRenderVersion() {
        streamingRenderVersion &+= 1
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

    private func enqueueTurnProcessing(conversationId: UUID, depth: Int) {
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

    func runtimeState(for conversationId: UUID) -> ConversationRuntimeState {
        runtimeStore.runtimeState(for: conversationId)
    }

    /// 提供给 Root 协调器创建消息发送编排器的 runtimeStore 引用。
    /// - Note: Root 负责“从队列触发执行”，因此需要访问 runtimeStore（但不负责其内部结构）。
    var runtimeStoreReference: ConversationRuntimeStore { runtimeStore }

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
            bumpStreamingRenderVersion()
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

    /// 当前项目名称（代理到 ProjectVM）
    var currentProjectName: String {
        ProjectVM.currentProjectName
    }

    /// 当前项目路径（代理到 ProjectVM）
    var currentProjectPath: String {
        ProjectVM.currentProjectPath
    }

    /// 是否已选择项目（代理到 ProjectVM）
    var isProjectSelected: Bool {
        ProjectVM.isProjectSelected
    }

    /// 当前项目的供应商 ID（代理到 ProjectVM）
    var selectedProviderId: String {
        ProjectVM.currentProviderId
    }

    /// 当前项目的模型名称（代理到 ProjectVM）
    var currentModel: String {
        ProjectVM.currentModel
    }

    /// 语言偏好（代理到 ProjectVM）
    var languagePreference: LanguagePreference {
        ProjectVM.languagePreference
    }

    /// 聊天模式（代理到 ProjectVM）
    var chatMode: ChatMode {
        ProjectVM.chatMode
    }

    /// 自动批准风险（代理到 ProjectVM）
    var autoApproveRisk: Bool {
        ProjectVM.autoApproveRisk
    }

    // MARK: - 项目管理（协调 ProjectVM）

    /// 设置供应商并保存到项目配置
    func setSelectedProviderId(_ providerId: String) {
        if isProjectSelected, !currentProjectPath.isEmpty {
            ProjectVM.saveProjectConfig(
                path: currentProjectPath,
                providerId: providerId,
                model: currentModel
            )
        } else {
            // 未选择项目时，更新全局供应商配置
            ProjectVM.setGlobalProviderId(providerId)
        }

        if Self.verbose {
            AppLogger.core.info("\(Self.t)⚙️ 已设置供应商：\(providerId)")
        }
    }

    /// 设置模型并保存到项目配置
    func setSelectedModel(_ model: String) {
        if isProjectSelected, !currentProjectPath.isEmpty {
            ProjectVM.saveProjectConfig(
                path: currentProjectPath,
                providerId: selectedProviderId,
                model: model
            )
        } else {
            // 未选择项目时，更新全局模型配置
            ProjectVM.setGlobalModel(model)
        }

        if Self.verbose {
            AppLogger.core.info("\(Self.t)⚙️ 已设置模型：\(model)")
        }
    }

    /// 获取最近使用的项目列表
    func getRecentProjects() -> [RecentProject] {
        ProjectVM.getRecentProjects()
    }

    // MARK: - 文件选择（协调 ProjectVM）

    /// 选择指定文件
    func selectFile(at url: URL) {
        ProjectVM.selectFile(at: url)
    }

    /// 清除文件选择
    func clearFileSelection() {
        ProjectVM.clearFileSelection()
    }

    // MARK: - 供应商配置

    /// 获取可用供应商列表
    var availableProviders: [ProviderInfo] {
        registry.allProviders()
    }

    /// 获取可用工具列表
    var tools: [AgentTool] {
        toolService.tools
    }

    /// 获取当前供应商配置
    func getCurrentConfig() -> LLMConfig {
        guard let providerType = registry.providerType(forId: selectedProviderId),
              registry.createProvider(id: selectedProviderId) != nil else {
            return LLMConfig.default
        }

        // API Key 使用 Keychain，首次读取时自动迁移旧明文存储
        let apiKey = APIKeyStore.shared.getWithMigration(
            forKey: providerType.apiKeyStorageKey,
            legacyLoad: { PluginStateStore.shared.string(forKey: providerType.apiKeyStorageKey) },
            legacyCleanup: {
                PluginStateStore.shared.removeObject(forKey: $0)
                PluginStateStore.shared.removeLegacyValue(forKey: $0)
            }
        )

        let config = LLMConfig(
            apiKey: apiKey,
            model: currentModel,
            providerId: selectedProviderId
        )
        return config
    }

    /// 获取指定供应商的 API Key
    func getApiKey(for providerId: String) -> String {
        guard let providerType = registry.providerType(forId: providerId) else {
            return ""
        }
        return APIKeyStore.shared.getWithMigration(
            forKey: providerType.apiKeyStorageKey,
            legacyLoad: { PluginStateStore.shared.string(forKey: providerType.apiKeyStorageKey) },
            legacyCleanup: {
                PluginStateStore.shared.removeObject(forKey: $0)
                PluginStateStore.shared.removeLegacyValue(forKey: $0)
            }
        )
    }

    /// 设置指定供应商的 API Key
    func setApiKey(_ apiKey: String, for providerId: String) {
        guard let providerType = registry.providerType(forId: providerId) else {
            return
        }
        APIKeyStore.shared.set(apiKey, forKey: providerType.apiKeyStorageKey)
        // 写入 Keychain 后清理旧明文键，避免继续落盘
        PluginStateStore.shared.removeObject(forKey: providerType.apiKeyStorageKey)
        PluginStateStore.shared.removeLegacyValue(forKey: providerType.apiKeyStorageKey)
        if Self.verbose {
            AppLogger.core.info("\(Self.t) 已设置 \(providerType.displayName) 的 API Key")
        }
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
        bumpStreamingRenderVersion()
        updateRuntimeState(for: conversationId)

        AppLogger.core.info("\(Self.t)🛑 任务已取消")
        // 重置处理状态
        setIsProcessing(false)
        setIsThinking(false, for: conversationId)
        setPendingPermissionRequest(nil)
        // 添加取消提示消息
        let cancelMessage = languagePreference == .chinese ? "⚠️ 生成已取消" : "⚠️ Generation cancelled"
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
            config: getCurrentConfig(),
            messages: messages,
            chatMode: chatMode,
            tools: tools,
            languagePreference: languagePreference,
            autoApproveRisk: autoApproveRisk
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
        switch languagePreference {
        case .chinese:
            message = "已切换到对话模式。在此模式下，我将只与您进行对话，不会执行任何工具或修改代码。有什么问题我可以帮您解答？"
        case .english:
            message = "Switched to Chat mode. In this mode, I will only chat with you without executing any tools or modifying code. How can I help you today?"
        }

        appendMessage(ChatMessage(role: .assistant, content: message))
    }

    // MARK: - 历史记录管理

    public func clearHistory() {
        let languagePreference = self.languagePreference
        let isProjectSelected = self.isProjectSelected

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
