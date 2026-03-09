import Combine
import Foundation
import MagicKit
import OSLog
import SwiftData

/// Agent 模式提供者，管理 Agent 模式下的核心状态和服务
///
/// ## 设计原则
///
/// `AgentProvider` 作为协调者，负责管理需要多个 ViewModel 协作的复杂操作。
/// 如果某个操作只涉及单个 ViewModel，应该由该 ViewModel 自己处理；
/// 如果某个操作需要协调多个 ViewModel，则应该由 `AgentProvider` 提供。
///
/// ## 职责划分
///
/// - **ConversationViewModel**: 只维护 `selectedConversationId`，管理会话的增删改查
/// - **MessageViewModel**: 只管理消息列表的加载、追加、更新
/// - **AgentProvider**: 协调多个 ViewModel，处理需要协作的复杂业务逻辑
///
/// ## 示例
///
/// ```swift
/// // 新建会话 - 需要协调多个 VM，由 AgentProvider 处理
/// await agentProvider.createNewConversation(projectId: projectId)
///
/// // 选择会话 - 只涉及 ConversationViewModel，直接调用
/// conversationViewModel.setSelectedConversation(id)
///
/// // 加载消息 - 只涉及 MessageViewModel，直接调用
/// messageViewModel.loadMessages(for: conversation)
/// ```
@MainActor
final class AgentProvider: ObservableObject, SuperLog, LLMConfigProvider {
    nonisolated static let emoji = "🤖"
    nonisolated static let verbose = true

    // MARK: - 服务依赖

    /// 提示词服务
    let promptService: PromptService

    /// 供应商注册表
    let registry: ProviderRegistry

    /// 工具服务
    let toolService: ToolService

    /// Tools ViewModel
    let toolsViewModel: ToolsViewModel

    /// 聊天历史服务
    let chatHistoryService: ChatHistoryService

    // MARK: - ViewModel 引用

    /// 消息 ViewModel
    let messageViewModel: MessageViewModel

    /// 会话 ViewModel
    let conversationViewModel: ConversationViewModel

    /// 消息发送 ViewModel
    var messageSenderViewModel: MessageSenderViewModel

    /// 项目 ViewModel
    let projectViewModel: ProjectViewModel

    /// 对话轮次 ViewModel
    let conversationTurnViewModel: ConversationTurnViewModel

    /// Slash 命令服务
    let slashCommandService: SlashCommandService

    /// 深度警告 ViewModel
    let depthWarningViewModel: DepthWarningViewModel

    /// 处理状态 ViewModel
    let processingStateViewModel: ProcessingStateViewModel

    /// 错误状态 ViewModel
    let errorStateViewModel: ErrorStateViewModel

    /// 权限请求 ViewModel
    let permissionRequestViewModel: PermissionRequestViewModel

    /// 思考状态 ViewModel
    let thinkingStateViewModel: ThinkingStateViewModel

    // MARK: - 订阅管理

    private var cancellables = Set<AnyCancellable>()

    /// 消息发送事件流任务
    private var messageSendEventTask: Task<Void, Never>?

    /// 对话轮次事件流任务
    private var conversationTurnEventTask: Task<Void, Never>?

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

    public var pendingAttachments: [Attachment] = []

    // MARK: - 初始化

