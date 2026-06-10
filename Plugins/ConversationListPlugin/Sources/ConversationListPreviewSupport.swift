#if DEBUG
import LumiChatKit
import Foundation

enum ConversationListPreviewSupport {
    @MainActor
    static func makeContext() -> ConversationListContext {
        let directory = FileManager.default.temporaryDirectory
            .appendingPathComponent("ConversationListPreview-\(UUID().uuidString)", isDirectory: true)
        let chatService = ChatService(configuration: .coreDatabase(directory: directory))
        return ConversationListContext(chatService: chatService)
    }
}
#endif
