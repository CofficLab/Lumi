import Foundation
import SwiftUI

/// Kernel-level event names centralized in LumiKernel.
///
/// 这些事件由内核统一发出，插件与 UI 层通过 NotificationCenter 订阅。
/// 新增事件时优先在这里补定义，再由 EventManager 统一发射。
public enum LumiKernelEvent: String, CaseIterable, Sendable {
    case enabledPluginsDidChange = "com.coffic.lumi.enabledPluginsDidChange"
    case messagesDidChange = "com.coffic.lumi.messagesDidChange"
    case conversationsDidChange = "com.coffic.lumi.conversationsDidChange"
    case conversationTitleDidChange = "com.coffic.lumi.conversationTitleDidChange"
    case conversationDidDelete = "com.coffic.lumi.conversationDidDelete"
    case conversationWillDelete = "com.coffic.lumi.conversationWillDelete"
    case themeDidChange = "com.coffic.lumi.themeDidChange"

    case messageSaved = "com.coffic.lumi.messageSaved"
    case turnStarted = "com.coffic.lumi.turnStarted"
    case turnCompleted = "com.coffic.lumi.turnCompleted"
    case turnFinished = "com.coffic.lumi.turnFinished"

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
    static let lumiThemeDidChange = LumiKernelEvent.themeDidChange.notificationName

    static let lumiMessagesDidChange = LumiKernelEvent.messagesDidChange.notificationName
    static let lumiMessageSaved = LumiKernelEvent.messageSaved.notificationName
    static let lumiTurnStarted = LumiKernelEvent.turnStarted.notificationName
    static let lumiTurnCompleted = LumiKernelEvent.turnCompleted.notificationName
    static let lumiTurnFinished = LumiKernelEvent.turnFinished.notificationName

    static let lumiShowOnboarding = Notification.Name("Onboarding.Show")

    static let lumiFocusChatInput = Notification.Name("lumi.focusChatInput")
    static let lumiSendChatMessage = Notification.Name("lumi.sendChatMessage")
    static let lumiStopChatGeneration = Notification.Name("lumi.stopChatGeneration")
    static let lumiResendMessage = Notification.Name("lumi.resendMessage")

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

// MARK: - Kernel NotificationCenter Posting Helpers

public extension NotificationCenter {
    /// 发送 `.lumiEnabledPluginsDidChange` 通知
    static func postLumiEnabledPluginsDidChange() {
        NotificationCenter.default.post(name: .lumiEnabledPluginsDidChange, object: nil)
    }

    /// 发送 `.lumiThemeDidChange` 通知
    static func postLumiThemeDidChange() {
        NotificationCenter.default.post(name: .lumiThemeDidChange, object: nil)
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

    /// 监听 `.lumiThemeDidChange` 通知
    func onLumiThemeDidChange(perform action: @escaping () -> Void) -> some View {
        self.onReceive(NotificationCenter.default.publisher(for: .lumiThemeDidChange)) { _ in
            action()
        }
    }

    /// 监听 `.lumiTurnStarted` 通知
    func onLumiTurnStarted(perform action: @escaping () -> Void) -> some View {
        self.onReceive(NotificationCenter.default.publisher(for: .lumiTurnStarted)) { _ in
            action()
        }
    }

    /// 监听 `.lumiTurnStarted` 通知，并传出该 turn 所属的会话 ID。
    ///
    /// 与 `onLumiMessagesDidChange(perform: (UUID?) -> Void)` 同理：高成本消费者
    /// 可借此过滤掉其他会话的 turn 事件，避免无关刷新。
    func onLumiTurnStarted(perform action: @escaping (UUID?) -> Void) -> some View {
        self.onReceive(NotificationCenter.default.publisher(for: .lumiTurnStarted)) { notification in
            action(notification.lumiConversationID)
        }
    }

    /// 监听 `.lumiTurnCompleted` 通知
    func onLumiTurnCompleted(perform action: @escaping () -> Void) -> some View {
        self.onReceive(NotificationCenter.default.publisher(for: .lumiTurnCompleted)) { _ in
            action()
        }
    }

    /// 监听 `.lumiTurnCompleted` 通知，并传出该 turn 所属的会话 ID。
    func onLumiTurnCompleted(perform action: @escaping (UUID?) -> Void) -> some View {
        self.onReceive(NotificationCenter.default.publisher(for: .lumiTurnCompleted)) { notification in
            action(notification.lumiConversationID)
        }
    }

    /// 监听 `.lumiTurnFinished` 通知
    func onLumiTurnFinished(perform action: @escaping () -> Void) -> some View {
        self.onReceive(NotificationCenter.default.publisher(for: .lumiTurnFinished)) { _ in
            action()
        }
    }

    /// 监听 `.lumiTurnFinished` 通知，并传出该 turn 所属的会话 ID。
    func onLumiTurnFinished(perform action: @escaping (UUID?) -> Void) -> some View {
        self.onReceive(NotificationCenter.default.publisher(for: .lumiTurnFinished)) { notification in
            action(notification.lumiConversationID)
        }
    }
}