    /// 初始化 AgentProvider
    /// - Parameters:
    ///   - promptService: 提示词服务
    ///   - registry: 供应商注册表
    ///   - toolService: 工具服务
    ///   - mcpService: MCP 服务
    ///   - chatHistoryService: 聊天历史服务
    ///   - messageViewModel: 消息 ViewModel
    ///   - conversationViewModel: 会话 ViewModel
    ///   - messageSenderViewModel: 消息发送 ViewModel
    ///   - projectViewModel: 项目 ViewModel
    ///   - conversationTurnViewModel: 对话轮次 ViewModel
    init(
        promptService: PromptService,
        registry: ProviderRegistry,
        toolService: ToolService,
        toolsViewModel: ToolsViewModel,
        chatHistoryService: ChatHistoryService,
        messageViewModel: MessageViewModel,
        conversationViewModel: ConversationViewModel,
        messageSenderViewModel: MessageSenderViewModel,
        projectViewModel: ProjectViewModel,
        conversationTurnViewModel: ConversationTurnViewModel,
        slashCommandService: SlashCommandService,
        depthWarningViewModel: DepthWarningViewModel,
        processingStateViewModel: ProcessingStateViewModel,
        errorStateViewModel: ErrorStateViewModel,
        permissionRequestViewModel: PermissionRequestViewModel,
        thinkingStateViewModel: ThinkingStateViewModel
    ) {
        self.promptService = promptService
        self.registry = registry
        self.toolService = toolService
        self.toolsViewModel = toolsViewModel
        self.chatHistoryService = chatHistoryService
        self.messageViewModel = messageViewModel
        self.conversationViewModel = conversationViewModel
        self.messageSenderViewModel = messageSenderViewModel
        self.projectViewModel = projectViewModel
        self.conversationTurnViewModel = conversationTurnViewModel
        self.slashCommandService = slashCommandService
        self.depthWarningViewModel = depthWarningViewModel
        self.processingStateViewModel = processingStateViewModel
        self.errorStateViewModel = errorStateViewModel
        self.permissionRequestViewModel = permissionRequestViewModel
        self.thinkingStateViewModel = thinkingStateViewModel

        // 监听会话选择变化
        setupConversationSelectionObserver()

        // 加载当前选中的会话消息（如果存在）
        loadInitialConversationIfNeeded()

        // 订阅消息发送事件流
        subscribeToMessageSendEvents()

        // 订阅对话轮次事件流
        subscribeToConversationTurnEvents()

        loadPreferences()
    }

    /// 加载初始会话消息
    /// 在初始化时，如果 ConversationViewModel 已经恢复了上次选择的会话，立即加载消息
    private func loadInitialConversationIfNeeded() {
        if let selectedId = conversationViewModel.selectedConversationId {
            if Self.verbose {
                os_log("\(Self.t)📥 [\(selectedId)] 初始化会话")
            }
            Task {
                await self.loadConversation(selectedId)
            }
        }
    }

    /// 设置会话选择监听
    /// 当 selectedConversationId 变化时，自动加载对应会话的消息
    private func setupConversationSelectionObserver() {
        conversationViewModel.$selectedConversationId
            .dropFirst() // 跳过初始值
            .removeDuplicates()
            .sink { [weak self] conversationId in
                guard let self = self, let id = conversationId else { return }
                Task { @MainActor in
                    await self.loadConversation(id)
                }
            }
            .store(in: &cancellables)
    }

    /// 订阅消息发送事件流
    /// 处理 MessageSenderViewModel 发出的发送消息事件
    private func subscribeToMessageSendEvents() {
        messageSendEventTask?.cancel()
        messageSendEventTask = Task { [weak self] in
            guard let self = self else { return }
            for await event in self.messageSenderViewModel.events {
                await self.handleMessageSendEvent(event)
            }
        }
    }

    /// 处理消息发送事件
    /// - Parameter event: 消息发送事件
    private func handleMessageSendEvent(_ event: MessageSendEvent) async {
        switch event {
        case .processingStarted:
            setIsProcessing(true)

        case .processingFinished:
            setIsProcessing(false)

        case let .sendMessage(message):
            await sendMessageToAgent(message: message)
        }
    }

    /// 订阅对话轮次事件流
    /// 处理 ConversationTurnViewModel 发出的事件
    private func subscribeToConversationTurnEvents() {
        conversationTurnEventTask?.cancel()
        conversationTurnEventTask = Task { [weak self] in
            guard let self = self else { return }
            for await event in self.conversationTurnViewModel.events {
                await self.handleConversationTurnEvent(event)
            }
        }
    }

    /// 当前流式消息ID
    public private(set) var currentStreamingMessageId: UUID?
    /// 当前流式消息索引
    private var currentStreamingMessageIndex: Int?

