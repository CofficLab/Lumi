import Combine
import Foundation
import SwiftUI
import MagicKit
import OSLog

/// DevAssistant 视图模型 - 主文件
/// 包含核心属性、初始化和基础功能
@MainActor
class AssistantViewModel: ObservableObject, SuperLog {
    nonisolated static let emoji = "🤖"
    nonisolated static let verbose = true

    // 发布状态

    @Published var messages: [ChatMessage] = []
    @Published var currentInput: String = ""
    @Published var isProcessing: Bool = false
    @Published var errorMessage: String?
    @Published var pendingPermissionRequest: PermissionRequest?
    @Published var depthWarning: DepthWarning?

    // 命令建议
    @Published var commandSuggestionViewModel = CommandSuggestionViewModel()

    // 工具队列

    var pendingToolCalls: [ToolCall] = []
    var currentDepth: Int = 0
    private var cancellables = Set<AnyCancellable>()

    // 取消支持
    var currentTask: Task<Void, Never>?

    // 项目信息

    @Published var currentProjectName: String = ""
    @Published var currentProjectPath: String = ""
    @Published var isProjectSelected: Bool = false

    // 风险控制

    @Published var autoApproveRisk: Bool = false {
        didSet {
            AgentProvider.shared.autoApproveRisk = autoApproveRisk
            if Self.verbose {
                os_log("\(self.t) 自动批准风险已更改：\(self.autoApproveRisk)")
            }
        }
    }

    // 语言偏好

    @Published var languagePreference: LanguagePreference = .chinese {
        didSet {
            AgentProvider.shared.languagePreference = languagePreference
            if Self.verbose {
                os_log("\(self.t) 切换语言偏好：\(self.languagePreference.displayName)")
            }
            notifyLanguageChange()
        }
    }

    // 供应商选择

    @Published var selectedProviderId: String = "anthropic" {
        didSet {
            AgentProvider.shared.selectedProviderId = selectedProviderId
            if Self.verbose {
                os_log("\(self.t) 切换供应商：\(self.selectedProviderId)")
            }
        }
    }

    // 模型选择

    @Published var selectedModel: String = "" {
        didSet {
            AgentProvider.shared.selectedModel = selectedModel
        }
    }

    // 聊天模式

    @Published var chatMode: ChatMode = .build {
        didSet {
            AgentProvider.shared.chatMode = chatMode
            if Self.verbose {
                os_log("\(self.t) 切换聊天模式：\(self.chatMode.displayName)")
            }
            if chatMode == .chat && oldValue == .build {
                Task {
                    await notifyModeChangeToChat()
                }
            }
        }
    }

    // 对话历史管理
    
    /// 当前对话会话
    @Published var currentConversation: Conversation?
    
    /// 聊天历史服务
    let chatHistoryService = ChatHistoryService.shared
    
    /// 标记是否已生成标题
    var hasGeneratedTitle: Bool = false

    // MARK: - 附件（图片上传）

    enum Attachment: Identifiable {
        case image(id: UUID, data: Data, mimeType: String, url: URL)

        var id: UUID {
            switch self {
            case .image(let id, _, _, _):
                return id
            }
        }
    }

    var pendingAttachments: [Attachment] = []

    // 供应商注册表

    let registry = ProviderRegistry.shared
    let llmService = LLMService.shared

    // 可用供应商信息

    var availableProviders: [ProviderInfo] {
        registry.allProviders()
    }

    // 提示词服务
    let promptService = PromptService.shared

    // MARK: - 工具管理器

    /// 使用 ToolManager 管理所有工具，而不是直接管理
    let toolManager = ToolManager.shared

    /// 获取所有可用工具（通过 ToolManager）
    var tools: [AgentTool] {
        return toolManager.tools
    }

    // MARK: - 初始化

