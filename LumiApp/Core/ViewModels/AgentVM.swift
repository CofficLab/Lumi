import Combine
import Foundation
import MagicKit
import OSLog
import SwiftData

enum ConversationRuntimeState: String {
    case idle
    case generating
    case waitingPermission
    case error
}

/// Agent 模式 VM，管理 Agent 模式下的核心状态和服务
///
/// ## 设计原则
///
/// `AgentVM` 作为协调者，负责管理需要多个 ViewModel 协作的复杂操作。
/// 如果某个操作只涉及单个 ViewModel，应该由该 ViewModel 自己处理；
/// 如果某个操作需要协调多个 ViewModel，则应该由 `AgentVM` 提供。
///
/// ## 职责划分
///
/// - **ConversationVM**: 只维护 `selectedConversationId`，管理会话的增删改查
/// - **MessageViewModel**: 只管理消息列表的加载、追加、更新
/// - **AgentVM**: 协调多个 ViewModel，处理需要协作的复杂业务逻辑
///
/// ## 示例
///
/// ```swift
/// // 新建会话 - 需要协调多个 VM，由 AgentVM 处理
/// await agentVM.createNewConversation(projectId: projectId)
///
/// // 选择会话 - 只涉及 ConversationVM，直接调用
/// ConversationVM.setSelectedConversation(id)
///
/// // 加载消息 - 只涉及 MessageViewModel，直接调用
/// messageViewModel.loadMessages(for: conversation)
/// ```
@MainActor
final class AgentVM: ObservableObject, SuperLog, LLMConfigProvider {
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
    var MessageSenderVM: MessageSenderVM

    /// 项目 ViewModel
    let ProjectVM: ProjectVM

    /// 对话轮次 ViewModel
    let conversationTurnViewModel: ConversationTurnVM

    /// Slash 命令服务
    let slashCommandService: SlashCommandService

    /// 深度警告 ViewModel
    let depthWarningViewModel: DepthWarningVM

    /// 处理状态 ViewModel
    let processingStateViewModel: ProcessingStateVM

    /// 错误状态 ViewModel
    let errorStateViewModel: ErrorStateVM

    /// 权限请求 ViewModel
    let permissionRequestViewModel: PermissionRequestVM

    /// 思考状态 ViewModel
    let thinkingStateViewModel: ThinkingStateVM

    // MARK: - 订阅管理

    private var cancellables = Set<AnyCancellable>()

    private lazy var messageSendCoordinator = MessageSendCoordinator(
        MessageSenderVM: MessageSenderVM,
        runtimeStore: runtimeStore,
        services: .init(
            getConversationTitle: { [weak self] conversationId in
                self?.chatHistoryService.fetchConversation(id: conversationId)?.title
            },
            getCurrentConfig: { [weak self] in
                self?.getCurrentConfig() ?? .default
            },
            generateConversationTitle: { [weak self] content, config in
                guard let self else { return String(content.prefix(20)) }
                return await self.chatHistoryService.generateConversationTitle(from: content, config: config)
            },
            updateConversationTitleIfUnchanged: { [weak self] conversationId, expectedTitle, newTitle in
                return await MainActor.run {
                    guard let self,
                          let conversation = self.chatHistoryService.fetchConversation(id: conversationId),
                          conversation.title == expectedTitle else {
                        return false
                    }
                    self.chatHistoryService.updateConversationTitle(conversation, newTitle: newTitle)
                    return true
                }
            },
            isProjectSelected: { [weak self] in
                self?.ProjectVM.isProjectSelected ?? false
            },
            getProjectInfo: { [weak self] in
                (self?.ProjectVM.currentProjectName ?? "", self?.ProjectVM.currentProjectPath ?? "")
            },
            isFileSelected: { [weak self] in
                self?.ProjectVM.isFileSelected ?? false
            },
            getSelectedFileInfo: { [weak self] in
                (self?.ProjectVM.selectedFilePath ?? "", self?.ProjectVM.selectedFileContent ?? "")
            },
            getSelectedText: {
                TextSelectionManager.shared.selectedText
            },
            getMessageCount: { [weak self] conversationId in
                self?.messageViewModel.messages.count ?? 0
            }
        ),
        onUserJustSentMessage: { [weak self] in
            self?.userJustSentMessage = true
        },
        onProcessingStarted: { [weak self] conversationId in
            guard let self else { return }
            if self.ConversationVM.selectedConversationId == conversationId {
                self.processingStateViewModel.beginSending()
            }
        },
        onProcessingFinished: { [weak self] conversationId in
            guard let self else { return }
            if self.ConversationVM.selectedConversationId == conversationId {
                self.processingStateViewModel.finish()
            }
        },
        sendMessageToAgent: { [weak self] message, conversationId in
            guard let self else { return }
            await self.sendMessageToAgent(message: message, conversationId: conversationId)
        }
    )

