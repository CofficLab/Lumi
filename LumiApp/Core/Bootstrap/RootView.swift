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

    /// 项目上下文与系统提示词（与 `container` 同源，见 `ProjectController.init(container:)`）。
    @StateObject var projectController = ProjectController(container: RootViewContainer.shared)

    /// 新会话创建流程（与 `container` 同源）。
    @StateObject var conversationCreationController = ConversationCreationController(container: RootViewContainer.shared)

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
            .environmentObject(container.messagePendingVM)
            .environmentObject(container.messageQueueVM)
            .environmentObject(container.agentAttachmentsVM)
            .environmentObject(container.inputQueueVM)
            .environmentObject(container.permissionHandlingVM)
            .environmentObject(container.conversationCreationVM)
            .environmentObject(container.commandSuggestionVM)
            .environmentObject(container.permissionRequestVM)
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
            .onAgentConversationSendTurnFinished(perform: onAgentConversationSendTurnFinished)
    }
}

extension View {
    /// 将视图包装在 RootView 中，注入所有必要的环境对象和模型容器
    /// - Returns: 包装在 RootView 中的视图
    func inRootView() -> some View {
        RootView(content: { self })
    }
}

// MARK: - Actions

extension RootView {
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

        projectController.applySavedProjectFromPreferences()
    }
}

// MARK: - Event Handlers

extension RootView {
    func onAppear() {
        loadPreferences()
    }

    func onAgentConversationSendTurnFinished(_: UUID) {
        Task {
            await sendController.attemptBeginNextQueuedSend(queueChangeLogging: false)
        }
    }

    func onResumeSendAfterToolPermission(_ conversationId: UUID) {
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
        Task {
            await sendController.attemptBeginNextQueuedSend(queueChangeLogging: true)
        }
    }

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

        let message = ChatMessage(role: .user, conversationId: conversationId, content: request.text, images: allImages)
        container.messageQueueVM.enqueueMessage(message)
    }

    func onConversationCreationRequested() {
        guard let requestId = container.conversationCreationVM.pendingRequest else { return }
        guard container.conversationCreationVM.consumePendingRequest(id: requestId) != nil else { return }

        Task { await conversationCreationController.handlePendingRequest(requestId: requestId) }
    }

    func onTaskCancellationRequested() {
        guard let conversationId = container.taskCancellationVM.conversationIdToCancel else { return }

        container.taskCancellationVM.consumeRequest()

        AppLogger.core.info("\(Self.t) [\(String(conversationId.uuidString.prefix(8)))] 任务已取消")
    }

    func onConversationChanged() {
        guard let conversationId = container.conversationVM.selectedConversationId else { return }
        Task { await projectController.handleConversationChanged(conversationId: conversationId, applyProjectContext: true) }
    }

    @MainActor
    func onProjectContextRequestChanged() {
        guard let request = container.projectContextRequestVM.request else { return }

        Task {
            await projectController.handleProjectContextRequest(request)
            container.projectContextRequestVM.request = nil
        }
    }
}

// MARK: - Preview

#Preview("App") {
    ContentLayout()
        .inRootView()
        .withDebugBar()
}
