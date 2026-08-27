import Foundation

/// 对话管理器的语义变更事件。
@MainActor
public enum ConversationEvent: Sendable, Equatable {
    case created(UUID)
    case selected(UUID?)
    case deleted(UUID)
    case updated(UUID)
    case markedActive(UUID)
    case providerChanged(UUID)
    case verbosityChanged(UUID?)
    case reasoningChanged(UUID?)
    case automationChanged(UUID?)
    case languageChanged(UUID?)
}

/// 对话事件观察令牌。
@MainActor
public protocol ConversationObserverHandle: AnyObject {
    func cancel()
}

/// 不需要事件实现的轻量 ConversationManaging 测试替身兼容令牌。
@MainActor
public final class NoopConversationObserverHandle: ConversationObserverHandle {
    public init() {}
    public func cancel() {}
}
