import Foundation
import LumiCoreKit

/// 按会话互斥，防止多个插件同时处理同一 Turn。
@MainActor
final class AgentConversationLock {
    static let shared = AgentConversationLock()

    private var lockedConversationIds = Set<UUID>()
    private var cancelledConversationIds = Set<UUID>()

    private init() {}

    func tryAcquire(_ conversationId: UUID) -> Bool {
        guard !lockedConversationIds.contains(conversationId) else {
        if AgentSendPipelineLog.enabled {
                AgentSendPipelineLog.logger.info("\(AgentSendPipelineLog.t)[\(AgentSendPipelineLog.conv(conversationId))] 🔒 [Lock] acquire failed (busy)")
            }
            return false
        }
        lockedConversationIds.insert(conversationId)
        if AgentSendPipelineLog.enabled {
            AgentSendPipelineLog.logger.info("\(AgentSendPipelineLog.t)[\(AgentSendPipelineLog.conv(conversationId))] 🔒 [Lock] acquired")
        }
        return true
    }

    func release(_ conversationId: UUID) {
        lockedConversationIds.remove(conversationId)
        if AgentSendPipelineLog.enabled {
            AgentSendPipelineLog.logger.info("\(AgentSendPipelineLog.t)[\(AgentSendPipelineLog.conv(conversationId))] 🔒 [Lock] released")
        }
    }

    func markCancelled(_ conversationId: UUID) {
        cancelledConversationIds.insert(conversationId)
    }

    func clearCancelled(_ conversationId: UUID) {
        cancelledConversationIds.remove(conversationId)
    }

    func isCancelled(_ conversationId: UUID) -> Bool {
        cancelledConversationIds.contains(conversationId)
    }

    func releaseAll() {
        lockedConversationIds.removeAll()
    }
}
