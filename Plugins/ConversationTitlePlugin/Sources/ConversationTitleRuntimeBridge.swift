import Foundation
import LumiKernel

@MainActor
enum ConversationTitleRuntimeBridge {
    static var chatServiceProvider: (@MainActor () -> (any LumiChatServicing)?)?
    static var inFlightConversationIds = Set<UUID>()
}
