import Foundation
import MagicAlert
import MagicKit
import SwiftData
import SwiftUI

/// 根视图容器组件
/// 为应用提供统一的上下文环境，管理核心服务初始化和环境注入
///
/// ## 架构说明
///
/// 所有服务和 ViewModel 均为全局单例，通过 `RootViewContainer.shared` 管理。
/// 主窗口与设置等窗口通过 `.inRootView()` 注入同一套环境。
///
/// ## 使用方式
///
/// ```swift
/// ContentLayout()
///     .inRootView()
/// ```
struct RootView<Content>: View, SuperLog where Content: View {
    nonisolated static var emoji: String { "📤" }
    nonisolated static var verbose: Bool { true }

    /// 视图内容
    var content: Content

    /// 全局服务容器（单例）。
    @StateObject var container = RootViewContainer.shared

    /// 发送与回合管线（与 `container` 同源，见 `SendController.init(container:)`）。
    @StateObject var sendController = SendController(container: RootViewContainer.shared)

    var captureThinkingContent: Bool { container.captureThinkingContent }
    var chatHistoryService: ChatHistoryService { container.chatHistoryService }
    var conversationSendStatusVM: ConversationSendStatusVM { container.conversationSendStatusVM }
    var conversationVM: ConversationVM { container.conversationVM }
    var llmService: LLMService { container.llmService }
    var messageQueueVM: MessageQueueVM { container.messageQueueVM }
    var messageVM: MessagePendingVM { container.messageViewModel }
    var permissionRequestViewModel: PermissionRequestVM { container.permissionRequestViewModel }
    var projectVM: ProjectVM { container.ProjectVM }
    var sessionConfig: AgentSessionConfig { container.agentSessionConfig }
    var toolExecutionService: ToolExecutionService { container.toolExecutionService }
    var toolService: ToolService { container.toolService }

    init(@ViewBuilder content: () -> Content) {
        self.content = content()
    }

    var body: some View {
        content
            .withMagicToast()
            .environmentObject(container.appProvider)
            .environmentObject(container.ProjectVM)
            .environmentObject(container.providerRegistry)
            .environmentObject(container.pluginVM)
            .environmentObject(container.conversationTurnServices)
            .environmentObject(container.agentSessionConfig)
            .environmentObject(container.conversationVM)
            .environmentObject(container.messageViewModel)
            .environmentObject(container.messageQueueVM)
            .environmentObject(container.agentAttachmentsVM)
            .environmentObject(container.inputQueueVM)
            .environmentObject(container.permissionHandlingVM)
            .environmentObject(container.conversationCreationVM)
            .environmentObject(container.commandSuggestionViewModel)
            .environmentObject(container.permissionRequestViewModel)
            .environmentObject(container.taskCancellationVM)
            .environmentObject(container.chatTimelineViewModel)
            .environmentObject(container.conversationSendStatusVM)
            .environmentObject(container.projectContextRequestVM)
            .environmentObject(container.mystiqueThemeManager)
            .modelContainer(container.modelContainer)
            .onAppear(perform: onAppear)
            .onChange(of: selectedConversationQueueCount, onQueueChanged)
            .onChange(of: container.inputQueueVM.pendingRequest?.id, onInputQueueRequested)
            .onChange(of: container.conversationCreationVM.pendingRequest, onConversationCreationRequested)
            .onChange(of: container.taskCancellationVM.conversationIdToCancel, onTaskCancellationRequested)
            .onChange(of: container.projectContextRequestVM.request, onProjectContextRequestChanged)
            .onChange(of: container.conversationVM.selectedConversationId, onConversationChanged)
            .onResumeSendAfterToolPermission(perform: onResumeSendAfterToolPermission)
    }
}

extension View {
    /// 将视图包装在 RootView 中，注入所有必要的环境对象和模型容器
    /// - Returns: 包装在 RootView 中的视图
    func inRootView() -> some View {
        RootView(content: { self })
    }
}

// MARK: - Event Handlers

extension RootView {
    func onAppear() {
        loadPreferences()
    }

