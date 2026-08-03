import Foundation
import SwiftUI

// MARK: - Notification.Name

public extension Notification.Name {
    static let lumiMessagesDidChange = LumiKernelEvent.messagesDidChange.notificationName

    static let lumiFocusChatInput = Notification.Name("lumi.focusChatInput")
    static let lumiSendChatMessage = Notification.Name("lumi.sendChatMessage")
    static let lumiStopChatGeneration = Notification.Name("lumi.stopChatGeneration")
    static let lumiMessageSaved = Notification.Name("lumi.messageSaved")
    static let lumiTurnCompleted = Notification.Name("lumi.turnCompleted")
    static let lumiTurnFinished = Notification.Name("lumi.turnFinished")
    static let lumiTurnStarted = Notification.Name("lumi.turnStarted")
    static let lumiShowOnboarding = Notification.Name("Onboarding.Show")
    static let lumiResendMessage = Notification.Name("lumi.resendMessage")
}

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

// MARK: - NotificationCenter Posting Helpers

public extension NotificationCenter {
    /// 发送 `.lumiMessagesDidChange` 通知
    static func postLumiMessagesDidChange() {
        NotificationCenter.default.post(name: .lumiMessagesDidChange, object: nil)
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
