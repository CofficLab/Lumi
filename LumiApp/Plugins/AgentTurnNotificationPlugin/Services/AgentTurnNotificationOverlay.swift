import SwiftUI
import UserNotifications
import os

/// 监听 `AgentTurnService` turn 结束事件并发出系统通知的 Overlay 视图
struct AgentTurnNotificationOverlay<Content: View>: View, SuperLog {
    nonisolated static let logger = Logger(
        subsystem: "com.coffic.lumi", category: "plugin.turn-notification-overlay")

    let content: Content

    @StateObject private var handler = AgentTurnNotificationHandler()

    var body: some View {
        content
            .onAgentTurnFinished { conversationId in
                handler.postTurnFinishedNotification(conversationId: conversationId)
            }
    }
}

/// 实际执行通知发送逻辑的 Handler
@MainActor
final class AgentTurnNotificationHandler: ObservableObject {
    private let center = UNUserNotificationCenter.current()

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
            AppLogger.core.info("已发送 turn 结束通知: \(conversationId)")
        } catch {
            AppLogger.core.error("发送 turn 结束通知失败: \(error)")
        }
    }
}
