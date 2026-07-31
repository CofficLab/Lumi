import Foundation

/// Kernel-level event names centralized in LumiKernel.
///
/// 这些事件由内核统一发出，插件与 UI 层通过 NotificationCenter 订阅。
/// 新增事件时优先在这里补定义，再由 EventManager 统一发射。
public enum LumiKernelEvent: String, CaseIterable, Sendable {
    case enabledPluginsDidChange = "com.coffic.lumi.enabledPluginsDidChange"
    case messagesDidChange = "com.coffic.lumi.messagesDidChange"
    case conversationsDidChange = "com.coffic.lumi.conversationsDidChange"
    case themeDidChange = "com.coffic.lumi.themeDidChange"
    /// 流式输出生命周期事件（打字机效果）。
    ///
    /// 流式期间全程不查库：runner 节流后以此事件推送累积全文，
    /// UI 原地 patch 那一条临时消息。结束后由 `.messagesDidChange` 兜底覆盖。
    case messageStreaming = "com.coffic.lumi.messageStreaming"

    case selectedRemoteProviderIDDidChange = "LumiProviderState.SelectedRemoteProviderIDDidChange"
    case selectedLocalProviderIDDidChange = "LumiProviderState.SelectedLocalProviderIDDidChange"
    case selectedModelsDidChange = "LumiProviderState.SelectedModelsDidChange"
    case routingModeDidChange = "LumiProviderState.RoutingModeDidChange"
    case providerAvailabilityDidChange = "LumiProviderState.AvailabilityDidChange"
    case providerStatusesDidChange = "LumiProviderState.StatusesDidChange"

    public var notificationName: Notification.Name {
        Notification.Name(rawValue)
    }
}

public extension Notification.Name {
    static let lumiEnabledPluginsDidChange = LumiKernelEvent.enabledPluginsDidChange.notificationName
    static let lumiMessagesDidChange = LumiKernelEvent.messagesDidChange.notificationName
    static let lumiConversationsDidChange = LumiKernelEvent.conversationsDidChange.notificationName
    static let lumiThemeDidChange = LumiKernelEvent.themeDidChange.notificationName
    /// 流式输出生命周期事件别名（start / delta / end）。
    static let lumiMessageStreaming = LumiKernelEvent.messageStreaming.notificationName

    static let lumiSelectedRemoteProviderIDDidChange = LumiKernelEvent.selectedRemoteProviderIDDidChange.notificationName
    static let lumiSelectedLocalProviderIDDidChange = LumiKernelEvent.selectedLocalProviderIDDidChange.notificationName
    static let lumiSelectedModelsDidChange = LumiKernelEvent.selectedModelsDidChange.notificationName
    static let lumiRoutingModeDidChange = LumiKernelEvent.routingModeDidChange.notificationName
    static let lumiProviderAvailabilityDidChange = LumiKernelEvent.providerAvailabilityDidChange.notificationName
    static let lumiProviderStatusesDidChange = LumiKernelEvent.providerStatusesDidChange.notificationName
}

public enum LumiNotificationUserInfoKey {
    public static let conversationID = "conversationID"

    // MARK: - 流式输出（messageStreaming）
    /// 流式消息的目标消息 id（与最终落库消息同 id，用于平滑覆盖临时行）。
    public static let messageID = "messageID"
    /// 流式生命周期阶段：`"start"` / `"delta"` / `"end"`，见 `LumiStreamingKind`。
    public static let streamingKind = "streamingKind"
    /// 累积全文（每次 delta 都带完整内容，便于 UI 直接替换）。
    public static let content = "content"
    /// 当前增量是否为思考内容（reasoning）。
    public static let isThinking = "isThinking"
}

/// 流式输出生命周期阶段。
public enum LumiStreamingKind: String, Sendable {
    /// runner 调 LLM 前，先发 start：UI 追加一条临时 assistant 行。
    case start
    /// onChunk 累积并节流后发 delta：UI 原地替换该消息文本/思考内容。
    case delta
    /// 流式结束（可省略，通常由 `.messagesDidChange` 兜底覆盖）。
    case end
}

public extension Notification {
    var lumiConversationID: UUID? {
        userInfo?[LumiNotificationUserInfoKey.conversationID] as? UUID
    }

    // MARK: - 流式输出便捷访问器
    var lumiStreamingMessageID: UUID? {
        userInfo?[LumiNotificationUserInfoKey.messageID] as? UUID
    }

    var lumiStreamingKind: LumiStreamingKind? {
        guard let raw = userInfo?[LumiNotificationUserInfoKey.streamingKind] as? String else {
            return nil
        }
        return LumiStreamingKind(rawValue: raw)
    }

    /// 累积全文（delta 阶段始终携带；start 阶段为空串）。
    var lumiStreamingContent: String {
        (userInfo?[LumiNotificationUserInfoKey.content] as? String) ?? ""
    }

    var lumiStreamingIsThinking: Bool {
        (userInfo?[LumiNotificationUserInfoKey.isThinking] as? Bool) ?? false
    }
}

/// Convenience helper for subscribing to enabled-plugins-changed events.
public extension NotificationCenter {
    /// Subscribe to `.lumiEnabledPluginsDidChange`.
    /// Returns an opaque observer token that must be passed to `removeObserver(_:)` in `deinit`.
    @MainActor
    func onLumiEnabledPluginsDidChange(_ handler: @escaping () -> Void) -> NSObjectProtocol {
        addObserver(forName: .lumiEnabledPluginsDidChange, object: nil, queue: .main) { _ in
            handler()
        }
    }

    /// Subscribe to `.lumiThemeDidChange`.
    /// Returns an opaque observer token that must be passed to `removeObserver(_:)` in `deinit`.
    @MainActor
    func onLumiThemeDidChange(_ handler: @escaping () -> Void) -> NSObjectProtocol {
        addObserver(forName: .lumiThemeDidChange, object: nil, queue: .main) { _ in
            handler()
        }
    }
}