    private lazy var conversationTurnCoordinator = ConversationTurnCoordinator(
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
        ui: .init(
            setPendingPermissionRequest: { [weak self] request, _ in
                self?.setPendingPermissionRequest(request)
            },
            setDepthWarning: { [weak self] warning, _ in
                self?.setDepthWarning(warning)
            },
            setErrorMessage: { [weak self] msg, _ in
                self?.setErrorMessage(msg)
            },
            onTurnFinishedUI: { [weak self] conversationId in
                guard let self else { return }
                self.processingStateViewModel.finish()
            },
            onTurnFailedUI: { [weak self] conversationId, _ in
                guard let self else { return }
                self.processingStateViewModel.finish()
            },
            onStreamStartedUI: { [weak self] _, conversationId in
                guard let self else { return }
                self.processingStateViewModel.markStreamStarted()
                if self.ConversationVM.selectedConversationId == conversationId {
                    self.bumpStreamingRenderVersion()
                }
            },
            onStreamFirstTokenUI: { [weak self] conversationId, ttftMs in
                guard let self else { return }
                if let ttftMs {
                    self.processingStateViewModel.markFirstToken(ttftMs: ttftMs)
                } else {
                    self.processingStateViewModel.markGenerating()
                }
            },
            onStreamFinishedUI: { [weak self] conversationId in
                guard let self else { return }
                self.setThinkingText(self.runtimeStore.thinkingTextByConversation[conversationId] ?? "", for: conversationId)
                self.setIsThinking(false, for: conversationId)
                self.processingStateViewModel.finish()
                self.runtimeStore.streamingTextByConversation[conversationId] = nil
                if self.ConversationVM.selectedConversationId == conversationId {
                    self.bumpStreamingRenderVersion()
                }
            },
            onThinkingStartedUI: { [weak self] conversationId in
                guard let self else { return }
                self.setIsThinking(true, for: conversationId)
            },
            setLastHeartbeatTime: { [weak self] date in
                self?.setLastHeartbeatTime(date)
            },
            setIsThinking: { [weak self] isThinking, cid in
                self?.setIsThinking(isThinking, for: cid)
            },
            setThinkingText: { [weak self] text, cid in
                self?.setThinkingText(text, for: cid)
            }
        ),
        onFallbackEvent: { [weak self] event in
            guard let self else { return }
            await self.handleConversationTurnEventFallback(event)
        }
    )

    // MARK: - 用户发送消息标记（用于触发 UI 滚动）

    /// 用户刚刚发送了消息的标记
    /// 当用户发送消息时设置为 true，UI 监听此属性并滚动到底部后重置为 false
    @Published public var userJustSentMessage: Bool = false

    // MARK: - 附件（图片上传）

    public enum Attachment: Identifiable {
        case image(id: UUID, data: Data, mimeType: String, url: URL)

        public var id: UUID {
            switch self {
            case let .image(id, _, _, _):
                return id
            }
        }
    }

    @Published public var pendingAttachments: [Attachment] = []

    // MARK: - 初始化