    /// 处理对话轮次事件
    /// - Parameter event: 对话轮次事件
    private func handleConversationTurnEvent(_ event: ConversationTurnEvent) async {
        switch event {
        case let .responseReceived(message):
            // 保存助手响应
            appendMessage(message)
            saveMessage(message)

        case let .streamStarted(messageId):
            // 流式响应开始，创建空消息占位
            currentStreamingMessageId = messageId

            // 清空上一次的思考文本
            setThinkingText("")

            let placeholderMessage = ChatMessage(
                id: messageId,
                role: .assistant,
                content: "",
                timestamp: Date()
            )
            appendMessage(placeholderMessage)
            currentStreamingMessageIndex = messages.count - 1

        case let .streamChunk(content, messageId):
            // 更新流式消息内容
            guard currentStreamingMessageId == messageId,
                  let index = currentStreamingMessageIndex,
                  index < messages.count else {
                return
            }

            // 获取当前消息并追加内容
            var currentMessage = messages[index]
            currentMessage.content += content

            // 更新消息（使用内部方法避免触发过多UI更新）
            updateMessage(currentMessage, at: index)

        case let .streamEvent(eventType, content, rawEvent, messageId):
            // 处理流式事件（用于调试和展示所有事件）

            // 首先记录所有事件
            if Self.verbose {
                let contentPreview = content.isEmpty ? "(空)" : "\(content.prefix(50))..."
                os_log("\(Self.t)📨 收到事件 [\(eventType.rawValue)]: \(contentPreview)")
            }

            // 处理心跳事件 - 更新心跳时间触发动画
            if eventType == .ping {
                setLastHeartbeatTime(Date())
                return
            }

            // 处理思考增量事件 - 累积思考文本
            if eventType == .thinkingDelta {
                // 累积思考文本
                if !content.isEmpty {
                    appendThinkingText(content)
                }
                return
            }

            // 处理内容块开始事件 - 不追加到消息内容
            if eventType == .contentBlockStart {
                // 从 rawEvent 判断是否是思考块
                if rawEvent.contains("\"type\":\"thinking\"") || rawEvent.contains("thinking") {
                    setIsThinking(true)
                    if Self.verbose {
                        os_log("\(Self.t)🤔 思考开始")
                    }
                }
                return
            }

            // 处理内容块停止事件 - 不追加到消息内容
            if eventType == .contentBlockStop {
                if Self.verbose {
                    os_log("\(Self.t)✅ 内容块结束")
                }
                return
            }

            // 处理签名增量事件 - 不追加到消息内容
            if eventType == .signatureDelta {
                if Self.verbose {
                    os_log("\(Self.t)🔏 收到签名")
                }
                return
            }

            // 处理 input_json_delta 事件 - 不追加到消息内容
            if eventType == .inputJsonDelta {
                return
            }

            // 处理消息增量事件 - 不追加到消息内容（只包含停止原因等元数据）
            if eventType == .messageDelta {
                if Self.verbose {
                    os_log("\(Self.t)📊 消息增量: \(content)")
                }
                return
            }

            guard currentStreamingMessageId == messageId,
                  let index = currentStreamingMessageIndex,
                  index < messages.count else {
                return
            }

            // 只追加文本增量事件的内容到消息
            if eventType == .textDelta {
                // 获取当前消息并追加事件内容
                var currentMessage = messages[index]
                currentMessage.content += content

                // 更新消息
                updateMessage(currentMessage, at: index)
            }

        case let .streamFinished(message):
            // 流式响应结束，将思考过程附加到消息
            var finalMessage = message
            if !thinkingStateViewModel.thinkingText.isEmpty {
                finalMessage.thinkingContent = thinkingStateViewModel.thinkingText
                if Self.verbose {
                    os_log("\(Self.t)💭 保存思考过程到消息: \(self.thinkingStateViewModel.thinkingText.prefix(50))...")
                }
            } else {
                if Self.verbose {
                    os_log("\(Self.t)⚠️ 思考文本为空，不保存思考过程")
                }
            }

            // 流式响应结束，保存最终消息
            if let index = currentStreamingMessageIndex, index < messages.count {
                // 更新为最终消息（包含工具调用等信息）
                updateMessage(finalMessage, at: index)
                // 保存到数据库
                saveMessage(finalMessage)
            }

            // 清理流式状态
            currentStreamingMessageId = nil
            currentStreamingMessageIndex = nil

            // 重置思考状态（但保留思考文本，以便在界面上显示）
            setIsThinking(false)

        case let .toolResultReceived(result):
            // 保存工具结果
            appendMessage(result)
            saveMessage(result)

        case let .permissionRequested(request):
            // 设置待处理权限请求
            setPendingPermissionRequest(request)

        case let .maxDepthReached(currentDepth, maxDepth):
            // 处理达到最大深度
            let warning = DepthWarning(
                currentDepth: currentDepth,
                maxDepth: maxDepth,
                warningType: .reached
            )
            setDepthWarning(warning)
            setIsProcessing(false)

            // 清理流式状态
            currentStreamingMessageId = nil
            currentStreamingMessageIndex = nil

        case .completed:
            // 轮次完成
            setIsProcessing(false)

            // 清理流式状态
            currentStreamingMessageId = nil
            currentStreamingMessageIndex = nil

        case let .error(error):
            // 处理错误
            setErrorMessage(error.localizedDescription)
            setIsProcessing(false)

            // 清理流式状态
            currentStreamingMessageId = nil
            currentStreamingMessageIndex = nil

        case let .shouldContinue(depth):
            // 继续下一轮
            await processTurn(depth: depth)
        }
    }