    @MainActor
    func loadPreferences() {
        if let data = PluginStateStore.shared.data(forKey: "Agent_LanguagePreference"),
           let preference = try? JSONDecoder().decode(LanguagePreference.self, from: data) {
            container.ProjectVM.setLanguagePreference(preference)
        }

        if let modeRaw = PluginStateStore.shared.string(forKey: "Agent_ChatMode"),
           let mode = ChatMode(rawValue: modeRaw) {
            container.ProjectVM.setChatMode(mode)
        }

        if let savedPath = PluginStateStore.shared.string(forKey: "Agent_SelectedProject") {
            container.ProjectVM.switchProject(to: savedPath)
            Task {
                await container.slashCommandService.setCurrentProjectPath(savedPath)
            }
        }
    }

    // MARK: - Send queue & resume

    private func onResumeSendAfterToolPermission(_ conversationId: UUID) {
        Task {
            await sendController.send(conversationId: conversationId)
        }
    }

    private var selectedConversationQueueCount: Int {
        guard let conversationId = container.conversationVM.selectedConversationId else { return 0 }
        return container.messageQueueVM.queueCount(for: conversationId)
    }

    /// 待发送的队列发生变化
    func onQueueChanged() {
        guard let conversationId = conversationVM.selectedConversationId else {
            AppLogger.core.error("\(Self.t) 消息队列变了，但当前没有选中的会话，忽略")
            return
        }

        let pendingMessages = messageQueueVM.pendingMessages(for: conversationId)
        guard let message = pendingMessages.first else {
            AppLogger.core.error("\(Self.t) 消息队列变了，但当前会话没有待发送消息，忽略")
            return
        }

        // 如果当前会话正在处理消息，则不发送
        if conversationSendStatusVM.isMessageProcessing(for: conversationId) {
            AppLogger.core.error("\(Self.t) 消息队列变了，但当前会话有上一条消息尚未结束，忽略")
            return
        }

        messageQueueVM.setCurrentProcessingIndex(0, for: conversationId)

        Task {
            if conversationVM.selectedConversationId == conversationId {
                messageVM.appendMessage(message)
            }

            await conversationVM.saveMessage(message, to: conversationId)

            let ctx = SendMessageContext(conversationId: conversationId, message: message)
            let pipeline = SendPipeline(middlewares: container.pluginVM.getSendMiddlewares())
            await pipeline.run(ctx: ctx) { _ in }

            await sendController.send(conversationId: conversationId)
        }
    }

    // MARK: - Input queue

    @MainActor
    func onInputQueueRequested() {
        guard let requestId = container.inputQueueVM.pendingRequest?.id else { return }
        guard let request = container.inputQueueVM.consumePendingRequest(id: requestId) else { return }

        guard let conversationId = container.conversationVM.selectedConversationId else {
            if Self.verbose {
                AppLogger.core.info("\(Self.t) No conversation selected")
            }
            return
        }

        let pendingImages = container.agentAttachmentsVM.drainPendingImageAttachments()
        let allImages = request.images + pendingImages
        guard !request.text.isEmpty || !allImages.isEmpty else { return }

        let message = ChatMessage(role: .user, content: request.text, images: allImages)
        container.messageQueueVM.enqueueMessage(message, in: conversationId)
    }

    // MARK: - Conversation creation

    func onConversationCreationRequested() {
        guard let requestId = container.conversationCreationVM.pendingRequest else { return }
        guard let request = container.conversationCreationVM.consumePendingRequest(id: requestId) else { return }

        Task { await createConversation(using: request) }
    }

    private func createConversation(using requestId: UUID) async {
        let projectId = container.ProjectVM.isProjectSelected ? container.ProjectVM.currentProjectPath : nil
        let projectName = container.ProjectVM.isProjectSelected ? container.ProjectVM.currentProjectName : nil
        let projectPath = container.ProjectVM.isProjectSelected ? container.ProjectVM.currentProjectPath : nil
        let languagePreference = container.ProjectVM.languagePreference

        let formatter = DateFormatter()
        formatter.dateFormat = "MM-dd HH:mm"

        let conversation = container.chatHistoryService.createConversation(
            projectId: projectId,
            title: "新会话 " + formatter.string(from: Date())
        )

        container.conversationVM.setSelectedConversation(conversation.id)
        NotificationCenter.postAgentConversationCreated(conversationId: conversation.id)
        container.conversationCreationVM.completeRequest(id: requestId)

        Task {
            let systemMessage = await container.promptService.getSystemContextMessage(
                projectName: projectName,
                projectPath: projectPath,
                language: languagePreference
            )
            if !systemMessage.isEmpty {
                await container.conversationVM.saveMessage(ChatMessage(role: .system, content: systemMessage), to: conversation.id)
            }

            let welcomeMessage = await container.promptService.getEmptySessionWelcomeMessage(
                projectName: projectName,
                projectPath: projectPath,
                language: languagePreference
            )
            if !welcomeMessage.isEmpty {
                await container.conversationVM.saveMessage(ChatMessage(role: .assistant, content: welcomeMessage), to: conversation.id)
            }
        }
    }

