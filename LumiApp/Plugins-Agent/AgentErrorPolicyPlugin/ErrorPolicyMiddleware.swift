import Foundation

/// 错误策略中间件（ConversationTurnEvent）
///
/// 目标：
/// - 统一“错误归类 -> 是否展示 -> 展示什么文案”的策略
/// - 必要时短路核心 handler，避免核心代码不断堆叠错误分支
@MainActor
struct ErrorPolicyMiddleware: ConversationTurnMiddleware {
    let id: String = "agent.error-policy"
    let order: Int = 80

    func handle(
        event: ConversationTurnEvent,
        ctx: ConversationTurnMiddlewareContext,
        next: @escaping @MainActor (ConversationTurnEvent, ConversationTurnMiddlewareContext) async -> Void
    ) async {
        guard case let .error(error, conversationId) = event else {
            await next(event, ctx)
            return
        }

        // 取消类错误：不作为“失败”展示（用户手动取消/切换导致的中断不应弹红字）
        if isCancellation(error) {
            cleanupTurnRuntimeState(conversationId, ctx: ctx, errorMessage: nil, treatAsFailure: false)
            return
        }

        let userFacing = userFacingMessage(for: error)
        cleanupTurnRuntimeState(conversationId, ctx: ctx, errorMessage: userFacing, treatAsFailure: true)
        // 短路：由中间件完全接管 `.error` 分支，避免核心重复处理。
    }

    private func cleanupTurnRuntimeState(
        _ conversationId: UUID,
        ctx: ConversationTurnMiddlewareContext,
        errorMessage: String?,
        treatAsFailure: Bool
    ) {
        ctx.runtimeStore.errorMessageByConversation[conversationId] = errorMessage
        ctx.runtimeStore.processingConversationIds.remove(conversationId)

        if ctx.env.selectedConversationId() == conversationId {
            if let errorMessage, treatAsFailure {
                ctx.ui.onTurnFailedUI(conversationId, errorMessage)
            }
        }

        ctx.runtimeStore.streamStateByConversation[conversationId] = .init(messageId: nil, messageIndex: nil)
        ctx.runtimeStore.pendingStreamTextByConversation[conversationId] = nil
        ctx.runtimeStore.pendingThinkingTextByConversation[conversationId] = nil
        ctx.runtimeStore.lastStreamFlushAtByConversation[conversationId] = nil
        ctx.runtimeStore.lastThinkingFlushAtByConversation[conversationId] = nil
        ctx.runtimeStore.streamStartedAtByConversation[conversationId] = nil
        ctx.runtimeStore.didReceiveFirstTokenByConversation.remove(conversationId)

        ctx.actions.updateRuntimeState(conversationId)
    }

    private func isCancellation(_ error: Error) -> Bool {
        if error is CancellationError { return true }
        let ns = error as NSError
        if ns.domain == NSURLErrorDomain, ns.code == NSURLErrorCancelled { return true }
        return false
    }

    private func userFacingMessage(for error: Error) -> String {
        let ns = error as NSError
        if ns.domain == NSURLErrorDomain, ns.code == NSURLErrorTimedOut {
            return "请求超时，请检查网络连接或稍后重试。"
        }
        if ns.domain == NSURLErrorDomain, ns.code == NSURLErrorNotConnectedToInternet {
            return "网络不可用，请检查网络连接。"
        }
        return error.localizedDescription
    }
}

