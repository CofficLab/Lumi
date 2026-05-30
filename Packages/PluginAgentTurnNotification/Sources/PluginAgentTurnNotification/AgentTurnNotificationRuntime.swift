import Foundation

@MainActor
public enum AgentTurnNotificationRuntime {
    public static var selectConversation: (UUID) -> Void = { _ in }
}
