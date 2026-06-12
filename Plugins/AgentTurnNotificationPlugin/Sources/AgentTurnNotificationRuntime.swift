import Foundation

@MainActor
public enum AgentTurnNotificationRuntime {
    public static let turnFinishedNotificationName = Notification.Name("agentTurnFinished")

    public static var selectConversation: (UUID) -> Void = { _ in }

    public static func conversationId(from notification: Notification) -> UUID? {
        guard notification.name == turnFinishedNotificationName else {
            return nil
        }

        return notification.object as? UUID
    }
}
