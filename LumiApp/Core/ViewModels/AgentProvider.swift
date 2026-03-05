import Combine
import MagicKit
import Foundation
import OSLog
import SwiftData

/// Agent 模式提供者，管理 Agent 模式下的核心状态和服务
@MainActor
final class AgentProvider: ObservableObject, SuperLog {
    nonisolated static let emoji = "🤖"
    nonisolated static let verbose = true

    // MARK: - 服务依赖

    /// 聊天历史服务
    let chatHistoryService = ChatHistoryService.shared

    /// 提示词服务
    let promptService = PromptService.shared

    /// 供应商注册表
    let registry = ProviderRegistry.shared

    /// LLM 服务
    let llmService = LLMService.shared

    /// 工具管理器
    let toolManager = ToolManager.shared

    // MARK: - ViewModel 引用

    /// 消息 ViewModel
    let messageViewModel: MessageViewModel

    /// 会话 ViewModel
    let conversationViewModel: ConversationViewModel

    /// 消息发送 ViewModel
    let messageSenderViewModel: MessageSenderViewModel

    /// 项目 ViewModel
    let projectViewModel: ProjectViewModel

    // MARK: - 聊天消息状态 (DevAssistant)

    /// 当前输入内容
    @Published public fileprivate(set) var currentInput: String = ""

    /// 是否正在处理
    @Published public fileprivate(set) var isProcessing: Bool = false

    /// 错误消息
    @Published public fileprivate(set) var errorMessage: String?

    /// 待处理权限请求
    @Published public fileprivate(set) var pendingPermissionRequest: PermissionRequest?

    /// 深度警告
    @Published public fileprivate(set) var depthWarning: DepthWarning?

    /// 待处理工具调用队列
    var pendingToolCalls: [ToolCall] = []
    var currentDepth: Int = 0

    /// 当前任务
    var currentTask: Task<Void, Never>?

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

    // MARK: - 供应商选择

    @Published fileprivate(set) var selectedProviderId: String = "anthropic" {
        didSet {
            UserDefaults.standard.set(selectedProviderId, forKey: "Agent_SelectedProvider")
        }
    }

    /// 当前选择的模型
    @Published fileprivate(set) var selectedModel: String = "" {
        didSet {
            UserDefaults.standard.set(selectedModel, forKey: "Agent_SelectedModel")
        }
    }

    // MARK: - 初始化

    /// 初始化 AgentProvider
    /// - Parameters:
    ///   - messageViewModel: 消息 ViewModel
    ///   - conversationViewModel: 会话 ViewModel
    ///   - messageSenderViewModel: 消息发送 ViewModel
    ///   - projectViewModel: 项目 ViewModel
    init(
        messageViewModel: MessageViewModel,
        conversationViewModel: ConversationViewModel,
        messageSenderViewModel: MessageSenderViewModel,
        projectViewModel: ProjectViewModel
    ) {
        self.messageViewModel = messageViewModel
        self.conversationViewModel = conversationViewModel
        self.messageSenderViewModel = messageSenderViewModel
        self.projectViewModel = projectViewModel
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

        // 加载自动批准风险
        if let autoApprove = UserDefaults.standard.string(forKey: "Agent_AutoApproveRisk") {
            projectViewModel.setAutoApproveRisk(autoApprove == "true")
        }

        // 加载供应商选择
        selectedProviderId = UserDefaults.standard.string(forKey: "Agent_SelectedProvider") ?? "anthropic"

        // 加载模型选择
        selectedModel = UserDefaults.standard.string(forKey: "Agent_SelectedModel") ?? ""

        // 加载上次选择的项目
        if let savedPath = UserDefaults.standard.string(forKey: "Agent_SelectedProject") {
            switchProject(to: savedPath)
        }
    }

    // MARK: - Setter 方法

    // MARK: - 内部 Setter 方法（仅供扩展文件使用）

    /// 设置项目信息（内部使用）
    func setCurrentProjectInfo(name: String, path: String, selected: Bool) {
        projectViewModel.setCurrentProjectInfo(name: name, path: path, selected: selected)
    }

    /// 设置文件信息（内部使用）
    func setSelectedFileInfo(url: URL?, path: String, content: String, selected: Bool) {
        projectViewModel.setSelectedFileInfo(url: url, path: path, content: content, selected: selected)
    }

    /// 设置文件内容（内部使用）
    func setSelectedFileContent(_ content: String) {
        projectViewModel.setSelectedFileContent(content)
    }

    /// 设置聊天消息状态（内部使用）
    func setChatMessageState(input: String? = nil, processing: Bool? = nil, errorMessage: String? = nil) {
        if let input = input {
            currentInput = input
        }
        if let processing = processing {
            isProcessing = processing
        }
        if let errorMessage = errorMessage {
            self.errorMessage = errorMessage
        }
    }

    /// 设置权限和深度警告状态（内部使用）
    func setPermissionAndWarningState(permissionRequest: PermissionRequest? = nil, depthWarning: DepthWarning? = nil) {
        if let permissionRequest = permissionRequest {
            pendingPermissionRequest = permissionRequest
        }
        if let depthWarning = depthWarning {
            self.depthWarning = depthWarning
        }
    }

    /// 设置权限请求（内部使用）
    func setPermissionRequest(_ request: PermissionRequest) {
        pendingPermissionRequest = request
    }

    // MARK: - 公开 Setter 方法

    /// 设置语言偏好
    func setLanguagePreference(_ preference: LanguagePreference) {
        projectViewModel.setLanguagePreference(preference)
    }

    /// 设置聊天模式
    func setChatMode(_ mode: ChatMode) {
        projectViewModel.setChatMode(mode)
    }

    /// 设置自动批准风险
    func setAutoApproveRisk(_ enabled: Bool) {
        projectViewModel.setAutoApproveRisk(enabled)
    }

    /// 设置供应商
    func setSelectedProviderId(_ providerId: String) {
        selectedProviderId = providerId
    }

    /// 设置模型
    func setSelectedModel(_ model: String) {
        selectedModel = model
    }

    /// 设置当前输入
    func setCurrentInput(_ input: String) {
        currentInput = input
    }

    /// 追加文本到当前输入
    func appendInput(_ text: String) {
        currentInput += text
    }

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

    /// 当前会话（代理到 ConversationViewModel）
    var currentConversation: Conversation? {
        conversationViewModel.currentConversation
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

    /// 是否已选择文件（代理到 ProjectViewModel）
    var isFileSelected: Bool {
        projectViewModel.isFileSelected
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
}