    // MARK: - System message (root list)

    func upsertRootSystemMessage(_ content: String) {
        let currentMessages = container.messageViewModel.messages
        let systemMessage = ChatMessage(role: .system, content: content)

        if !currentMessages.isEmpty, currentMessages[0].role == .system {
            container.messageViewModel.updateMessage(systemMessage, at: 0)
        } else {
            container.messageViewModel.insertMessage(systemMessage, at: 0)
        }
    }

    // MARK: - Task cancellation

    func onTaskCancellationRequested() {
        guard let conversationId = container.taskCancellationVM.conversationIdToCancel else { return }

        container.taskCancellationVM.consumeRequest()

        AppLogger.core.info("\(Self.t) [\(String(conversationId.uuidString.prefix(8)))] 任务已取消")
    }

    // MARK: - Conversation selection

    func onConversationChanged() {
        guard let conversationId = container.conversationVM.selectedConversationId else { return }
        Task { await handleConversationChanged(conversationId: conversationId, applyProjectContext: true) }
    }

    private func handleConversationChanged(conversationId: UUID, applyProjectContext: Bool) async {
        guard applyProjectContext else { return }
        guard let conversation = container.conversationVM.fetchConversation(id: conversationId) else { return }

        let path = conversation.projectId?.trimmingCharacters(in: .whitespacesAndNewlines)
        let languagePreference = container.ProjectVM.languagePreference

        if let path, !path.isEmpty {
            container.ProjectVM.switchProject(to: path)
            await applyConversationProjectContext(path: path, languagePreference: languagePreference)
        } else {
            container.ProjectVM.clearProject()
            await applyConversationProjectContext(path: nil, languagePreference: languagePreference)
        }
    }

    private func applyConversationProjectContext(path: String?, languagePreference: LanguagePreference) async {
        let fullSystemPrompt = await container.promptService.buildSystemPrompt(
            languagePreference: languagePreference,
            includeContext: true
        )
        upsertRootSystemMessage(fullSystemPrompt)
        await container.slashCommandService.setCurrentProjectPath(path)
    }

    // MARK: - Project context request

    @MainActor
    func onProjectContextRequestChanged() {
        guard let request = container.projectContextRequestVM.request else { return }

        switch request {
        case let .switchProject(path):
            Task {
                await handleProjectSwitch(path: path)
                container.projectContextRequestVM.request = nil
            }

        case .clearProject:
            Task {
                await handleProjectClear()
                container.projectContextRequestVM.request = nil
            }
        }
    }

    private func handleProjectSwitch(path: String) async {
        container.ProjectVM.switchProject(to: path)
        let languagePreference = container.ProjectVM.languagePreference
        await applyProjectContext(path: path, languagePreference: languagePreference)

        let projectName = container.ProjectVM.currentProjectName
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

        container.messageViewModel.appendMessage(ChatMessage(role: .assistant, content: switchMessage))
    }

    private func handleProjectClear() async {
        guard container.ProjectVM.isProjectSelected else { return }

        container.conversationVM.setSelectedConversation(nil)
        container.ProjectVM.clearProject()

        let languagePreference = container.ProjectVM.languagePreference
        await applyProjectContext(path: nil, languagePreference: languagePreference)

        let clearMessage: String
        switch languagePreference {
        case .chinese:
            clearMessage = "✅ 已取消选择项目，当前未关联任何项目。"
        case .english:
            clearMessage = "✅ Project cleared. No project is currently selected."
        }

        container.messageViewModel.appendMessage(ChatMessage(role: .assistant, content: clearMessage))
    }

    private func applyProjectContext(path: String?, languagePreference: LanguagePreference) async {
        let fullSystemPrompt = await container.promptService.buildSystemPrompt(
            languagePreference: languagePreference,
            includeContext: true
        )
        upsertRootSystemMessage(fullSystemPrompt)
        await container.slashCommandService.setCurrentProjectPath(path)
    }
}

// MARK: - Preview

#Preview("App") {
    ContentLayout()
        .inRootView()
        .withDebugBar()
}
