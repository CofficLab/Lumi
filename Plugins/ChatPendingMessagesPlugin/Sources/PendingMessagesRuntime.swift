import Foundation
import LumiCoreKit

@MainActor
public enum PendingMessagesRuntime {
    public static var titleProvider: () -> String = { "" }
    public static var messagesProvider: () -> [AgentChatMessage] = { [] }
    public static var removeMessage: (UUID) -> Void = { _ in }

    public static var title: String { titleProvider() }
    public static var messages: [AgentChatMessage] { messagesProvider() }
}
