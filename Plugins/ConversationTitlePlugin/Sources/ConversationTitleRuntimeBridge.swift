import Foundation
import LumiCoreKit

@MainActor
enum ConversationTitleRuntimeBridge {
    static var chatServiceProvider: (@MainActor () -> (any LumiChatServicing)?)?
    static var inFlightConversationIds = Set<UUID>()
}
