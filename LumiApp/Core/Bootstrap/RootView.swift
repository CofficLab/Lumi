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
            .environmentObject(container.conversationRuntimeStore)
            .environmentObject(container.agentSessionConfig)
            .environmentObject(container.conversationVM)
            .environmentObject(container.messageViewModel)
            .environmentObject(container.messageSenderVM)
            .environmentObject(container.agentAttachmentsVM)
            .environmentObject(container.inputQueueVM)
            .environmentObject(container.permissionHandlingVM)
            .environmentObject(container.conversationCreationVM)
            .environmentObject(container.commandSuggestionViewModel)
            .environmentObject(container.depthWarningViewModel)
            .environmentObject(container.processingStateViewModel)
            .environmentObject(container.permissionRequestViewModel)
            .environmentObject(container.thinkingStateViewModel)
            .environmentObject(container.taskCancellationVM)
            .environmentObject(container.chatTimelineViewModel)
            .environmentObject(container.projectContextRequestVM)
            .environmentObject(container.mystiqueThemeManager)
            .modelContainer(container.modelContainer)
            .onAppear(perform: onAppear)
            .onChange(of: container.messageSenderVM.pendingMessages.count, onSenderPendingMessagesChanged)
            .onChange(of: container.conversationCreationVM.pendingRequest?.id, onConversationCreationRequested)
            .onChange(of: container.taskCancellationVM.conversationIdToCancel, onTaskCancellationRequested)
            .onChange(of: container.projectContextRequestVM.request, onProjectContextRequestChanged)
            .onChange(of: container.conversationVM.selectedConversationId, onConversationChanged)
            .task(id: ObjectIdentifier(container)) {
                await runConversationTurnPipeline()
            }
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
        loadConversation()
    }
}

// MARK: - Preview

#Preview("App") {
    ContentLayout()
        .inRootView()
        .withDebugBar()
}
