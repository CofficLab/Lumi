#if DEBUG
import LumiChatKit
import Foundation

enum ConversationListPreviewSupport {
    @MainActor
    static func makeChatService() -> ChatService {
        let directory = FileManager.default.temporaryDirectory
            .appendingPathComponent("ConversationListPreview-\(UUID().uuidString)", isDirectory: true)
        return ChatService(configuration: .coreDatabase(directory: directory))
    }

    @MainActor
    static func makeContext() -> ConversationListContext {
        ConversationListContext(chatService: makeChatService())
    }
}
#endif
