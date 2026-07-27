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

    static let lumiSelectedRemoteProviderIDDidChange = LumiKernelEvent.selectedRemoteProviderIDDidChange.notificationName
    static let lumiSelectedLocalProviderIDDidChange = LumiKernelEvent.selectedLocalProviderIDDidChange.notificationName
    static let lumiSelectedModelsDidChange = LumiKernelEvent.selectedModelsDidChange.notificationName
    static let lumiRoutingModeDidChange = LumiKernelEvent.routingModeDidChange.notificationName
    static let lumiProviderAvailabilityDidChange = LumiKernelEvent.providerAvailabilityDidChange.notificationName
    static let lumiProviderStatusesDidChange = LumiKernelEvent.providerStatusesDidChange.notificationName
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
