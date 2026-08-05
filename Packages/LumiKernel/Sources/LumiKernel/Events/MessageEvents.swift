import Foundation
import SwiftUI

// MARK: - UserInfo Keys

public enum LumiMessageSavedNotification {
    public static let messageIDKey = "messageID"
    public static let conversationIDKey = "conversationID"
    public static let roleKey = "role"
}

public enum LumiOnboardingNotification {
    public static let resetKey = "reset"
}

public enum LumiTurnFinishedNotification {
    public static let turnIDKey = "turnID"
    public static let parentConversationIDKey = "parentConversationID"
    public static let reasonKey = "reason"
}

public enum LumiTurnStartedNotification {
    public static let turnIDKey = "turnID"
    public static let parentConversationIDKey = "parentConversationID"
}

public extension LumiTurnEndReason {
    init?(notificationUserInfo userInfo: [AnyHashable: Any]?) {
        guard let raw = userInfo?[LumiTurnFinishedNotification.reasonKey] as? String,
              let reason = LumiTurnEndReason(rawValue: raw)
        else { return nil }
        self = reason
    }
}

// MARK: - SwiftUI View Extensions

@MainActor
public extension View {
    /// 监听 `.lumiMessagesDidChange` 通知
    func onLumiMessagesDidChange(perform action: @escaping () -> Void) -> some View {
        self.onReceive(NotificationCenter.default.publisher(for: .lumiMessagesDidChange)) { _ in
            action()
        }
    }

    /// 监听 `.lumiMessagesDidChange` 通知，并传出发生变化的会话 ID。
    ///
    /// 旧调用方可继续使用无参数版本；消息列表等高成本消费者应使用此重载，
    /// 避免其他会话的消息变化触发无关刷新。
    func onLumiMessagesDidChange(perform action: @escaping (UUID?) -> Void) -> some View {
        self.onReceive(NotificationCenter.default.publisher(for: .lumiMessagesDidChange)) { notification in
            action(notification.lumiConversationID)
        }
    }
}
