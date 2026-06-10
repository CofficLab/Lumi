import LumiCoreKit

extension ChatService: HistoryQueryService {
    public func fetchMessageCount() async -> Int {
        store.historyMessageCount()
    }

    public func fetchMessagePage(limit: Int, offset: Int) async -> [HistoryMessageRow] {
        store.historyMessagePage(limit: limit, offset: offset)
    }

    public func fetchConversationCount() async -> Int {
        store.historyConversationCount()
    }

    public func fetchConversationPage(limit: Int, offset: Int) async -> [HistoryConversationRow] {
        store.historyConversationPage(limit: limit, offset: offset)
    }
}
