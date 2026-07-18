#if DEBUG
import LumiCoreKit
import Foundation

enum ConversationListPreviewSupport {
    @MainActor
    static func makeChatService() -> ChatService {
        let directory = FileManager.default.temporaryDirectory
            .appendingPathComponent("ConversationListPreview-\(UUID().uuidString)", isDirectory: true)
        // Preview 场景：数据库建在临时目录，失败无恢复价值，用 try! 简化（仅 DEBUG）。
        return try! ChatService(configuration: .coreDatabase(directory: directory))
    }

    @MainActor
    static func makeContext() -> ConversationListContext {
        ConversationListContext(chatService: makeChatService())
    }
}
#endif
