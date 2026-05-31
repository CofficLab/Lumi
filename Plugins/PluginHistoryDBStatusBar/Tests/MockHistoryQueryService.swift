import Testing
import Foundation
@testable import PluginHistoryDBStatusBar
@testable import LumiCoreKit

/// 用于测试的 Mock 实现
@MainActor
final class MockHistoryQueryService: HistoryQueryService {
    var messageCount: Int = 0
    var conversationCount: Int = 0
    var messagePages: [Int: [HistoryMessageRow]] = [:]   // offset → rows
    var conversationPages: [Int: [HistoryConversationRow]] = [:]
    var messagePageRequests: [(limit: Int, offset: Int)] = []
    var conversationPageRequests: [(limit: Int, offset: Int)] = []

    func fetchMessageCount() async -> Int {
        messageCount
    }

    func fetchMessagePage(limit: Int, offset: Int) async -> [HistoryMessageRow] {
        messagePageRequests.append((limit: limit, offset: offset))
        return messagePages[offset] ?? []
    }

    func fetchConversationCount() async -> Int {
        conversationCount
    }

    func fetchConversationPage(limit: Int, offset: Int) async -> [HistoryConversationRow] {
        conversationPageRequests.append((limit: limit, offset: offset))
        return conversationPages[offset] ?? []
    }
}
