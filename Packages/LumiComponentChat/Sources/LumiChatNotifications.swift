import Foundation
import LumiComponentTurn

public enum LumiMessageSavedNotification {
    public static let messageIDKey = "messageID"
    public static let conversationIDKey = "conversationID"
    public static let roleKey = "role"
}

public enum LumiOnboardingNotification {
    public static let resetKey = "reset"
}

public enum LumiTurnFinishedNotification {
    public static let reasonKey = "reason"
}

public enum LumiAskUserNotification {
    public static let conversationIDKey = "conversationID"
    public static let toolCallIDKey = "toolCallID"
    public static let answerKey = "answer"
}

public extension Notification.Name {
    static let lumiFocusChatInput = Notification.Name("lumi.focusChatInput")
    static let lumiSendChatMessage = Notification.Name("lumi.sendChatMessage")
    static let lumiStopChatGeneration = Notification.Name("lumi.stopChatGeneration")
    /// 消息已保存。**唯一发送方：`LumiChatKit.MessageManager.postMessageSavedNotification(for:)`**。
    /// userInfo: `LumiMessageSavedNotification.messageIDKey` / `.conversationIDKey` / `.roleKey`。
    /// 订阅方：ConversationTitlePlugin（过滤 role==.user）、HistoryDBStatusBarPlugin。
    static let lumiMessageSaved = Notification.Name("lumi.messageSaved")
    /// Turn 正常完成（仅 `LumiTurnEndReason.completed`）。**唯一发送方：`LumiChatKit.SendPipeline.appendTurnCompletedMarker`**。
    /// 订阅方：AgentTurnNotificationPlugin 的系统通知 overlay。保留以兼容现有监听方。
    static let lumiTurnCompleted = Notification.Name("lumi.turnCompleted")
    /// Turn 结束（携带 `LumiTurnFinishedNotification.reasonKey`）。
    /// **唯一发送方：`LumiChatKit.SendPipeline`**（`finishTurn` 与 `appendTurnCompletedMarker`）。
    static let lumiTurnFinished = Notification.Name("lumi.turnFinished")
    static let lumiShowOnboarding = Notification.Name("Onboarding.Show")
    static let lumiResendMessage = Notification.Name("lumi.resendMessage")
    /// AskUser 用户已回答，需要恢复 Agent 循环。
    /// **唯一发送方：`AskUserPlugin.AskUserBridge`**。
    static let lumiAskUserDidAnswer = Notification.Name("lumi.askUserDidAnswer")
}

public extension LumiTurnEndReason {
    init?(notificationUserInfo userInfo: [AnyHashable: Any]?) {
        guard let raw = userInfo?[LumiTurnFinishedNotification.reasonKey] as? String,
              let reason = LumiTurnEndReason(rawValue: raw)
        else {
            return nil
        }
        self = reason
    }
}
