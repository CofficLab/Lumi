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

    /// 全局单例
    static let shared = AgentProvider()

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

    // MARK: - 项目信息

    /// 当前项目名称
    @Published fileprivate(set) var currentProjectName: String = ""

    /// 当前项目路径
    @Published fileprivate(set) var currentProjectPath: String = ""

    /// 是否已选择项目
    @Published fileprivate(set) var isProjectSelected: Bool = false

    // MARK: - 当前选择的文件

    /// 当前选择的文件 URL
    @Published fileprivate(set) var selectedFileURL: URL?

    /// 当前选择的文件路径
    @Published fileprivate(set) var selectedFilePath: String = ""

    /// 当前选择的文件内容
    @Published fileprivate(set) var selectedFileContent: String = ""

    /// 是否已选择文件
    @Published fileprivate(set) var isFileSelected: Bool = false

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

    // MARK: - 语言偏好

    @Published fileprivate(set) var languagePreference: LanguagePreference = .chinese {
        didSet {
            if let encoded = try? JSONEncoder().encode(languagePreference) {
                UserDefaults.standard.set(encoded, forKey: "Agent_LanguagePreference")
            }
        }
    }

    // MARK: - 聊天模式

    @Published fileprivate(set) var chatMode: ChatMode = .build {
        didSet {
            UserDefaults.standard.set(chatMode.rawValue, forKey: "Agent_ChatMode")
        }
    }

    // MARK: - 自动批准风险

    @Published fileprivate(set) var autoApproveRisk: Bool = {
        UserDefaults.standard.bool(forKey: "Agent_AutoApproveRisk")
    }() {
        didSet {
            UserDefaults.standard.set(autoApproveRisk, forKey: "Agent_AutoApproveRisk")
        }
    }

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

    private init() {
        loadPreferences()
    }

    // MARK: - 偏好设置加载

    /// 加载保存的偏好设置
    private func loadPreferences() {
        // 加载语言偏好
        if let data = UserDefaults.standard.data(forKey: "Agent_LanguagePreference"),
           let preference = try? JSONDecoder().decode(LanguagePreference.self, from: data) {
            languagePreference = preference
        }

        // 加载聊天模式
        if let modeRaw = UserDefaults.standard.string(forKey: "Agent_ChatMode"),
           let mode = ChatMode(rawValue: modeRaw) {
            chatMode = mode
        }

        // 加载自动批准风险
        autoApproveRisk = UserDefaults.standard.bool(forKey: "Agent_AutoApproveRisk")

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
        currentProjectName = name
        currentProjectPath = path
        isProjectSelected = selected
    }

    /// 设置文件信息（内部使用）
    func setSelectedFileInfo(url: URL?, path: String, content: String, selected: Bool) {
        selectedFileURL = url
        selectedFilePath = path
        selectedFileContent = content
        isFileSelected = selected
    }

    /// 设置文件内容（内部使用）
    func setSelectedFileContent(_ content: String) {
        selectedFileContent = content
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
        languagePreference = preference
    }

    /// 设置聊天模式
    func setChatMode(_ mode: ChatMode) {
        chatMode = mode
    }

    /// 设置自动批准风险
    func setAutoApproveRisk(_ enabled: Bool) {
        autoApproveRisk = enabled
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

    // MARK: - 代理 ConversationViewModel 属性（仅供内部扩展使用）

    /// 当前会话（代理到 ConversationViewModel）
    var currentConversation: Conversation? {
        ConversationViewModel.shared.currentConversation
    }

    /// 当前会话的消息列表（代理到 ConversationViewModel）
    var messages: [ChatMessage] {
        ConversationViewModel.shared.messages
    }

    /// 标记是否已生成标题（代理到 ConversationViewModel）
    var hasGeneratedTitle: Bool {
        ConversationViewModel.shared.hasGeneratedTitle
    }
}
