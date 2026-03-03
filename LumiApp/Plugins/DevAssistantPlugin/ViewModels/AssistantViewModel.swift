import Combine
import Foundation
import SwiftUI
import MagicKit
import OSLog

/// DevAssistant 视图模型 - 主文件
/// 包含核心属性、初始化和基础功能
///
/// 注意：通用状态已迁移到 AgentProvider，本类只保留视图特定状态
@MainActor
class AssistantViewModel: ObservableObject, SuperLog {
    nonisolated static let emoji = "🤖"
    nonisolated static let verbose = true

    // MARK: - 视图特定状态

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

    // MARK: - 计算属性（代理到 AgentProvider）

    /// 当前对话会话
    var currentConversation: Conversation? {
        get { AgentProvider.shared.currentConversation }
        set { AgentProvider.shared.currentConversation = newValue }
    }

    /// 是否已生成标题
    var hasGeneratedTitle: Bool {
        get { AgentProvider.shared.hasGeneratedTitle }
        set { AgentProvider.shared.hasGeneratedTitle = newValue }
    }

    /// 语言偏好
    var languagePreference: LanguagePreference {
        get { AgentProvider.shared.languagePreference }
        set { AgentProvider.shared.languagePreference = newValue }
    }

    /// 聊天模式
    var chatMode: ChatMode {
        get { AgentProvider.shared.chatMode }
        set { AgentProvider.shared.chatMode = newValue }
    }

    /// 自动批准风险
    var autoApproveRisk: Bool {
        get { AgentProvider.shared.autoApproveRisk }
        set { AgentProvider.shared.autoApproveRisk = newValue }
    }

    /// 供应商选择
    var selectedProviderId: String {
        get { AgentProvider.shared.selectedProviderId }
        set { AgentProvider.shared.selectedProviderId = newValue }
    }

    /// 模型选择
    var selectedModel: String {
        get { AgentProvider.shared.selectedModel }
        set { AgentProvider.shared.selectedModel = newValue }
    }

    /// 当前项目名称
    var currentProjectName: String {
        get { AgentProvider.shared.currentProjectName }
        set { AgentProvider.shared.currentProjectName = newValue }
    }

    /// 当前项目路径
    var currentProjectPath: String {
        get { AgentProvider.shared.currentProjectPath }
        set { AgentProvider.shared.currentProjectPath = newValue }
    }

    /// 是否已选择项目
    var isProjectSelected: Bool {
        get { AgentProvider.shared.isProjectSelected }
        set { AgentProvider.shared.isProjectSelected = newValue }
    }

    /// 获取工具列表
    var tools: [AgentTool] {
        AgentProvider.shared.toolManager.tools
    }

    // MARK: - 初始化

    init() {
        // 同步 AgentProvider 的状态
        _ = languagePreference
        _ = chatMode
        _ = autoApproveRisk
        _ = selectedProviderId
        _ = selectedModel
        _ = currentProjectName
        _ = currentProjectPath
        _ = isProjectSelected

        // 订阅输入变化以更新建议
        $currentInput
            .receive(on: RunLoop.main)
            .sink { [weak self] input in
                self?.commandSuggestionViewModel.updateSuggestions(for: input)
            }
            .store(in: &cancellables)

        Task { @MainActor in
            // 创建新对话
            await createNewConversation()

            let fullSystemPrompt = await AgentProvider.shared.promptService.buildSystemPrompt(
                languagePreference: languagePreference,
                includeContext: isProjectSelected
            )

            messages.append(ChatMessage(role: .system, content: fullSystemPrompt))

            // 如果未选择项目，显示引导消息
            if !isProjectSelected {
                showProjectSelectionPrompt()
            } else {
                let welcomeMsg = await AgentProvider.shared.promptService.getWelcomeBackMessage(
                    projectName: currentProjectName,
                    projectPath: currentProjectPath,
                    language: languagePreference
                )
                let welcomeMessage = ChatMessage(role: .assistant, content: welcomeMsg)
                messages.append(welcomeMessage)
                // 保存欢迎消息到数据库
                saveMessage(welcomeMessage)
            }
        }

        if Self.verbose {
            os_log("\(self.t)DevAssistant 视图模型已初始化")
        }
    }

    // MARK: - 对话管理（代理到 AgentProvider）

    /// 创建新对话
    func createNewConversation() async {
        await AgentProvider.shared.createNewConversation()
    }

    /// 保存消息到存储
    func saveMessage(_ message: ChatMessage) {
        AgentProvider.shared.saveMessage(message)
    }

    // MARK: - 项目选择提示

    func showProjectSelectionPrompt() {
        Task {
            let prompt = await AgentProvider.shared.promptService.getWelcomeMessage()
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
            let planPrompt = await AgentProvider.shared.promptService.getPlanningModePrompt(task: task)
            await processUserMessage(input: planPrompt)
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
