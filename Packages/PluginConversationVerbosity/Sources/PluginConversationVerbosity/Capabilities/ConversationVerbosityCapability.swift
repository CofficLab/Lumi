import Foundation
import ProviderConversation

/// Verbosity 插件需要的最小会话能力边界。
///
/// 工具栏视图通过该协议读写详细程度，不直接持有
/// `ConversationManaging` 具体类型；Provider 的解析与适配由插件入口完成。
@MainActor
protocol ConversationVerbosityCapability: AnyObject {
    /// 当前选中的对话 ID。
    var selectedConversationID: UUID? { get }

    /// 获取指定对话的详细程度。
    func verbosity(for conversationID: UUID?) -> ResponseVerbosity

    /// 设置指定对话的详细程度。
    func setVerbosity(_ verbosity: ResponseVerbosity, for conversationID: UUID?)

    /// 全局详细程度。
    var globalVerbosity: ResponseVerbosity { get }

    /// 设置全局详细程度。
    func setGlobalVerbosity(_ verbosity: ResponseVerbosity)

    /// 注册对话领域事件观察者，用于将 Provider 事件转换为插件内部状态。
    func addConversationObserver(_ callback: @escaping (ConversationEvent) -> Void) -> any ConversationObserverHandle
}

/// 将内核的 `ConversationManaging` 收窄为 Verbosity 插件的会话能力。
@MainActor
final class ConversationVerbosityCapabilityAdapter: ConversationVerbosityCapability {
    private let conversations: any ConversationManaging

    init(conversations: any ConversationManaging) {
        self.conversations = conversations
    }

    var selectedConversationID: UUID? {
        conversations.selectedConversationID
    }

    func verbosity(for conversationID: UUID?) -> ResponseVerbosity {
        conversations.verbosity(for: conversationID)
    }

    func setVerbosity(_ verbosity: ResponseVerbosity, for conversationID: UUID?) {
        conversations.setVerbosity(verbosity, for: conversationID)
    }

    var globalVerbosity: ResponseVerbosity {
        conversations.globalVerbosity
    }

    func setGlobalVerbosity(_ verbosity: ResponseVerbosity) {
        conversations.setGlobalVerbosity(verbosity)
    }

    func addConversationObserver(_ callback: @escaping (ConversationEvent) -> Void) -> any ConversationObserverHandle {
        conversations.addConversationObserver(callback)
    }
}
