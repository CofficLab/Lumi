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
/// 多窗口场景下，所有窗口共享同一份状态和数据。
///
/// ## 使用方式
///
/// ```swift
/// ContentLayout()
///     .inRootView()
/// ```
struct RootView<Content>: View where Content: View {
    /// 视图内容
    var content: Content

    /// 全局服务容器（单例）
    @StateObject private var container = RootViewContainer.shared

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
            .environmentObject(container.conversationTurnViewModel)
            .environmentObject(container.conversationRuntimeStore)
            .environmentObject(container.agentSessionConfig)
            .environmentObject(container.ConversationVM)
            .environmentObject(container.messageViewModel)
            .environmentObject(container.MessageSenderVM)
            .environmentObject(container.agentAttachmentsVM)
            .environmentObject(container.inputQueueVM)
            .environmentObject(container.permissionHandlingVM)
            .environmentObject(container.conversationCreationVM)
            .environmentObject(container.commandSuggestionViewModel)
            .environmentObject(container.depthWarningViewModel)
            .environmentObject(container.processingStateViewModel)
            .environmentObject(container.permissionRequestViewModel)
            .environmentObject(container.thinkingStateViewModel)
            .environmentObject(container.agentTaskCancellationVM)
            .environmentObject(container.chatTimelineViewModel)
            .environmentObject(container.projectContextRequestVM)
            .environmentObject(container.mystiqueThemeManager)
            .modelContainer(container.modelContainer)
            .onAppear {
                PreferencesLoadHandler.handle(projectVM: container.ProjectVM, slashCommandService: container.slashCommandService)
                onInitialConversationLoaded()
            }
            .onChange(of: container.MessageSenderVM.pendingMessages.count) { _, _ in
                onSenderPendingMessagesChanged()
            }
            .onChange(of: container.agentTaskCancellationVM.conversationIdToCancel) { _, conversationId in
                onAgentTaskCancellationRequested(conversationId)
            }
            .onChange(of: container.projectContextRequestVM.request, onProjectContextRequestChanged)
            .onChange(of: container.ConversationVM.selectedConversationId, onConversationSelectionChanged)
            .task(id: ObjectIdentifier(container)) {
                await container.conversationTurnViewModel.makeConversationTurnPipelineHandler().run()
            }
    }
}

// MARK: - Event Handling

extension RootView {
    func onAgentTaskCancellationRequested(_ conversationId: UUID?) {
        guard let conversationId else { return }
        CancelAgentTaskHandler.handle(
            conversationId: conversationId,
            turnVM: container.conversationTurnViewModel
        )
        container.agentTaskCancellationVM.consumeRequest()
    }

    func onSenderPendingMessagesChanged() {
        SendMessageHandler.handle(
            vm: container.MessageSenderVM,
            messageViewModel: container.messageViewModel,
            conversationVM: container.ConversationVM,
            runtimeStore: container.conversationRuntimeStore,
            sessionConfig: container.agentSessionConfig,
            projectVM: container.ProjectVM,
            slashCommandService: container.slashCommandService,
            enqueueTurnProcessing: { [weak turn = container.conversationTurnViewModel] conversationId, depth in
                turn?.enqueueTurnProcessing(conversationId: conversationId, depth: depth)
            }
        )
    }

    func onProjectContextRequestChanged() {
        ProjectContextRequestHandler.handle(
            request: container.projectContextRequestVM.request,
            container: container
        )
    }

    func onInitialConversationLoaded() {
        guard let conversationId = container.ConversationVM.selectedConversationId else { return }

        let handler = ConversationChangedHandler(
            runtimeStore: container.conversationRuntimeStore,
            conversationVM: container.ConversationVM,
            messageSenderVM: container.MessageSenderVM,
            projectVM: container.ProjectVM,
            promptService: container.promptService,
            slashCommandService: container.slashCommandService,
            messageViewModel: container.messageViewModel,
            processingStateViewModel: container.processingStateViewModel,
            thinkingStateViewModel: container.thinkingStateViewModel,
            permissionRequestViewModel: container.permissionRequestViewModel,
            depthWarningViewModel: container.depthWarningViewModel
        )

        Task { await handler.handle(conversationId: conversationId, applyProjectContext: false) }
    }

    func onConversationSelectionChanged() {
        guard let conversationId = container.ConversationVM.selectedConversationId else { return }

        let handler = ConversationChangedHandler(
            runtimeStore: container.conversationRuntimeStore,
            conversationVM: container.ConversationVM,
            messageSenderVM: container.MessageSenderVM,
            projectVM: container.ProjectVM,
            promptService: container.promptService,
            slashCommandService: container.slashCommandService,
            messageViewModel: container.messageViewModel,
            processingStateViewModel: container.processingStateViewModel,
            thinkingStateViewModel: container.thinkingStateViewModel,
            permissionRequestViewModel: container.permissionRequestViewModel,
            depthWarningViewModel: container.depthWarningViewModel
        )

        Task { await handler.handle(conversationId: conversationId, applyProjectContext: true) }
    }
}

extension View {
    /// 将视图包装在 RootView 中，注入所有必要的环境对象和模型容器
    /// - Returns: 包装在 RootView 中的视图
    func inRootView() -> some View {
        RootView(content: { self })
    }
}

// MARK: - Preview

#Preview("App") {
    ContentLayout()
        .inRootView()
        .withDebugBar()
}
