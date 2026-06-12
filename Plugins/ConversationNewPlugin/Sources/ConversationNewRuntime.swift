import Foundation

public enum ConversationNewRuntime {
    nonisolated(unsafe) public static var createConversation: () async -> Void = {}
}
