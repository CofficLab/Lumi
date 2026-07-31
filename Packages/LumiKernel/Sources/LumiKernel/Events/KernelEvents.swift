import Foundation
import SwiftUI

// MARK: - Kernel Event Names

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

public enum LumiNotificationUserInfoKey {
    public static let conversationID = "conversationID"
}

public extension Notification {
    var lumiConversationID: UUID? {
        userInfo?[LumiNotificationUserInfoKey.conversationID] as? UUID
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

// MARK: - Kernel NotificationCenter Posting Helpers

public extension NotificationCenter {
    /// 发送 `.lumiEnabledPluginsDidChange` 通知
    static func postLumiEnabledPluginsDidChange() {
        NotificationCenter.default.post(name: .lumiEnabledPluginsDidChange, object: nil)
    }

    /// 发送 `.lumiMessagesDidChange` 通知
    static func postLumiMessagesDidChange() {
        NotificationCenter.default.post(name: .lumiMessagesDidChange, object: nil)
    }

    /// 发送 `.lumiConversationsDidChange` 通知
    static func postLumiConversationsDidChange() {
        NotificationCenter.default.post(name: .lumiConversationsDidChange, object: nil)
    }

    /// 发送 `.lumiThemeDidChange` 通知
    static func postLumiThemeDidChange() {
        NotificationCenter.default.post(name: .lumiThemeDidChange, object: nil)
    }

    /// 发送 `.lumiSelectedRemoteProviderIDDidChange` 通知
    static func postLumiSelectedRemoteProviderIDDidChange() {
        NotificationCenter.default.post(name: .lumiSelectedRemoteProviderIDDidChange, object: nil)
    }

    /// 发送 `.lumiSelectedLocalProviderIDDidChange` 通知
    static func postLumiSelectedLocalProviderIDDidChange() {
        NotificationCenter.default.post(name: .lumiSelectedLocalProviderIDDidChange, object: nil)
    }

    /// 发送 `.lumiSelectedModelsDidChange` 通知
    static func postLumiSelectedModelsDidChange() {
        NotificationCenter.default.post(name: .lumiSelectedModelsDidChange, object: nil)
    }

    /// 发送 `.lumiRoutingModeDidChange` 通知
    static func postLumiRoutingModeDidChange() {
        NotificationCenter.default.post(name: .lumiRoutingModeDidChange, object: nil)
    }

    /// 发送 `.lumiProviderAvailabilityDidChange` 通知
    static func postLumiProviderAvailabilityDidChange() {
        NotificationCenter.default.post(name: .lumiProviderAvailabilityDidChange, object: nil)
    }

    /// 发送 `.lumiProviderStatusesDidChange` 通知
    static func postLumiProviderStatusesDidChange() {
        NotificationCenter.default.post(name: .lumiProviderStatusesDidChange, object: nil)
    }
}

// MARK: - Kernel SwiftUI View Extensions

@MainActor
public extension View {
    /// 监听 `.lumiEnabledPluginsDidChange` 通知
    func onLumiEnabledPluginsDidChange(perform action: @escaping () -> Void) -> some View {
        self.onReceive(NotificationCenter.default.publisher(for: .lumiEnabledPluginsDidChange)) { _ in
            action()
        }
    }

    /// 监听 `.lumiMessagesDidChange` 通知
    func onLumiMessagesDidChange(perform action: @escaping () -> Void) -> some View {
        self.onReceive(NotificationCenter.default.publisher(for: .lumiMessagesDidChange)) { _ in
            action()
        }
    }

    /// 监听 `.lumiConversationsDidChange` 通知
    func onLumiConversationsDidChange(perform action: @escaping () -> Void) -> some View {
        self.onReceive(NotificationCenter.default.publisher(for: .lumiConversationsDidChange)) { _ in
            action()
        }
    }

    /// 监听 `.lumiThemeDidChange` 通知
    func onLumiThemeDidChange(perform action: @escaping () -> Void) -> some View {
        self.onReceive(NotificationCenter.default.publisher(for: .lumiThemeDidChange)) { _ in
            action()
        }
    }

    /// 监听 `.lumiSelectedRemoteProviderIDDidChange` 通知
    func onLumiSelectedRemoteProviderIDDidChange(perform action: @escaping () -> Void) -> some View {
        self.onReceive(NotificationCenter.default.publisher(for: .lumiSelectedRemoteProviderIDDidChange)) { _ in
            action()
        }
    }

    /// 监听 `.lumiSelectedLocalProviderIDDidChange` 通知
    func onLumiSelectedLocalProviderIDDidChange(perform action: @escaping () -> Void) -> some View {
        self.onReceive(NotificationCenter.default.publisher(for: .lumiSelectedLocalProviderIDDidChange)) { _ in
            action()
        }
    }

    /// 监听 `.lumiSelectedModelsDidChange` 通知
    func onLumiSelectedModelsDidChange(perform action: @escaping () -> Void) -> some View {
        self.onReceive(NotificationCenter.default.publisher(for: .lumiSelectedModelsDidChange)) { _ in
            action()
        }
    }

    /// 监听 `.lumiRoutingModeDidChange` 通知
    func onLumiRoutingModeDidChange(perform action: @escaping () -> Void) -> some View {
        self.onReceive(NotificationCenter.default.publisher(for: .lumiRoutingModeDidChange)) { _ in
            action()
        }
    }

    /// 监听 `.lumiProviderAvailabilityDidChange` 通知
    func onLumiProviderAvailabilityDidChange(perform action: @escaping () -> Void) -> some View {
        self.onReceive(NotificationCenter.default.publisher(for: .lumiProviderAvailabilityDidChange)) { _ in
            action()
        }
    }

    /// 监听 `.lumiProviderStatusesDidChange` 通知
    func onLumiProviderStatusesDidChange(perform action: @escaping () -> Void) -> some View {
        self.onReceive(NotificationCenter.default.publisher(for: .lumiProviderStatusesDidChange)) { _ in
            action()
        }
    }
}
