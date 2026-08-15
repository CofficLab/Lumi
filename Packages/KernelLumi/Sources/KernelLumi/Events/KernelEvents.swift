import Foundation
import SwiftUI

/// Kernel-level event names centralized in KernelLumi.
///
/// 这些事件由内核统一发出，插件与 UI 层通过 NotificationCenter 订阅。
/// 新增事件时优先在这里补定义，再由 EventManager 统一发射。
public enum KernelLumiEvent: String, CaseIterable, Sendable {
    case enabledPluginsDidChange = "com.coffic.lumi.enabledPluginsDidChange"
    case messagesDidChange = "com.coffic.lumi.messagesDidChange"
    case conversationsDidChange = "com.coffic.lumi.conversationsDidChange"
    case conversationDidCreate = "com.coffic.lumi.conversationDidCreate"
    case selectedConversationDidChange = "com.coffic.lumi.selectedConversationDidChange"
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
    /// LLM provider registry changed (initial registration or runtime rebuild).
    case llmProvidersDidChange = "LumiProviderState.LLMProvidersDidChange"

    /// 工具调用记录已写入 ToolManager 存储后触发。
    case toolActivityDidChange = "Lumi.ToolActivityDidChange"

    /// 本地 Web 服务处理完一次请求后触发,携带 `WebRequestActivity`。
    case webRequestReceived = "com.coffic.lumi.webRequestReceived"

    /// 屏幕录制会话状态变化时触发，携带 `RecordingActivity`。
    case recordingStateChanged = "com.coffic.lumi.recordingStateChanged"

    /// 工作区布局事件。rawValue 对齐既有 `Notification.Name` 常量，
    /// 订阅端不受影响；统一由 `EventManager` 发射。
    case activeViewContainerIDDidChange = "ActiveViewContainerIDDidChange"
    case activeRailTabIDDidChange = "ActiveRailTabIDDidChange"
    case activeBottomTabIDDidChange = "ActiveBottomTabIDDidChange"
    case bottomPanelVisibleDidChange = "BottomPanelVisibleDidChange"
    case chatSectionVisibleDidChange = "ChatSectionVisibleDidChange"
    case railVisibleDidChange = "RailVisibleDidChange"
    case railDividerDidChange = "RailDividerDidChange"
    case chatSectionDividerDidChange = "ChatSectionDividerDidChange"
    case bottomPanelDividerDidChange = "BottomPanelDividerDidChange"
    case workspaceContributionsDidChange = "WorkspaceContributionsDidChange"

    public var notificationName: Notification.Name {
        Notification.Name(rawValue)
    }
}

public extension Notification.Name {
    static let lumiEnabledPluginsDidChange = KernelLumiEvent.enabledPluginsDidChange.notificationName
    static let lumiThemeDidChange = KernelLumiEvent.themeDidChange.notificationName

    static let lumiMessagesDidChange = KernelLumiEvent.messagesDidChange.notificationName
    static let lumiMessageSaved = KernelLumiEvent.messageSaved.notificationName
    static let lumiTurnStarted = KernelLumiEvent.turnStarted.notificationName
    static let lumiTurnCompleted = KernelLumiEvent.turnCompleted.notificationName
    static let lumiTurnFinished = KernelLumiEvent.turnFinished.notificationName

    static let lumiWebRequestReceived = KernelLumiEvent.webRequestReceived.notificationName
    static let lumiRecordingStateChanged = KernelLumiEvent.recordingStateChanged.notificationName

    static let lumiShowOnboarding = Notification.Name("Onboarding.Show")

    /// 请求打开设置窗口。
    ///
    /// 由"应用菜单"中的"Settings..."命令发出（`SettingsPlugin`），
    /// 由主窗口根视图（`WindowMain`）监听并调用 `openWindow(id:)` 打开设置窗口。
    /// 这样菜单命令闭包（非视图上下文）可以与 SwiftUI 的开窗动作解耦。
    static let lumiOpenSettings = Notification.Name("lumi.openSettings")

    /// 请求打开设置窗口并定位到指定标签页。
    ///
    /// userInfo 携带目标标签 id（见 `LumiNotificationUserInfoKey.settingsTabID`）。
    /// 由 `WindowMain` 监听开窗，设置窗口内的 `SettingsView` 消费目标标签。
    static let lumiOpenSettingsTab = Notification.Name("lumi.openSettingsTab")

    static let lumiFocusChatInput = Notification.Name("lumi.focusChatInput")
    static let lumiSendChatMessage = Notification.Name("lumi.sendChatMessage")
    static let lumiStopChatGeneration = Notification.Name("lumi.stopChatGeneration")
    static let lumiResendMessage = Notification.Name("lumi.resendMessage")

    static let lumiSelectedRemoteProviderIDDidChange = KernelLumiEvent.selectedRemoteProviderIDDidChange.notificationName
    static let lumiSelectedLocalProviderIDDidChange = KernelLumiEvent.selectedLocalProviderIDDidChange.notificationName
    static let lumiSelectedModelsDidChange = KernelLumiEvent.selectedModelsDidChange.notificationName
    static let lumiLLMProvidersDidChange = KernelLumiEvent.llmProvidersDidChange.notificationName
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

    /// 监听 `.lumiTurnFinished` 通知，并传出会话 ID、父会话 ID 和结束原因。
    ///
    /// `parentConversationID` 非 nil 表示该 turn 属于子 Agent。
    func onLumiTurnFinished(perform action: @escaping (_ conversationID: UUID?, _ parentConversationID: UUID?, _ reason: LumiTurnEndReason?) -> Void) -> some View {
        self.onReceive(NotificationCenter.default.publisher(for: .lumiTurnFinished)) { notification in
            let conversationID = notification.lumiConversationID
            let parentConversationID = notification.userInfo?[LumiTurnFinishedNotification.parentConversationIDKey] as? UUID
            let reason = LumiTurnEndReason(notificationUserInfo: notification.userInfo)
            action(conversationID, parentConversationID, reason)
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

    /// 监听 `.lumiLLMProvidersDidChange` 通知
    func onLumiLLMProvidersDidChange(perform action: @escaping () -> Void) -> some View {
        self.onReceive(NotificationCenter.default.publisher(for: .lumiLLMProvidersDidChange)) { _ in
            action()
        }
    }

    /// 监听 `.lumiShowOnboarding` 通知，并传出是否要求强制重置（`userInfo["reset"]`）。
    func onLumiShowOnboarding(perform action: @escaping (Bool) -> Void) -> some View {
        self.onReceive(NotificationCenter.default.publisher(for: .lumiShowOnboarding)) { notification in
            let forceReset = notification.userInfo?[LumiOnboardingNotification.resetKey] as? Bool ?? false
            action(forceReset)
        }
    }

    /// 监听 `.lumiWebRequestReceived` 通知,并传出该次请求的活动记录。
    func onLumiWebRequestReceived(perform action: @escaping (WebRequestActivity) -> Void) -> some View {
        self.onReceive(NotificationCenter.default.publisher(for: .lumiWebRequestReceived)) { notification in
            if let activity = notification.lumiWebRequestActivity {
                action(activity)
            }
        }
    }

    /// 监听 `.lumiRecordingStateChanged` 通知，并传出录制状态变化记录。
    func onLumiRecordingStateChanged(perform action: @escaping (RecordingActivity) -> Void) -> some View {
        self.onReceive(NotificationCenter.default.publisher(for: .lumiRecordingStateChanged)) { notification in
            if let activity = notification.lumiRecordingActivity {
                action(activity)
            }
        }
    }
}
