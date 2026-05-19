import Combine
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
/// 全局共享 VM 通过 `RootContainer.shared` 注入。
/// 窗口级 VM 通过 `WindowScope` 注入，每个窗口拥有独立的 VM 实例。
///
/// ## 使用方式
///
/// ```swift
/// ContentLayout()
///     .inRootView(scope: windowScope)
/// ```
struct RootView<Content>: View, SuperLog where Content: View {
    nonisolated static var emoji: String { "📤" }
    nonisolated static var verbose: Bool { false }

    /// 视图内容
    var content: Content

    /// 窗口作用域（每窗口独立）
    @ObservedObject var scope: WindowScope

    /// 全局服务容器（单例）。
    @StateObject var container = RootContainer.shared

    /// 发送与回合管线（与 `container` 同源，见 `SendController.init(container:)`）。
    @StateObject var sendController = SendController(container: RootContainer.shared)

    /// 项目上下文与系统提示词（与 `container` 同源，见 `ProjectController.init(container:)`）。
    @StateObject var projectController = ProjectController(container: RootContainer.shared)

    /// 会话控制器（创建、删除、重命名等会话操作）。
    @StateObject var conversationController = ConversationController(container: RootContainer.shared)

    init(scope: WindowScope, @ViewBuilder content: () -> Content) {
        self._scope = ObservedObject(wrappedValue: scope)
        self.content = content()
    }

    var body: some View {
        content
            .withMagicToast()
            // 全局 VM（所有窗口共享）
            .environmentObject(container.themeVM)
            .environmentObject(container.providerRegistry)
            .environmentObject(container.pluginVM)
            .environmentObject(container.messageRendererVM)
            .environmentObject(container.conversationTurnServices)
            .environmentObject(container.agentSessionConfig)
            .environmentObject(container.chatHistoryVM)
            .environmentObject(container.gitVM)
            .environmentObject(container.editorVM)
            .environmentObject(container.idleTimeVM)
            // 窗口级 VM（每窗口独立）
            .environmentObject(scope.conversationVM)
            .environmentObject(scope.projectVM)
            .environmentObject(scope.layoutVM)
            .environmentObject(scope.messagePendingVM)
            .environmentObject(scope.messageQueueVM)
            .environmentObject(scope.agentAttachmentsVM)
            .environmentObject(scope.inputQueueVM)
            .environmentObject(scope.permissionHandlingVM)
            .environmentObject(scope.conversationCreationVM)
            .environmentObject(scope.commandSuggestionVM)
            .environmentObject(scope.permissionRequestVM)
            .environmentObject(scope.taskCancellationVM)
            .environmentObject(scope.chatTimelineViewModel)
            .environmentObject(scope.conversationSendStatusVM)
            .environmentObject(scope.projectContextRequestVM)
            .environment(\.windowScope, scope)
            .modelContainer(container.modelContainer)
            .onReceive(scope.messageQueueVM.$queueVersion.dropFirst()) { _ in
                onMessageQueueChanged()
            }
            .onReceive(scope.inputQueueVM.$queueVersion.dropFirst()) { _ in
                onInputQueueRequested()
            }
            .onReceive(scope.conversationCreationVM.$pendingRequest.compactMap { $0 }) { _ in
                onConversationCreationRequested()
            }
            .onReceive(scope.taskCancellationVM.$conversationIdToCancel.compactMap { $0 }) { _ in
                onTaskCancellationRequested()
            }
            .onReceive(scope.projectContextRequestVM.$request.compactMap { $0 }) { _ in
                onProjectContextRequestChanged()
            }
            .onResumeSendAfterToolPermission(perform: onResumeSendAfterToolPermission)
            .onAgentConversationSendTurnFinished(perform: onAgentConversationSendTurnFinished)
    }
}

extension View {
    /// 将视图包装在 RootView 中，注入所有必要的环境对象和模型容器
    /// - Parameter scope: 窗口作用域
    /// - Returns: 包装在 RootView 中的视图
    func inRootView(scope: WindowScope) -> some View {
        RootView(scope: scope, content: { self })
    }

    /// Preview 专用：使用 fallback WindowScope 注入环境对象
    ///
    /// 生产代码请使用 `inRootView(scope:)` 传入窗口作用域。
    /// 此方法仅用于 #Preview 和设置窗口等无窗口上下文的场景。
    func inRootView() -> some View {
        inRootView(scope: WindowScope(container: RootContainer.shared))
    }
}

// MARK: - Event Handlers

extension RootView {
    func onAgentConversationSendTurnFinished(_: UUID) {
        Task {
            await sendController.attemptBeginNextQueuedSend()
        }
    }

    func onResumeSendAfterToolPermission(_ conversationId: UUID) {
        Task {
            await sendController.resumeAfterPermissionGranted(conversationId: conversationId)
        }
    }

    /// 待发送的Message队列版本发生变化
    func onMessageQueueChanged() {
        if scope.messageQueueVM.messages.isEmpty {
            return
        }

        if Self.verbose {
            AppLogger.core.info("\(Self.t) 队列发生变化，尝试开始发送")
        }

        Task {
            await sendController.attemptBeginNextQueuedSend()
        }
    }

    @MainActor
    func onInputQueueRequested() {
        guard let requestId = scope.inputQueueVM.pendingRequest?.id else {
            if Self.verbose { AppLogger.core.warning("\(Self.t) 收到输入队列版本变化，但没有待处理输入请求") }
            return
        }
        guard let request = scope.inputQueueVM.consumePendingRequest(id: requestId) else {
            if Self.verbose { AppLogger.core.warning("\(Self.t) 输入请求已不存在或 ID 不匹配，忽略：\(requestId)") }
            return
        }

        guard let conversationId = scope.conversationVM.selectedConversationId else {
            if Self.verbose { AppLogger.core.warning("\(Self.t) 用户输入了数据，但没有选择对话，忽略") }
            return
        }

        let pendingImages = scope.agentAttachmentsVM.drainPendingImageAttachments()
        let allImages = request.images + pendingImages
        guard !request.text.isEmpty || !allImages.isEmpty else {
            if Self.verbose { AppLogger.core.warning("\(Self.t) 用户输入了数据，但是文本和图片都为空，忽略") }
            return
        }
        
        if Self.verbose {
            AppLogger.core.info("\(Self.t)将用户的输入加入消息队列")
        }

        scope.messageQueueVM.enqueueMessage(ChatMessage(
            role: .user,
            conversationId: conversationId,
            content: request.text,
            images: allImages)
        )
    }

    func onConversationCreationRequested() {
        guard let requestId = scope.conversationCreationVM.pendingRequest else { return }
        guard scope.conversationCreationVM.consumePendingRequest(id: requestId) != nil else { return }

        Task { await conversationController.handleCreationRequest(requestId: requestId) }
    }

    func onTaskCancellationRequested() {
        guard let conversationId = scope.taskCancellationVM.conversationIdToCancel else { return }

        scope.taskCancellationVM.consumeRequest()
        sendController.cancelSend(conversationId: conversationId)

        if Self.verbose {
            AppLogger.core.info("\(Self.t) [\(String(conversationId.uuidString.prefix(8)))] 任务已取消")
        }
    }

    @MainActor
    func onProjectContextRequestChanged() {
        guard let request = scope.projectContextRequestVM.request else { return }

        Task {
            await projectController.handleProjectContextRequest(request)
            scope.projectContextRequestVM.request = nil
        }
    }
}

// MARK: - Preview

#Preview("App") {
    ContentLayout()
        .inRootView(scope: WindowScope(container: RootContainer.shared))
        .withDebugBar()
}
