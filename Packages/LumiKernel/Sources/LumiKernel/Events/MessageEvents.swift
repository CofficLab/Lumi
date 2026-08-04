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
}
