import Foundation
import UserNotifications
#if os(macOS)
import AppKit
#endif

/// 处理回合通知点击：把宿主应用带到前台，并选中通知对应的会话。
///
/// 通知正文里的 `conversationId` 由发送侧写入 `UNNotificationContent.userInfo`；
/// 缺少该字段（旧通知）或值非法时只完成回调，不改变当前选中会话。
@MainActor
final class TurnNotificationTapHandler: NSObject, UNUserNotificationCenterDelegate {
    nonisolated static let conversationIDKey = "conversationId"

    private let activateApplication: @MainActor () -> Void
    private let selectConversation: @MainActor (UUID) -> Void

    init(
        activateApplication: @escaping @MainActor () -> Void,
        selectConversation: @escaping @MainActor (UUID) -> Void
    ) {
        self.activateApplication = activateApplication
        self.selectConversation = selectConversation
    }

    nonisolated static func conversationID(in userInfo: [AnyHashable: Any]) -> UUID? {
        guard let raw = userInfo[conversationIDKey] as? String else { return nil }
        return UUID(uuidString: raw)
    }

    /// 返回是否从 `userInfo` 中解析出会话并完成路由。
    @discardableResult
    func handleTap(userInfo: [AnyHashable: Any]) -> Bool {
        guard let conversationID = Self.conversationID(in: userInfo) else { return false }
        activateApplication()
        selectConversation(conversationID)
        return true
    }

    nonisolated func userNotificationCenter(
        _ center: UNUserNotificationCenter,
        didReceive response: UNNotificationResponse,
        withCompletionHandler completionHandler: @escaping () -> Void
    ) {
        let conversationID = Self.conversationID(
            in: response.notification.request.content.userInfo
        )
        completionHandler()
        guard let conversationID else { return }
        Task { @MainActor [weak self] in
            guard let self else { return }
            self.activateApplication()
            self.selectConversation(conversationID)
        }
    }

    /// iOS 点击通知会自动激活应用，只有 macOS 需要显式前置窗口。
    @MainActor
    static func activateHostApplication() {
        #if os(macOS)
        guard let app = NSApp else { return }
        app.activate(ignoringOtherApps: true)
        app.windows.first?.makeKeyAndOrderFront(nil)
        #endif
    }
}