    init() {
        // 同步 AgentProvider 的状态
        self.languagePreference = AgentProvider.shared.languagePreference
        self.chatMode = AgentProvider.shared.chatMode
        self.autoApproveRisk = AgentProvider.shared.autoApproveRisk
        self.selectedProviderId = AgentProvider.shared.selectedProviderId
        self.selectedModel = AgentProvider.shared.selectedModel
        self.currentProjectName = AgentProvider.shared.currentProjectName
        self.currentProjectPath = AgentProvider.shared.currentProjectPath
        self.isProjectSelected = AgentProvider.shared.isProjectSelected

        // 订阅输入变化以更新建议
        $currentInput
            .receive(on: RunLoop.main)
            .sink { [weak self] input in
                self?.commandSuggestionViewModel.updateSuggestions(for: input)
            }
            .store(in: &cancellables)

        // 初始化上下文和历史
        let initialLanguagePreference = languagePreference
        let initialIsProjectSelected = isProjectSelected
        let initialCurrentProjectName = currentProjectName
        let initialCurrentProjectPath = currentProjectPath

        Task { @MainActor in
            // 创建新对话
            await createNewConversation()
            
            let fullSystemPrompt = await promptService.buildSystemPrompt(
                languagePreference: initialLanguagePreference,
                includeContext: initialIsProjectSelected
            )

            messages.append(ChatMessage(role: .system, content: fullSystemPrompt))

            // 如果未选择项目，显示引导消息
            if !initialIsProjectSelected {
                showProjectSelectionPrompt()
            } else {
                let welcomeMsg = await promptService.getWelcomeBackMessage(
                    projectName: initialCurrentProjectName,
                    projectPath: initialCurrentProjectPath,
                    language: initialLanguagePreference
                )
                let welcomeMessage = ChatMessage(role: .assistant, content: welcomeMsg)
                messages.append(welcomeMessage)
                // 保存欢迎消息到数据库
                saveMessage(welcomeMessage)
            }
        }

        if Self.verbose {
            os_log("\(self.t)DevAssistant 视图模型已初始化")
            os_log("\(self.t) 自动批准风险设置：\(self.autoApproveRisk)")
        }
    }

    // MARK: - 项目选择提示

    func showProjectSelectionPrompt() {
        Task {
            let prompt = await promptService.getWelcomeMessage()
            messages.append(ChatMessage(role: .assistant, content: prompt))
        }
    }

    // MARK: - 取消当前任务

    /// 取消当前正在进行的任务
    func cancelCurrentTask() {
        if let task = currentTask {
            task.cancel()
            currentTask = nil
            os_log("\(self.t)🛑 任务已取消")
        }
        // 清除工具队列
        pendingToolCalls.removeAll()
        pendingPermissionRequest = nil
        // 重置处理状态
        isProcessing = false
        // 添加取消提示消息
        let cancelMessage = languagePreference == .chinese ? "⚠️ 生成已取消" : "⚠️ Generation cancelled"
        messages.append(ChatMessage(role: .assistant, content: cancelMessage))
    }

    // MARK: - SlashCommandService API

    func appendSystemMessage(_ content: String) {
        messages.append(ChatMessage(role: .assistant, content: content))
    }

    func triggerPlanningMode(task: String) {
        Task {
            let planPrompt = await promptService.getPlanningModePrompt(task: task)
            await processUserMessage(input: planPrompt)
        }
    }

    // MARK: - 语言偏好管理（内部方法）

    func notifyLanguageChange() {
        let languagePreference = self.languagePreference
        let isProjectSelected = self.isProjectSelected

        Task { @MainActor in
            let message = await promptService.getLanguageSwitchedMessage(language: languagePreference)
            let fullSystemPrompt = await promptService.buildSystemPrompt(
                languagePreference: languagePreference,
                includeContext: isProjectSelected
            )

            // 查找并更新系统消息
            if let systemIndex = messages.firstIndex(where: { $0.role == .system }) {
                messages[systemIndex] = ChatMessage(role: .system, content: fullSystemPrompt)
            } else {
                messages.insert(ChatMessage(role: .system, content: fullSystemPrompt), at: 0)
            }

            // 添加语言切换通知
            messages.append(ChatMessage(role: .assistant, content: message))
        }
    }
}

// MARK: - Preview

#Preview("App") {
    ContentLayout()
        .hideSidebar()
        .withNavigation(DevAssistantPlugin.navigationId)
        .inRootView()
        .withDebugBar()
}
