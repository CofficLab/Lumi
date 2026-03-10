import SwiftUI
import Foundation

/// 思考状态 ViewModel
/// 专门管理思考状态和思考文本，避免因 AgentProvider 其他状态变化导致不必要的视图重新渲染
@MainActor
final class ThinkingStateViewModel: ObservableObject {
    /// 是否正在思考（用于显示思考状态）
    @Published public fileprivate(set) var isThinking: Bool = false

    /// 当前思考过程文本
    @Published public fileprivate(set) var thinkingText: String = ""

    /// 当前激活会话 ID（用于驱动当前会话的 UI）
    private var activeConversationId: UUID?

    /// 按会话维度的思考状态
    @Published public fileprivate(set) var isThinkingByConversation: [UUID: Bool] = [:]

    /// 按会话维度的思考文本
    @Published public fileprivate(set) var thinkingTextByConversation: [UUID: String] = [:]

    /// 切换当前激活的会话，用于同步全局 isThinking/thinkingText
    func setActiveConversation(_ conversationId: UUID?) {
        activeConversationId = conversationId
        if let id = conversationId {
            isThinking = isThinkingByConversation[id] ?? false
            thinkingText = thinkingTextByConversation[id] ?? ""
        } else {
            isThinking = false
            thinkingText = ""
        }
    }

    /// 设置思考状态
    func setIsThinking(_ thinking: Bool, for conversationId: UUID) {
        isThinkingByConversation[conversationId] = thinking
        if conversationId == activeConversationId {
            isThinking = thinking
        }
    }

    /// 追加思考文本
    func appendThinkingText(_ text: String, for conversationId: UUID) {
        let existing = thinkingTextByConversation[conversationId] ?? ""
        let updated = existing + text
        thinkingTextByConversation[conversationId] = updated
        if conversationId == activeConversationId {
            thinkingText = updated
        }
    }

    /// 设置思考文本
    func setThinkingText(_ text: String, for conversationId: UUID) {
        thinkingTextByConversation[conversationId] = text
        if conversationId == activeConversationId {
            thinkingText = text
        }
    }

    /// 查询指定会话是否正在思考
    func isThinking(for conversationId: UUID) -> Bool {
        isThinkingByConversation[conversationId] ?? false
    }

    /// 查询指定会话的思考文本
    func thinkingText(for conversationId: UUID) -> String {
        thinkingTextByConversation[conversationId] ?? ""
    }
}