import Combine
import MagicKit
import Foundation
import OSLog
import SwiftData

/// Agent 模式提供者，管理 Agent 模式下的核心状态和服务
@MainActor
final class AgentProvider: ObservableObject, SuperLog, MessageSendingDelegate, ConversationTurnDelegate, LLMConfigProvider {
    nonisolated static let emoji = "🤖"
    nonisolated static let verbose = true

    // MARK: - 服务依赖

    /// 提示词服务
    let promptService: PromptService

    /// 供应商注册表
    let registry: ProviderRegistry

    /// 工具管理器
    let toolManager: ToolManager

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

    // MARK: - 聊天消息状态 (DevAssistant)

    /// 是否正在处理
    @Published public fileprivate(set) var isProcessing: Bool = false

    /// 错误消息
    @Published public fileprivate(set) var errorMessage: String?

    /// 待处理权限请求
    @Published public fileprivate(set) var pendingPermissionRequest: PermissionRequest?

    /// 深度警告
    @Published public fileprivate(set) var depthWarning: DepthWarning?

    // MARK: - 附件（图片上传）

    public enum Attachment: Identifiable {
        case image(id: UUID, data: Data, mimeType: String, url: URL)

        public var id: UUID {
            switch self {
            case .image(let id, _, _, _):
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
    ///   - toolManager: 工具管理器
    ///   - chatHistoryService: 聊天历史服务
    ///   - messageViewModel: 消息 ViewModel
    ///   - conversationViewModel: 会话 ViewModel
    ///   - messageSenderViewModel: 消息发送 ViewModel
    ///   - projectViewModel: 项目 ViewModel
    ///   - conversationTurnViewModel: 对话轮次 ViewModel
    init(
        promptService: PromptService,
        registry: ProviderRegistry,
        toolManager: ToolManager,
        chatHistoryService: ChatHistoryService,
        messageViewModel: MessageViewModel,
        conversationViewModel: ConversationViewModel,
        messageSenderViewModel: MessageSenderViewModel,
        projectViewModel: ProjectViewModel,
        conversationTurnViewModel: ConversationTurnViewModel
    ) {
        self.promptService = promptService
        self.registry = registry
        self.toolManager = toolManager
        self.chatHistoryService = chatHistoryService
        self.messageViewModel = messageViewModel
        self.conversationViewModel = conversationViewModel
        self.messageSenderViewModel = messageSenderViewModel
        self.projectViewModel = projectViewModel
        self.conversationTurnViewModel = conversationTurnViewModel
        loadPreferences()
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
        }
    }

    // MARK: - Setter 方法

    // MARK: - 公开 Setter 方法

    /// 设置错误消息
    func setErrorMessage(_ message: String?) {
        errorMessage = message
    }

    /// 设置是否正在处理
    func setIsProcessing(_ processing: Bool) {
        isProcessing = processing
    }

    /// 设置待处理权限请求
    func setPendingPermissionRequest(_ request: PermissionRequest?) {
        pendingPermissionRequest = request
    }

    /// 设置深度警告
    func setDepthWarning(_ warning: DepthWarning?) {
        depthWarning = warning
    }

    // MARK: - 业务方法

    // MARK: - 代理 ConversationViewModel 属性（仅供内部扩展使用）

    /// 当前选中的会话 ID（代理到 ConversationViewModel）
    ///
    /// 需要完整会话数据的视图应使用 `@Query` 根据此 ID 自行查询：
    /// ```swift
    /// @Query(filter: #Predicate<Conversation> { $0.id == agentProvider.selectedConversationId })
    /// var selectedConversation: [Conversation]
    /// ```
    var selectedConversationId: UUID? {
        conversationViewModel.selectedConversationId
    }

    /// 当前会话的消息列表（代理到 ConversationViewModel）
    var messages: [ChatMessage] {
        conversationViewModel.messages
    }

    /// 标记是否已生成标题（代理到 ConversationViewModel）
    var hasGeneratedTitle: Bool {
        conversationViewModel.hasGeneratedTitle
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
        toolManager.tools
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

    /// 加载指定对话的消息
    func loadConversation(_ conversationId: UUID) async {
        await conversationViewModel.loadConversation(conversationId)
    }

    /// 保存消息到存储
    func saveMessage(_ message: ChatMessage) {
        conversationViewModel.saveMessage(message)
    }

    // MARK: - Cancel Support

    /// 取消当前正在进行的任务
    public func cancelCurrentTask() {
        os_log("\(Self.t)🛑 任务已取消")
        // 重置处理状态
        setIsProcessing(false)
        pendingPermissionRequest = nil
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
    public func sendMessage(input: String, images: [ImageAttachment] = []) {
        let trimmed = input.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty || !pendingAttachments.isEmpty else { return }

        if Self.verbose {
            os_log("\(Self.t)🚀 用户发送消息")
        }

        // 清除之前的深度警告
        depthWarning = nil

        // 合并外部传入的图片和 pendingAttachments 中的图片
        let attachmentImages = pendingAttachments.compactMap { attachment -> ImageAttachment? in
            if case .image(_, let data, let mimeType, _) = attachment {
                return ImageAttachment(data: data, mimeType: mimeType)
            }
            return nil
        }
        let allImages = images + attachmentImages

        isProcessing = false
        errorMessage = nil
        pendingAttachments.removeAll()

        // 检查是否为支持的斜杠命令
        if SlashCommandService.shared.isSupportedSlashCommand(trimmed) {
            Task {
                let result = await SlashCommandService.shared.handle(input: trimmed, provider: self)
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
            }
            return
        }

        // 通过 MessageSenderViewModel 发送消息
        messageSenderViewModel.sendMessage(content: trimmed, images: allImages)
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
        guard let request = pendingPermissionRequest else { return }

        pendingPermissionRequest = nil

        Task {
            await conversationTurnViewModel.respondToPermissionRequest(
                allowed: allowed,
                request: request,
                languagePreference: languagePreference,
                autoApproveRisk: autoApproveRisk
            )
        }
    }

    // MARK: - ConversationTurnDelegate

    func turnDidReceiveResponse(_ response: ChatMessage) async {
        appendMessage(response)
        saveMessage(response)
    }

    func turnDidComplete() async {
        setIsProcessing(false)
    }

    func turnDidEncounterError(_ error: Error) async {
        setErrorMessage(error.localizedDescription)
        appendMessage(ChatMessage(role: .assistant, content: "Error: \(error.localizedDescription)", isError: true))
        setIsProcessing(false)
        depthWarning = nil
    }

    func turnDidReachMaxDepth(currentDepth: Int, maxDepth: Int) async {
        setErrorMessage("Max recursion depth reached.")
        setIsProcessing(false)
        depthWarning = DepthWarning(currentDepth: currentDepth, maxDepth: maxDepth, warningType: .reached)
        os_log(.error, "\(Self.t) 达到最大递归深度 (\(maxDepth))，对话终止")
    }

    func turnDidRequestPermission(_ request: PermissionRequest) async {
        pendingPermissionRequest = request
    }

    func turnDidReceiveToolResult(_ result: ChatMessage) async {
        appendMessage(result)
        saveMessage(result)
    }

    func turnDidUpdateDepthWarning(_ warning: DepthWarning?) {
        depthWarning = warning
    }

    func turnShouldContinue(depth: Int) async {
        await processTurn(depth: depth)
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

    // MARK: - MessageSendingDelegate

    /// 开始处理消息
    func messageSendingDidStart() {
        setIsProcessing(true)
    }

    /// 结束处理消息
    func messageSendingDidFinish() {
        setIsProcessing(false)
    }

    /// 处理用户消息
    /// - Parameters:
    ///   - content: 消息内容
    ///   - images: 图片附件
    func processUserMessage(content: String, images: [ImageAttachment]) async {
        if Self.verbose && !images.isEmpty {
            os_log("\(Self.t)✅ 用户消息包含 \(images.count) 张图片")
        }

        // 消息已由 MessageSenderViewModel 保存和追加
        // 直接处理对话轮次
        await processTurn()
    }
}