    // MARK: - 偏好设置加载

    /// 加载保存的偏好设置
    private func loadPreferences() {
        // 加载语言偏好
        if let data = UserDefaults.standard.data(forKey: "Agent_LanguagePreference"),
           let preference = try? JSONDecoder().decode(LanguagePreference.self, from: data) {
            projectViewModel.setLanguagePreference(preference)
        }

        // 加载聊天模式
        if let modeRaw = UserDefaults.standard.string(forKey: "Agent_ChatMode"),
           let mode = ChatMode(rawValue: modeRaw) {
            projectViewModel.setChatMode(mode)
        }

        // 加载自动批准风险 - 使用 bool 类型读取
        let autoApprove = UserDefaults.standard.bool(forKey: "Agent_AutoApproveRisk")
        projectViewModel.setAutoApproveRisk(autoApprove)

        // 加载上次选择的项目（项目切换会自动应用配置）
        if let savedPath = UserDefaults.standard.string(forKey: "Agent_SelectedProject") {
            projectViewModel.switchProject(to: savedPath)
            
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
    func setIsThinking(_ thinking: Bool) {
        thinkingStateViewModel.setIsThinking(thinking)
    }

    /// 追加思考文本
    func appendThinkingText(_ text: String) {
        thinkingStateViewModel.appendThinkingText(text)
    }

    /// 设置思考文本
    func setThinkingText(_ text: String) {
        thinkingStateViewModel.setThinkingText(text)
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

    // MARK: - 业务方法

    /// 当前会话的消息列表（代理到 MessageViewModel）
    var messages: [ChatMessage] {
        messageViewModel.messages
    }

    /// 标记是否已生成标题（代理到 MessageViewModel）
    var hasGeneratedTitle: Bool {
        messageViewModel.hasGeneratedTitle
    }

    // MARK: - 代理 ProjectViewModel 属性（仅供内部扩展使用）

    /// 当前项目名称（代理到 ProjectViewModel）
    var currentProjectName: String {
        projectViewModel.currentProjectName
    }

    /// 当前项目路径（代理到 ProjectViewModel）
    var currentProjectPath: String {
        projectViewModel.currentProjectPath
    }

    /// 是否已选择项目（代理到 ProjectViewModel）
    var isProjectSelected: Bool {
        projectViewModel.isProjectSelected
    }

    /// 当前项目的供应商 ID（代理到 ProjectViewModel）
    var selectedProviderId: String {
        projectViewModel.currentProviderId
    }

    /// 当前项目的模型名称（代理到 ProjectViewModel）
    var currentModel: String {
        projectViewModel.currentModel
    }

    /// 语言偏好（代理到 ProjectViewModel）
    var languagePreference: LanguagePreference {
        projectViewModel.languagePreference
    }

    /// 聊天模式（代理到 ProjectViewModel）
    var chatMode: ChatMode {
        projectViewModel.chatMode
    }

    /// 自动批准风险（代理到 ProjectViewModel）
    var autoApproveRisk: Bool {
        projectViewModel.autoApproveRisk
    }

    // MARK: - 项目管理（协调 ProjectViewModel）

    /// 设置供应商并保存到项目配置
    func setSelectedProviderId(_ providerId: String) {
        guard isProjectSelected, !currentProjectPath.isEmpty else { return }

        projectViewModel.saveProjectConfig(
            path: currentProjectPath,
            providerId: providerId,
            model: currentModel
        )

        if Self.verbose {
            os_log("\(Self.t)⚙️ 已设置供应商：\(providerId)")
        }
    }

    /// 设置模型并保存到项目配置
    func setSelectedModel(_ model: String) {
        guard isProjectSelected, !currentProjectPath.isEmpty else { return }

        projectViewModel.saveProjectConfig(
            path: currentProjectPath,
            providerId: selectedProviderId,
            model: model
        )

        if Self.verbose {
            os_log("\(Self.t)⚙️ 已设置模型：\(model)")
        }
    }

    /// 获取最近使用的项目列表
    func getRecentProjects() -> [RecentProject] {
        projectViewModel.getRecentProjects()
    }

    // MARK: - 文件选择（协调 ProjectViewModel）

    /// 选择指定文件
    func selectFile(at url: URL) {
        projectViewModel.selectFile(at: url)
    }

    /// 清除文件选择
    func clearFileSelection() {
        projectViewModel.clearFileSelection()
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

        // 从 UserDefaults 获取 API Key
        let apiKey = UserDefaults.standard.string(forKey: providerType.apiKeyStorageKey) ?? ""

        return LLMConfig(
            apiKey: apiKey,
            model: currentModel,
            providerId: selectedProviderId
        )
    }

    /// 获取指定供应商的 API Key
    func getApiKey(for providerId: String) -> String {
        guard let providerType = registry.providerType(forId: providerId) else {
            return ""
        }
        return UserDefaults.standard.string(forKey: providerType.apiKeyStorageKey) ?? ""
    }

    /// 设置指定供应商的 API Key
    func setApiKey(_ apiKey: String, for providerId: String) {
        guard let providerType = registry.providerType(forId: providerId) else {
            return
        }
        UserDefaults.standard.set(apiKey, forKey: providerType.apiKeyStorageKey)
        if Self.verbose {
            os_log("\(Self.t) 已设置 \(providerType.displayName) 的 API Key")
        }
    }

    // MARK: - 消息便捷方法（代理到 ConversationViewModel）

    /// 追加消息到列表
    func appendMessage(_ message: ChatMessage) {
        messageViewModel.appendMessageInternal(message)
    }

    /// 插入消息到指定位置
    func insertMessage(_ message: ChatMessage, at index: Int) {
        messageViewModel.insertMessageInternal(message, at: index)
    }

    /// 更新指定位置的消息
    func updateMessage(_ message: ChatMessage, at index: Int) {
        messageViewModel.updateMessageInternal(message, at: index)
    }

    /// 设置聊天消息列表
    func setMessages(_ messages: [ChatMessage]) {
        messageViewModel.setMessagesInternal(messages)
    }

    /// 设置标题生成标记
    func setHasGeneratedTitle(_ value: Bool) {
        messageViewModel.setHasGeneratedTitleInternal(value)
    }

    /// 加载指定对话
    /// 协调 ConversationViewModel 和 MessageViewModel 完成加载
    func loadConversation(_ conversationId: UUID) async {
        if Self.verbose {
            os_log("\(Self.t)📥 [\(conversationId)] 开始加载对话")
        }

        // 从数据库获取对话
        guard let conversation = chatHistoryService.fetchConversation(id: conversationId) else {
            os_log(.error, "\(Self.t)❌ [\(conversationId)] 对话不存在")
            return
        }

        // 切换消息发送队列到新会话
        let queueCount = messageSenderViewModel.switchToConversation(conversation.id)
        if Self.verbose {
            os_log("\(Self.t)🔄 [\(conversationId)] 待发送消息：\(queueCount) 条")
        }

        // 加载消息到 MessageViewModel
        _ = messageViewModel.loadMessages(for: conversation)

        if Self.verbose {
            os_log("\(Self.t)✅ [\(conversation.id)] 共 \(self.messageViewModel.messages.count) 条消息")
        }
    }

    /// 保存消息到存储
    func saveMessage(_ message: ChatMessage) {
        conversationViewModel.saveMessage(message)
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
        messageSenderViewModel.removeConversationQueue(conversation.id)

        // 如果删除的是选中的对话，清理当前队列
        if conversationViewModel.selectedConversationId == conversation.id {
            messageSenderViewModel.clearCurrentConversationQueue()
        }

        // 2. 删除会话记录
        conversationViewModel.deleteConversation(conversation)

        if Self.verbose {
            os_log("\(Self.t)✅ 对话已删除：\(conversation.title)")
        }
    }

    // MARK: - 会话管理

    /// 创建新对话
    ///
    /// 协调多个 ViewModel 完成新会话创建：
    /// 1. 创建会话记录
    /// 2. 选中该会话
    /// 3. 切换消息队列
    /// 4. 获取并保存欢迎消息
    ///
    /// - Parameters:
    ///   - projectId: 关联的项目 ID（可选）
    ///   - projectName: 项目名称（可选，用于生成欢迎消息）
    ///   - projectPath: 项目路径（可选，用于生成欢迎消息）
    func createNewConversation(
        projectId: String? = nil,
        projectName: String? = nil,
        projectPath: String? = nil
    ) async {
        if Self.verbose {
            os_log("\(Self.t)🚀 开始创建新会话")
        }

        // 1. 创建会话记录
        let formatter = DateFormatter()
        formatter.dateFormat = "MM-dd HH:mm"
        let newConversation = chatHistoryService.createConversation(
            projectId: projectId,
            title: "新会话 " + formatter.string(from: Date())
        )

        // 2. 选中该会话（会触发监听加载消息）
        conversationViewModel.setSelectedConversation(newConversation.id)

        // 3. 切换消息发送队列到新会话
        messageSenderViewModel.switchToConversation(newConversation.id)

        // 4. 清空当前消息列表并获取系统上下文消息和欢迎消息
        messageViewModel.clearMessages()

        // 4.1 添加系统上下文消息（设置项目上下文）
        let systemMessage = await promptService.getSystemContextMessage(
            projectName: projectName,
            projectPath: projectPath,
            language: languagePreference
        )
        if !systemMessage.isEmpty {
            let sysMsg = ChatMessage(role: .system, content: systemMessage)
            if let savedSystemMsg = chatHistoryService.saveMessage(sysMsg, to: newConversation) {
                messageViewModel.appendMessageInternal(savedSystemMsg)
            }
        }

        // 4.2 添加欢迎消息
        let welcomeMessage = await promptService.getEmptySessionWelcomeMessage(
            projectName: projectName,
            projectPath: projectPath,
            language: languagePreference,
            conversationId: newConversation.id
        )

        if !welcomeMessage.isEmpty {
            let welcomeMsg = ChatMessage(role: .assistant, content: welcomeMessage)
            if let savedMessage = chatHistoryService.saveMessage(welcomeMsg, to: newConversation) {
                messageViewModel.appendMessageInternal(savedMessage)
            }
        }

        if Self.verbose {
            os_log("\(Self.t)✅ [\(newConversation.id)] 新会话创建完成")
        }
    }

    // MARK: - 消息发送协调

    /// 发送单条消息到 Agent
    /// 协调 MessageViewModel 和 ConversationViewModel 完成消息发送
    /// - Parameter message: 要发送的消息
    func sendMessageToAgent(message: ChatMessage) async {
        if Self.verbose {
            os_log("\(Self.t)📤 正在发送消息：\(message.content.max(50))")
        }

        // 1. 添加消息到消息列表
        messageViewModel.appendMessageInternal(message)

        // 2. 保存到数据库
        conversationViewModel.saveMessage(message)

        // 3. 启动会话标题生成（如果需要）
        startConversationTitleGenerationIfNeeded(message: message)

        // 4. 处理消息（等待完成）
        await processTurn()

        if Self.verbose {
            os_log("\(Self.t)✅ 消息发送完成：\(message.content.max(30))...")
        }
    }

    /// 启动会话标题生成（如果需要）
    /// - Parameter message: 用户消息
    private func startConversationTitleGenerationIfNeeded(message: ChatMessage) {
        // 只处理用户消息
        guard message.role == .user else { return }

        // 获取当前对话 ID
        guard let conversationId = conversationViewModel.selectedConversationId else { return }

        // 获取会话以检查标题
        guard let conversation = chatHistoryService.fetchConversation(id: conversationId) else { return }

        // 检查是否满足生成标题的条件
        guard conversation.title.hasPrefix("新会话 "),
              !messageViewModel.hasGeneratedTitle else {
            return
        }

        // 标记已生成标题，防止重复生成
        messageViewModel.setHasGeneratedTitleInternal(true)

        // 获取 LLM 配置
        let config = getCurrentConfig()

        // 在后台 Task 中执行标题生成
        Task.detached(priority: .utility) { [weak self] in
            guard let self = self else { return }
            await self.chatHistoryService.autoGenerateConversationTitleIfNeeded(
                conversationId: conversationId,
                userMessageContent: message.content,
                config: config
            )
        }
    }

    // MARK: - Cancel Support

    /// 取消当前正在进行的任务
    public func cancelCurrentTask() {
        os_log("\(Self.t)🛑 任务已取消")
        // 重置处理状态
        setIsProcessing(false)
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
            await processTurn()
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
        pendingAttachments.removeAll()

        // 检查是否为支持的斜杠命令（异步检查包括项目命令）
        Task {
            let isCommand = await slashCommandService.isSlashCommand(trimmed)
            if isCommand {
                let result = await slashCommandService.handle(input: trimmed, provider: self)
                switch result {
                case .handled:
                    setIsProcessing(false)
                case let .error(msg):
                    appendMessage(ChatMessage(role: .assistant, content: "Command Error: \(msg)", isError: true))
                    setIsProcessing(false)
                case .notHandled:
                    // 对于未处理的命令，继续通过消息队列发送
                    messageSenderViewModel.sendMessage(content: trimmed, images: allImages)
                }
            } else {
                // 通过 MessageSenderViewModel 发送消息
                messageSenderViewModel.sendMessage(content: trimmed, images: allImages)
            }
        }
    }


    // MARK: - 对话轮次处理

    /// 处理对话轮次
    /// - Parameter depth: 当前递归深度
    public func processTurn(depth: Int = 0) async {
        await conversationTurnViewModel.processTurn(
            depth: depth,
            config: getCurrentConfig(),
            messages: messages,
            chatMode: chatMode,
            tools: tools,
            languagePreference: languagePreference,
            autoApproveRisk: autoApproveRisk
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

    public func respondToPermissionRequest(allowed: Bool) {
        guard let request = permissionRequestViewModel.pendingPermissionRequest else { return }

        permissionRequestViewModel.setPendingPermissionRequest(nil)

        if allowed {
            // 批准后继续执行工具
            Task {
                await conversationTurnViewModel.executeToolAndContinue(
                    request.toToolCall(),
                    languagePreference: languagePreference
                )
            }
        } else {
            // 拒绝执行，添加拒绝消息
            let rejectMessage = ChatMessage(
                role: .user,
                content: "用户拒绝了执行 \(request.toolName) 的权限请求",
                toolCallID: request.toolCallID
            )
            appendMessage(rejectMessage)
            saveMessage(rejectMessage)
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
            setMessages([ChatMessage(role: .system, content: fullSystemPrompt)])
        }
    }

    // MARK: - 项目管理

    /// 切换到指定项目
    public func switchProjectWithPrompt(to path: String) {
        // 使用内核的 AgentProvider 执行实际的项目切换
        projectViewModel.switchProject(to: path)

        // 更新本地状态（镜像 AgentProvider）
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

    // MARK: - 图片上传

    /// 处理图片上传
    public func handleImageUpload(url: URL) {
        do {
            let imageData = try Data(contentsOf: url)
            let mimeType = mimeTypeForPath(url.pathExtension)

            if Self.verbose {
                os_log("\(Self.t)📤 添加图片附件：\(url.lastPathComponent) (\(imageData.count) bytes)")
            }

            let attachment = Attachment.image(
                id: UUID(),
                data: imageData,
                mimeType: mimeType,
                url: url
            )
            pendingAttachments.append(attachment)
        } catch {
            os_log(.error, "\(Self.t)❌ 无法读取图片：\(error.localizedDescription)")
        }
    }

    /// 根据文件扩展名获取 MIME 类型
    private func mimeTypeForPath(_ pathExtension: String) -> String {
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

    /// 清空所有附件
    public func clearAttachments() {
        pendingAttachments.removeAll()
    }
}
