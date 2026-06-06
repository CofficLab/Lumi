import Combine
import AgentToolKit
import Foundation
import LumiCoreKit
import MagicAlert
import SwiftUI

/// 根事件监听视图
/// 专门负责监听各种事件并触发相应的处理逻辑
///
/// ## 监听的事件
/// - 输入队列请求 (`inputQueueVM.enqueueRequests`)
/// - 任务取消请求 (`taskCancellationVM.$conversationIdToCancel`)
/// - 项目上下文请求 (`projectContextRequestVM.$request`)
/// - Tool 权限恢复发送 (`onResumeSendAfterToolPermission`)
struct RootListener: View, SuperLog {
    nonisolated static var emoji: String { "📡" }
    nonisolated static var verbose: Bool { false }

    /// 窗口作用域（每窗口独立）
    @ObservedObject var scope: WindowContainer

    /// 项目上下文与系统提示词（每窗口独立）。
    private var projectController: ProjectController { scope.projectController }

    init(scope: WindowContainer) {
        self._scope = ObservedObject(wrappedValue: scope)
    }

    var body: some View {
        Color.clear
            .allowsHitTesting(false)
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
    }
}

// MARK: - Event Handlers

extension RootListener {
    func onResumeSendAfterToolPermission(_ conversationId: UUID) {
        RootContainer.shared.conversationService.setTurnPhase(.processing, forConversationId: conversationId)
    }

    @MainActor
    func onInputQueueRequested(_ request: WindowInputQueueVM.InputEnqueueRequest) {
        scope.handleInputEnqueueRequest(request)
    }

    func onTaskCancellationRequested() {
        guard let conversationId = scope.taskCancellationVM.conversationIdToCancel else { return }

        scope.taskCancellationVM.consumeRequest()
        scope.cancelAgentTurn(conversationId: conversationId)

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
