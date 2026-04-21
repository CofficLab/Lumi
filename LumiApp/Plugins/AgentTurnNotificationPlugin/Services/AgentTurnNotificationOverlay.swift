import AppKit
import SwiftUI
import UserNotifications
import MagicKit

/// 监听 `AgentTurnService` turn 结束事件并发出系统通知的 Overlay 视图
struct AgentTurnNotificationOverlay<Content: View>: View, SuperLog {
    nonisolated static var emoji: String { "🔔" }
    nonisolated static var verbose: Bool { true }

    let content: Content

    @StateObject private var handler = AgentTurnNotificationHandler()

    var body: some View {
        content
            .onAgentTurnFinished { conversationId in
                handler.postTurnFinishedNotification(conversationId: conversationId)
            }
            .onAppear {
                handler.setupNotificationDelegate()
            }
    }
}

/// 实际执行通知发送逻辑的 Handler
@MainActor
final class AgentTurnNotificationHandler: NSObject, ObservableObject, SuperLog {
    nonisolated static var emoji: String { "🔔" }
    nonisolated static var verbose: Bool { false }

    private let center = UNUserNotificationCenter.current()

    // MARK: - Setup

    /// 设置通知中心代理，处理用户点击通知的事件
    func setupNotificationDelegate() {
        // 只在首次设置，避免重复设置代理
        if !(center.delegate is AgentTurnNotificationHandler) {
            center.delegate = self
            if Self.verbose {
                AppLogger.core.info("已设置通知中心代理")
            }
        }
    }

    // MARK: - Notification Posting

    func postTurnFinishedNotification(conversationId: UUID) {
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
            AppLogger.core.error("请求通知权限失败: \(error)")
        }
    }

    private func deliverNotification(conversationId: UUID) async {
        let notificationContent = UNMutableNotificationContent()
        notificationContent.title = String(localized: "Lumi Agent")
        notificationContent.body = String(localized: "Agent 回合已结束")
        notificationContent.sound = .default
        notificationContent.userInfo = ["conversationId": conversationId.uuidString]

        let request = UNNotificationRequest(
            identifier: "agent-turn-\(conversationId.uuidString)",
            content: notificationContent,
            trigger: nil
        )

        do {
            try await center.add(request)
            if Self.verbose {
                AppLogger.core.info("已发送 turn 结束通知: \(conversationId)")
            }
        } catch {
            AppLogger.core.error("发送 turn 结束通知失败: \(error)")
        }
    }
}

// MARK: - UNUserNotificationCenterDelegate

extension AgentTurnNotificationHandler: UNUserNotificationCenterDelegate {
    /// 用户点击通知时的回调
    /// 激活应用窗口并选中对应的对话
    nonisolated func userNotificationCenter(
        _ center: UNUserNotificationCenter,
        didReceive response: UNNotificationResponse,
        withCompletionHandler completionHandler: @escaping () -> Void
    ) {
        let userInfo = response.notification.request.content.userInfo

        // 从 userInfo 中提取 conversationId
        guard let conversationIdString = userInfo["conversationId"] as? String,
              let conversationId = UUID(uuidString: conversationIdString) else {
            if Self.verbose {
                AppLogger.core.info("通知中未找到有效的 conversationId")
            }
            completionHandler()
            return
        }

        if Self.verbose {
            AppLogger.core.info("用户点击了通知，准备选中对话: \(conversationId)")
        }

        Task { @MainActor in
            // 1. 激活应用
            NSApp.activate(ignoringOtherApps: true)

            // 2. 显示主窗口
            if let window = NSApp.windows.first {
                window.makeKeyAndOrderFront(nil)
            }

            // 3. 选中对应的对话
            RootViewContainer.shared.conversationVM.setSelectedConversation(conversationId)

            if Self.verbose {
                AppLogger.core.info("已选中对话: \(conversationId)")
            }
        }
        completionHandler()
    }
}
