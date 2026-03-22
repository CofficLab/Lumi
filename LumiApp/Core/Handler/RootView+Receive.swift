import Foundation

extension RootView {
    func onMessageReceived(message: ChatMessage, conversationId: UUID) async {
        var message = message

        if var calls = message.toolCalls {
            for i in calls.indices {
                let risk = await toolExecutionService.evaluateRisk(
                    toolName: calls[i].name,
                    arguments: calls[i].arguments
                )

                if Self.verbose {
                    AppLogger.core.info("\(Self.t) 工具名称：\(calls[i].name)")
                    AppLogger.core.info("\(Self.t)  工具参数：\(calls[i].arguments)")
                    AppLogger.core.info("\(Self.t)  工具风险情况：\(risk.displayName)")
                }

                if !risk.requiresPermission {
                    calls[i].authorizationState = .noRisk
                } else if projectVM.autoApproveRisk {
                    calls[i].authorizationState = .autoApproved
                } else {
                    calls[i].authorizationState = .pendingAuthorization
                }
            }
            message.toolCalls = calls
        }

        // 落库消息
        await conversationVM.saveMessage(message, to: conversationId)

        // 如果消息有工具调用，则继续发送
        if message.hasToolCalls {
            await send(conversationId: conversationId)
        } else {
            // 如果消息没有工具调用，则结束发送
            finishSendTurn(conversationId: conversationId)
        }
    }
}
