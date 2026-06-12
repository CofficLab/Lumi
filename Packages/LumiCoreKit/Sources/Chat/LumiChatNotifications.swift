import Foundation

public enum LumiMessageSavedNotification {
    public static let messageIDKey = "messageID"
    public static let conversationIDKey = "conversationID"
    public static let roleKey = "role"
}

public enum LumiOnboardingNotification {
    public static let resetKey = "reset"
}

public extension Notification.Name {
    static let lumiFocusChatInput = Notification.Name("lumi.focusChatInput")
    static let lumiSendChatMessage = Notification.Name("lumi.sendChatMessage")
    static let lumiStopChatGeneration = Notification.Name("lumi.stopChatGeneration")
    static let lumiMessageSaved = Notification.Name("lumi.messageSaved")
    static let lumiTurnCompleted = Notification.Name("lumi.turnCompleted")
    static let lumiShowOnboarding = Notification.Name("Onboarding.Show")
}