    /// 初始化 AgentVM
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
        MessageSenderVM: MessageSenderVM,
        ProjectVM: ProjectVM,
        conversationTurnViewModel: ConversationTurnVM,
        slashCommandService: SlashCommandService,
        depthWarningViewModel: DepthWarningVM,
        processingStateViewModel: ProcessingStateVM,
        errorStateViewModel: ErrorStateVM,
        permissionRequestViewModel: PermissionRequestVM,
        thinkingStateViewModel: ThinkingStateVM
    ) {
        self.promptService = promptService
        self.registry = registry
        self.toolService = toolService
        self.chatHistoryService = chatHistoryService
        self.messageViewModel = messageViewModel
        self.ConversationVM = ConversationVM
        self.MessageSenderVM = MessageSenderVM
        self.ProjectVM = ProjectVM
        self.conversationTurnViewModel = conversationTurnViewModel
        self.slashCommandService = slashCommandService
        self.depthWarningViewModel = depthWarningViewModel
        self.processingStateViewModel = processingStateViewModel
        self.errorStateViewModel = errorStateViewModel
        self.permissionRequestViewModel = permissionRequestViewModel
        self.thinkingStateViewModel = thinkingStateViewModel

        // runtimeStore 变化需要触发 AgentVM 刷新（例如会话列表上的 runtimeState 徽标）
        runtimeStore.objectWillChange
            .sink { [weak self] _ in
                self?.objectWillChange.send()
            }
            .store(in: &cancellables)

        // 监听会话选择变化
        setupConversationSelectionObserver()

        // 加载当前选中的会话消息（如果存在）
        loadInitialConversationIfNeeded()

        // 订阅消息发送事件流
        messageSendCoordinator.start()

        // 订阅对话轮次事件流
        conversationTurnCoordinator.start()

        loadPreferences()
    }

    /// 加载初始会话消息
    /// 在初始化时，如果 ConversationVM 已经恢复了上次选择的会话，立即加载消息
    private func loadInitialConversationIfNeeded() {
        if let selectedId = ConversationVM.selectedConversationId {
            if Self.verbose {
                os_log("\(Self.t)📥 [\(selectedId)] 初始化会话")
            }
            Task {
                await self.loadConversation(selectedId)
                self.refreshSessionScopedUIState(for: selectedId)
            }
        }
    }

    /// 设置会话选择监听
    /// 当 selectedConversationId 变化时，自动加载对应会话的消息，并加载该会话关联的项目
    private func setupConversationSelectionObserver() {
        ConversationVM.$selectedConversationId
            .dropFirst() // 跳过初始值
            .removeDuplicates()
            .sink { [weak self] conversationId in
                guard let self = self else { return }
                Task { @MainActor in
                    guard let id = conversationId else { return }
                    await self.loadConversation(id)
                    self.refreshSessionScopedUIState(for: id)
                    self.applyProjectForConversation(id: id)
                }
            }
            .store(in: &cancellables)
    }

    /// 根据选中会话关联的项目加载或清除当前项目（不追加聊天消息）
    private func applyProjectForConversation(id: UUID) {
        guard let conversation = ConversationVM.fetchConversation(id: id) else { return }
        let path = conversation.projectId?.trimmingCharacters(in: .whitespacesAndNewlines)
        if let path = path, !path.isEmpty {
            ProjectVM.switchProject(to: path)
            Task {
                let languagePreference = self.languagePreference
                let fullSystemPrompt = await promptService.buildSystemPrompt(
                    languagePreference: languagePreference,
                    includeContext: true
                )
                let currentMessages = messages
                if !currentMessages.isEmpty, currentMessages[0].role == .system {
                    updateMessage(ChatMessage(role: .system, content: fullSystemPrompt), at: 0)
                } else {
                    insertMessage(ChatMessage(role: .system, content: fullSystemPrompt), at: 0)
                }
                await slashCommandService.setCurrentProjectPath(path)
            }
        } else {
            ProjectVM.clearProject()
            Task {
                let languagePreference = self.languagePreference
                let fullSystemPrompt = await promptService.buildSystemPrompt(
                    languagePreference: languagePreference,
                    includeContext: true
                )
                let currentMessages = messages
                if !currentMessages.isEmpty, currentMessages[0].role == .system {
                    updateMessage(ChatMessage(role: .system, content: fullSystemPrompt), at: 0)
                } else {
                    insertMessage(ChatMessage(role: .system, content: fullSystemPrompt), at: 0)
                }
                await slashCommandService.setCurrentProjectPath(nil)
            }
        }
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

    private func bumpStreamingRenderVersion() {
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
                os_log("\(Self.t)🧵 [\(conversationId)] 新消息到达，取消旧轮次链路")
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
            os_log("\(Self.t)🧵 [\(conversationId)] 轮次入队 depth=\(depth), gen=\(generation)")
        }

        let task = Task { [weak self] in
            if let previousTask {
                await previousTask.value
            }
            guard let self else { return }
            if Self.verbose {
                os_log("\(Self.t)🧵 [\(conversationId)] 开始执行轮次 depth=\(depth), gen=\(generation)")
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

    /// 加载保存的偏好设置
    private func loadPreferences() {
        // 加载语言偏好
        if let data = AppSettingsStore.shared.data(forKey: "Agent_LanguagePreference"),
           let preference = try? JSONDecoder().decode(LanguagePreference.self, from: data) {
            ProjectVM.setLanguagePreference(preference)
        }

        // 加载聊天模式
        if let modeRaw = AppSettingsStore.shared.string(forKey: "Agent_ChatMode"),
           let mode = ChatMode(rawValue: modeRaw) {
            ProjectVM.setChatMode(mode)
        }

        // 加载自动批准风险 - 使用 bool 类型读取
        let autoApprove = AppSettingsStore.shared.bool(forKey: "Agent_AutoApproveRisk")
        ProjectVM.setAutoApproveRisk(autoApprove)

        // 加载上次选择的项目（项目切换会自动应用配置）
        if let savedPath = AppSettingsStore.shared.string(forKey: "Agent_SelectedProject") {
            ProjectVM.switchProject(to: savedPath)

            // 加载项目命令
            Task {
                await slashCommandService.setCurrentProjectPath(savedPath)
                if Self.verbose {
                    os_log("\(Self.t)📚 初始化时加载项目命令：\(savedPath)")
                }
            }
        }
    }

    // MARK: - Setter 方法

    // MARK: - 公开 Setter 方法

    /// 设置错误消息
    func setErrorMessage(_ message: String?) {
        errorStateViewModel.setErrorMessage(message)
    }

    /// 设置是否正在处理
    func setIsProcessing(_ processing: Bool) {
        processingStateViewModel.setIsProcessing(processing)
    }

    /// 设置最后心跳时间
    func setLastHeartbeatTime(_ date: Date?) {
        processingStateViewModel.setLastHeartbeatTime(date)
    }

    /// 设置思考状态
    func setIsThinking(_ thinking: Bool, for conversationId: UUID) {
        thinkingStateViewModel.setIsThinking(thinking, for: conversationId)
    }

    /// 追加思考文本
    func appendThinkingText(_ text: String, for conversationId: UUID) {
        thinkingStateViewModel.appendThinkingText(text, for: conversationId)
    }

    /// 设置思考文本
    func setThinkingText(_ text: String, for conversationId: UUID) {
        thinkingStateViewModel.setThinkingText(text, for: conversationId)
    }

    /// 设置待处理权限请求
    func setPendingPermissionRequest(_ request: PermissionRequest?) {
        permissionRequestViewModel.setPendingPermissionRequest(request)
    }

    /// 设置深度警告
    func setDepthWarning(_ warning: DepthWarning?) {
        depthWarningViewModel.setDepthWarning(warning)
    }

    /// 关闭深度警告
    func dismissDepthWarning() {
        depthWarningViewModel.dismissDepthWarning()
    }

    /// 根据当前选中会话同步会话级 UI 状态
    private func refreshSessionScopedUIState(for conversationId: UUID) {
        setIsProcessing(runtimeStore.processingConversationIds.contains(conversationId))
        setLastHeartbeatTime(runtimeStore.lastHeartbeatByConversation[conversationId] ?? nil)
        thinkingStateViewModel.setActiveConversation(conversationId)
        setIsThinking(runtimeStore.thinkingConversationIds.contains(conversationId), for: conversationId)
        setThinkingText(runtimeStore.thinkingTextByConversation[conversationId] ?? "", for: conversationId)
        setPendingPermissionRequest(runtimeStore.pendingPermissionByConversation[conversationId] ?? nil)
        setDepthWarning(runtimeStore.depthWarningByConversation[conversationId] ?? nil)
        setErrorMessage(runtimeStore.errorMessageByConversation[conversationId] ?? nil)
    }

    func runtimeState(for conversationId: UUID) -> ConversationRuntimeState {
        runtimeStore.runtimeState(for: conversationId)
    }

    private func updateRuntimeState(for conversationId: UUID) {
        runtimeStore.updateRuntimeState(for: conversationId)
    }

    private func flushPendingStreamTextIfNeeded(for conversationId: UUID, force: Bool = false) {
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

    private func flushPendingThinkingTextIfNeeded(for conversationId: UUID, force: Bool = false) {
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
            os_log("\(Self.t)⚙️ 已设置供应商：\(providerId)")
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
            os_log("\(Self.t)⚙️ 已设置模型：\(model)")
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

        // 从应用设置存储获取 API Key（按供应商维度）
        let apiKey = AppSettingsStore.shared.string(forKey: providerType.apiKeyStorageKey) ?? ""

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
        return AppSettingsStore.shared.string(forKey: providerType.apiKeyStorageKey) ?? ""
    }

    /// 设置指定供应商的 API Key
    func setApiKey(_ apiKey: String, for providerId: String) {
        guard let providerType = registry.providerType(forId: providerId) else {
            return
        }
        AppSettingsStore.shared.set(apiKey, forKey: providerType.apiKeyStorageKey)
        if Self.verbose {
            os_log("\(Self.t) 已设置 \(providerType.displayName) 的 API Key")
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

    /// 加载指定对话
    /// 协调 ConversationVM 和 MessageViewModel 完成加载（分页模式）
    func loadConversation(_ conversationId: UUID) async {
        if Self.verbose {
            os_log("\(Self.t)📥 [\(conversationId)] 开始加载对话（分页模式）")
        }

        // 切换消息发送队列到新会话
        let queueCount = MessageSenderVM.switchToConversation(conversationId)
        if Self.verbose {
            os_log("\(Self.t)🔄 [\(conversationId)] 待发送消息：\(queueCount) 条")
        }

        refreshSessionScopedUIState(for: conversationId)
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
            os_log("\(Self.t)🗑️ 开始删除对话：\(conversation.title)")
        }

        // 1. 清理该会话的待发送队列
        MessageSenderVM.removeConversationQueue(conversation.id)

        // 如果删除的是选中的对话，清理当前队列
        if ConversationVM.selectedConversationId == conversation.id {
            MessageSenderVM.clearCurrentConversationQueue()
        }

        // 2. 清理该会话的运行时状态（流式缓存、思考文本、任务管线等）
        cleanupConversationState(conversation.id)

        // 3. 删除会话记录
        ConversationVM.deleteConversation(conversation)

        if Self.verbose {
            os_log("\(Self.t)✅ 对话已删除：\(conversation.title)")
        }
    }

    // MARK: - 消息发送协调

    /// 发送单条消息到 Agent
    /// 协调 MessageViewModel 和 ConversationVM 完成消息发送
    /// - Parameter message: 要发送的消息
    func sendMessageToAgent(message: ChatMessage, conversationId: UUID) async {
        if Self.verbose {
            os_log("\(Self.t)📤 [\(conversationId)] 正在发送消息：\(message.content.max(50))")
        }

        // 1. 添加消息到消息列表
        if ConversationVM.selectedConversationId == conversationId {
            messageViewModel.appendMessage(message)
        }

        // 2. 保存到数据库
        await ConversationVM.saveMessage(message, to: conversationId)

        // 4. 串行入队处理轮次，避免阻塞事件消费循环。
        enqueueTurnProcessing(conversationId: conversationId, depth: 0)

        if Self.verbose {
            os_log("\(Self.t)✅ 消息发送完成：\(message.content.max(30))...")
        }
    }

    // MARK: - Cancel Support

    /// 取消当前正在进行的任务
    public func cancelCurrentTask() {
        guard let conversationId = ConversationVM.selectedConversationId else { return }

        MessageSenderVM.cancelProcessing(for: conversationId, clearQueue: true)
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

        os_log("\(Self.t)🛑 任务已取消")
        // 重置处理状态
        setIsProcessing(false)
        setIsThinking(false, for: conversationId)
        setPendingPermissionRequest(nil)
        permissionRequestViewModel.setPendingPermissionRequest(nil)
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

    // MARK: - 消息发送

    /// 发送消息
    /// - Parameters:
    ///   - input: 要发送的文字内容（由 InputViewModel 传入，不再从内部状态读取）
    ///   - images: 附件图片列表
    /// 发送消息
    /// - Parameters:
    ///   - input: 要发送的文字内容（由 InputViewModel 传入，不再从内部状态读取）
    ///   - images: 附件图片列表
    public func sendMessage(input: String, images: [ImageAttachment] = []) {
        let trimmed = input.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty || !pendingAttachments.isEmpty else { return }

        if Self.verbose {
            os_log("\(Self.t)🚀 用户发送消息")
        }

        // 发送全局输入事件，供 UI（如消息列表）监听并执行自动滚动等行为
        NotificationCenter.postAgentUserDidSendMessage()

        // 清除之前的深度警告
        depthWarningViewModel.dismissDepthWarning()

        // 合并外部传入的图片和 pendingAttachments 中的图片
        let attachmentImages = pendingAttachments.compactMap { attachment -> ImageAttachment? in
            if case let .image(_, data, mimeType, _) = attachment {
                return ImageAttachment(data: data, mimeType: mimeType)
            }
            return nil
        }
        let allImages = images + attachmentImages

        setIsProcessing(false)
        setErrorMessage(nil)
        if let conversationId = ConversationVM.selectedConversationId {
            runtimeStore.errorMessageByConversation[conversationId] = nil
            updateRuntimeState(for: conversationId)
        }
        pendingAttachments.removeAll()

        // 检查是否为支持的斜杠命令（异步检查包括项目命令）
        Task {
            let isCommand = await slashCommandService.isSlashCommand(trimmed)
            if isCommand {
                let result = await slashCommandService.handle(input: trimmed)
                switch result {
                case .handled:
                    setIsProcessing(false)
                case let .error(msg):
                    appendMessage(ChatMessage(role: .assistant, content: "Command Error: \(msg)", isError: true))
                    setIsProcessing(false)
                case .notHandled:
                    // 对于未处理的命令，继续通过消息队列发送
                    MessageSenderVM.sendMessage(content: trimmed, images: allImages)
                case let .systemMessage(content):
                    // 添加系统消息
                    appendSystemMessage(content)
                    setIsProcessing(false)
                case let .userMessage(content, triggerProcessing):
                    // 添加用户消息并触发处理
                    let message = ChatMessage(role: .user, content: content)
                    appendMessage(message)
                    await saveMessage(message)
                    if triggerProcessing,
                       let conversationId = ConversationVM.selectedConversationId {
                        await processTurn(conversationId: conversationId)
                    }
                    setIsProcessing(false)
                case .clearHistory:
                    clearHistory()
                    setIsProcessing(false)
                case let .triggerPlanning(task):
                    triggerPlanningMode(task: task)
                    setIsProcessing(false)
                @unknown default:
                    // 兜底处理：将未知结果视为未处理命令
                    MessageSenderVM.sendMessage(content: trimmed, images: allImages)
                    setIsProcessing(false)
                }
            } else {
                // 通过 MessageSenderVM 发送消息
                MessageSenderVM.sendMessage(content: trimmed, images: allImages)
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

    /// 创建一个新会话
    ///
    /// - 创建会话记录（带项目上下文）
    /// - 切换消息发送队列到新会话
    /// - 生成系统上下文和欢迎消息
    /// - 选中新会话
    @MainActor
    public func createNewConversation() async {
        let projectId = isProjectSelected ? currentProjectPath : nil
        let projectName = isProjectSelected ? currentProjectName : nil
        let projectPath = isProjectSelected ? currentProjectPath : nil

        let formatter = DateFormatter()
        formatter.dateFormat = "MM-dd HH:mm"

        // 1. 使用 ChatHistoryService 创建会话记录
        let conversation = chatHistoryService.createConversation(
            projectId: projectId,
            title: "新会话 " + formatter.string(from: Date())
        )

        // 2. 切换消息发送队列到新会话
        MessageSenderVM.switchToConversation(conversation.id)

        // 3. 生成系统上下文和欢迎消息
        Task { [promptService, ProjectVM, ConversationVM] in
            let systemMessage = await promptService.getSystemContextMessage(
                projectName: projectName,
                projectPath: projectPath,
                language: ProjectVM.languagePreference
            )
            if !systemMessage.isEmpty {
                let msg = ChatMessage(role: .system, content: systemMessage)
                await ConversationVM.saveMessage(msg, to: conversation.id)
            }

            let welcomeMessage = await promptService.getEmptySessionWelcomeMessage(
                projectName: projectName,
                projectPath: projectPath,
                language: ProjectVM.languagePreference
            )
            if !welcomeMessage.isEmpty {
                let msg = ChatMessage(role: .assistant, content: welcomeMessage)
                await ConversationVM.saveMessage(msg, to: conversation.id)
            }
        }

        // 4. 选中该会话
        ConversationVM.setSelectedConversation(conversation.id)
    }

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

    // MARK: - 权限响应

    public func respondToPermissionRequest(allowed: Bool) async {
        guard let conversationId = ConversationVM.selectedConversationId,
              let request = runtimeStore.pendingPermissionByConversation[conversationId] else { return }

        runtimeStore.pendingPermissionByConversation[conversationId] = nil
        permissionRequestViewModel.setPendingPermissionRequest(nil)
        updateRuntimeState(for: conversationId)

        if allowed {
            // 批准后继续执行工具
            Task {
                await conversationTurnViewModel.executeToolAndContinue(
                    request.toToolCall(),
                    conversationId: conversationId,
                    languagePreference: languagePreference
                )
            }
        } else {
            // 拒绝执行，添加拒绝消息
            let rejectMessage = ChatMessage(
                role: .tool,
                content: "用户拒绝了执行 \(request.toolName) 的权限请求",
                toolCallID: request.toolCallID
            )
            if ConversationVM.selectedConversationId == conversationId {
                appendMessage(rejectMessage)
            }
            await saveMessage(rejectMessage, conversationId: conversationId)
            updateRuntimeState(for: conversationId)
        }
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

    /// 切换到指定项目
    public func switchProjectWithPrompt(to path: String) {
        // 使用内核的 AgentVM 执行实际的项目切换
        ProjectVM.switchProject(to: path)

        // 更新本地状态（镜像 AgentVM）
        let languagePreference = self.languagePreference

        Task {
            // 刷新系统提示
            let fullSystemPrompt = await promptService.buildSystemPrompt(
                languagePreference: languagePreference,
                includeContext: true
            )

            // 更新第一条系统消息
            let currentMessages = messages
            if !currentMessages.isEmpty, currentMessages[0].role == .system {
                updateMessage(ChatMessage(role: .system, content: fullSystemPrompt), at: 0)
            } else {
                insertMessage(ChatMessage(role: .system, content: fullSystemPrompt), at: 0)
            }

            // 加载项目命令
            await slashCommandService.setCurrentProjectPath(path)

            // 添加切换项目通知（根据语言偏好）
            let projectName = self.currentProjectName
            let config = ProjectConfigStore.shared.getOrCreateConfig(for: path)
            let switchMessage: String
            switch languagePreference {
            case .chinese:
                switchMessage = """
                ✅ 已切换到项目

                **项目名称**: \(projectName)
                **项目路径**: \(path)
                **使用模型**: \(config.model.isEmpty ? "默认" : config.model) (\(config.providerId))
                """
            case .english:
                switchMessage = """
                ✅ Switched to project

                **Project**: \(projectName)
                **Path**: \(path)
                **Model**: \(config.model.isEmpty ? "Default" : config.model) (\(config.providerId))
                """
            }

            appendMessage(ChatMessage(role: .assistant, content: switchMessage))

            if Self.verbose {
                os_log("\(Self.t)📁 已切换项目：\(projectName)")
            }
        }
    }

    /// 清除当前项目，恢复到未选择任何项目的状态
    public func clearCurrentProject() {
        guard isProjectSelected else { return }
        ConversationVM.setSelectedConversation(nil)
        ProjectVM.clearProject()

        Task {
            let languagePreference = self.languagePreference
            let fullSystemPrompt = await promptService.buildSystemPrompt(
                languagePreference: languagePreference,
                includeContext: true
            )
            let currentMessages = messages
            if !currentMessages.isEmpty, currentMessages[0].role == .system {
                updateMessage(ChatMessage(role: .system, content: fullSystemPrompt), at: 0)
            } else {
                insertMessage(ChatMessage(role: .system, content: fullSystemPrompt), at: 0)
            }
            await slashCommandService.setCurrentProjectPath(nil)

            let clearMessage: String
            switch languagePreference {
            case .chinese:
                clearMessage = "✅ 已取消选择项目，当前未关联任何项目。"
            case .english:
                clearMessage = "✅ Project cleared. No project is currently selected."
            }
            appendMessage(ChatMessage(role: .assistant, content: clearMessage))
        }
    }

    // MARK: - 图片上传

    /// 处理图片上传
    public func handleImageUpload(url: URL) {
        Task.detached(priority: .userInitiated) { [weak self] in
            do {
                let imageData = try Data(contentsOf: url)
                let mimeType = Self.mimeTypeForPath(url.pathExtension)
                let attachment = Attachment.image(
                    id: UUID(),
                    data: imageData,
                    mimeType: mimeType,
                    url: url
                )
                await self?.appendImageAttachment(attachment, fileName: url.lastPathComponent, byteCount: imageData.count)
            } catch {
                os_log(.error, "\(Self.t)❌ 无法读取图片：\(error.localizedDescription)")
            }
        }
    }

    private func appendImageAttachment(_ attachment: Attachment, fileName: String, byteCount: Int) {
        if Self.verbose {
            os_log("\(Self.t)📤 添加图片附件：\(fileName) (\(byteCount) bytes)")
        }
        pendingAttachments.append(attachment)
    }

    /// 根据文件扩展名获取 MIME 类型
    private nonisolated static func mimeTypeForPath(_ pathExtension: String) -> String {
        switch pathExtension.lowercased() {
        case "jpg", "jpeg":
            return "image/jpeg"
        case "png":
            return "image/png"
        case "gif":
            return "image/gif"
        case "webp":
            return "image/webp"
        case "heic":
            return "image/heic"
        default:
            return "image/jpeg"
        }
    }

    /// 移除指定附件
    public func removeAttachment(id: UUID) {
        pendingAttachments.removeAll { $0.id == id }
    }
}
