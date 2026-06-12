import LumiCoreKit

@MainActor
public enum ChatMessagesRuntime {
    public static var messagesProvider: () -> [ChatMessage] = { [] }
    public static var hasConversationProvider: () -> Bool = { false }
    public static var resendMessage: (String) -> Void = { _ in }

    public static var messages: [ChatMessage] {
        messagesProvider()
    }

    public static var hasConversation: Bool {
        hasConversationProvider()
    }
}
