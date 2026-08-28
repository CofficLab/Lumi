import Foundation

/// 一个空实现的观察句柄，用于默认的 `addConversationStateObserver` 回退。
@MainActor
public final class NoopConversationStateObserverHandle: ConversationStateObserverHandle {
    public init() {}
    public func cancel() {}
}
