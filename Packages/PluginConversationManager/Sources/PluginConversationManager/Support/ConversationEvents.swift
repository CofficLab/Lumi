import Foundation
import KernelCore

// MARK: - Typed conversation events (KernelCoreEventBus)
//
// 旧版 ConversationManager 通过 `kernel.eventManager.post*` 发 4 种通知:
// conversationsDidChange / conversationDidCreate / selectedConversationDidChange /
// conversationTitleDidChange。v2 无事件管理器,ConversationManager 用 `@Published`
// 广播状态变化(registerProvider 默认转发到容器),同时把变更以类型化事件发布到
// KernelCoreEventBus,并桥接为旧 NotificationCenter 通知(字符串名与旧版一致),
// 让尚未迁移的 NotificationCenter 消费者(如按 `.lumiConversationsDidChange`
// 刷新的视图)继续工作。

public struct ConversationsDidChangeEvent: KernelEvent {
    public init() {}
}

public struct ConversationDidCreateEvent: KernelEvent {
    public let conversationID: UUID
    public init(conversationID: UUID) {
        self.conversationID = conversationID
    }
}

public struct SelectedConversationDidChangeEvent: KernelEvent {
    public let conversationID: UUID?
    public init(conversationID: UUID?) {
        self.conversationID = conversationID
    }
}

public struct ConversationTitleDidChangeEvent: KernelEvent {
    public let conversationID: UUID
    public init(conversationID: UUID) {
        self.conversationID = conversationID
    }
}

public extension Notification.Name {
    /// 通知名与旧版 KernelLumi 完全一致,保证旧消费者兼容。
    static let lumiConversationsDidChange = Notification.Name("com.coffic.lumi.conversationsDidChange")
    static let lumiConversationDidCreate = Notification.Name("com.coffic.lumi.conversationDidCreate")
    static let lumiSelectedConversationDidChange = Notification.Name("com.coffic.lumi.selectedConversationDidChange")
    static let lumiConversationTitleDidChange = Notification.Name("com.coffic.lumi.conversationTitleDidChange")
}
