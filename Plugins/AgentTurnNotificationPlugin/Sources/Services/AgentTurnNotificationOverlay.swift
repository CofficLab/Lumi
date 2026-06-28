import AppKit
import SuperLogKit
import LumiCoreKit
import SwiftUI
import UserNotifications

/// 监听 `AgentTurnService` turn 结束事件并发出系统通知的 Overlay 视图
public struct AgentTurnNotificationOverlay<Content: View>: View {
    public let content: Content
    @StateObject private var handler = AgentTurnNotificationHandler()

    public var body: some View {
        content
            .onAppear {
                handler.bind()
            }
            .onReceive(NotificationCenter.default.publisher(for: .lumiTurnCompleted)) { notification in
                guard let conversationId = notification.userInfo?[LumiMessageSavedNotification.conversationIDKey] as? UUID else {
                    return
                }
                handler.postTurnFinishedNotification(conversationId: conversationId)
            }
    }
}

/// 实际执行通知发送逻辑的 Handler
@MainActor
public final class AgentTurnNotificationHandler: NSObject, ObservableObject, SuperLog {
    private let center = UNUserNotificationCenter.current()

    // MARK: - Setup

    /// 注册为通知中心代理
    public func bind() {
        center.delegate = self
        AgentTurnNotificationPlugin.logger.debug("\(Self.t)Notification center delegate configured")
    }

    // MARK: - Notification Posting

    public func postTurnFinishedNotification(conversationId: UUID) {
        center.getNotificationSettings { settings in
            guard settings.authorizationStatus == .authorized else {
                // 未授权通知，请求授权
                Task {
                    await self.requestAuthorizationAndPost(conversationId: conversationId)
                }
                return
            }

            // 已授权，直接发送
            Task {
                await self.deliverNotification(conversationId: conversationId)
            }
        }
    }

    private func requestAuthorizationAndPost(conversationId: UUID) async {
        do {
            let granted = try await center.requestAuthorization(options: [.alert, .sound, .badge])
            if granted {
                await deliverNotification(conversationId: conversationId)
            }
        } catch {
            AgentTurnNotificationPlugin.logger.error("\(Self.t)Notification authorization failed: \(error.localizedDescription)")
        }
    }

    private func deliverNotification(conversationId: UUID) async {
        let notificationContent = UNMutableNotificationContent()
        notificationContent.title = LumiPluginLocalization.string("Lumi Agent", bundle: .module)
        notificationContent.body = LumiPluginLocalization.string("Agent 回合已结束", bundle: .module)
        notificationContent.sound = .default
        notificationContent.userInfo = ["conversationId": conversationId.uuidString]

        let request = UNNotificationRequest(
            identifier: "agent-turn-\(conversationId.uuidString)",
            content: notificationContent,
            trigger: nil
        )

        do {
            try await center.add(request)
            AgentTurnNotificationPlugin.logger.debug("\(Self.t)Posted turn completed notification for \(conversationId.uuidString)")
        } catch {
            AgentTurnNotificationPlugin.logger.error("\(Self.t)Failed to post notification: \(error.localizedDescription)")
        }
    }
}

// MARK: - UNUserNotificationCenterDelegate

extension AgentTurnNotificationHandler: UNUserNotificationCenterDelegate {
    /// 用户点击通知时的回调
    /// 激活应用窗口并选中对应的对话
    public nonisolated func userNotificationCenter(
        _ center: UNUserNotificationCenter,
        didReceive response: UNNotificationResponse,
        withCompletionHandler completionHandler: @escaping () -> Void
    ) {
        let userInfo = response.notification.request.content.userInfo

        // 从 userInfo 中提取 conversationId
        guard let conversationIdString = userInfo["conversationId"] as? String,
              let conversationId = UUID(uuidString: conversationIdString) else {
            AgentTurnNotificationPlugin.logger.warning("\(Self.t)Notification missing conversationId")
            completionHandler()
            return
        }

        AgentTurnNotificationPlugin.logger.debug("\(Self.t)User opened notification for conversation \(conversationId.uuidString)")

        Task { @MainActor in
            // 1. 激活应用
            NSApp.activate(ignoringOtherApps: true)

            // 2. 显示主窗口
            if let window = NSApp.windows.first {
                window.makeKeyAndOrderFront(nil)
            }

            AgentTurnNotificationRuntime.selectConversation(conversationId)

            AgentTurnNotificationPlugin.logger.debug("\(Self.t)Selected conversation \(conversationId.uuidString)")
        }
        completionHandler()
    }
}
