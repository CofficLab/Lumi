import Combine
import AgentToolKit
import Foundation
import MagicAlert
import SwiftUI

/// 根事件监听视图
/// 专门负责监听各种事件并触发相应的处理逻辑
///
/// ## 监听的事件
/// - 消息队列变化 (`messageQueueVM.$queueVersion`)
/// - 输入队列请求 (`inputQueueVM.enqueueRequests`)
/// - 任务取消请求 (`taskCancellationVM.$conversationIdToCancel`)
/// - 项目上下文请求 (`projectContextRequestVM.$request`)
/// - Tool 权限恢复发送 (`onResumeSendAfterToolPermission`)
/// - Agent 回合完成 (`onAgentConversationSendTurnFinished`)
struct RootListener: View, SuperLog {
    nonisolated static var emoji: String { "📡" }
    nonisolated static var verbose: Bool { false }

    /// 窗口作用域（每窗口独立）
    @ObservedObject var scope: WindowContainer

    /// 发送与回合管线（每窗口独立，直接访问窗口级 VM）。
    private var sendController: SendController { scope.sendController }

    /// 项目上下文与系统提示词（每窗口独立）。
    private var projectController: ProjectController { scope.projectController }

    init(scope: WindowContainer) {
        self._scope = ObservedObject(wrappedValue: scope)
    }

    var body: some View {
        Color.clear
            .allowsHitTesting(false)
            .onReceive(scope.messageQueueVM.$queueVersion.dropFirst()) { _ in
                onMessageQueueChanged()
            }
            .onReceive(scope.inputQueueVM.enqueueRequests) { request in
                onInputQueueRequested(request)
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

// MARK: - Event Handlers

extension RootListener {
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
    func onInputQueueRequested(_ request: WindowInputQueueVM.InputEnqueueRequest) {
        guard scope.inputQueueVM.consumePendingRequest(id: request.id) != nil else {
            return
        }
        guard let conversationId = scope.conversationVM.selectedConversationId else {
            return
        }

        let pendingImages = scope.agentAttachmentsVM.drainPendingImageAttachments()
        let allImages = request.images + pendingImages
        guard !request.text.isEmpty || !allImages.isEmpty else {
            return
        }

        if Self.verbose {
            AppLogger.core.info("\(Self.t)将用户的输入加入消息队列")
        }

        let message = ChatMessage(
            role: .user,
            conversationId: conversationId,
            content: request.text,
            images: allImages
        )
        scope.messageQueueVM.enqueueMessage(message)
        scope.chatTimelineViewModel.handleMessageQueued(message)
        Task {
            await sendController.attemptBeginNextQueuedSend()
        }
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
