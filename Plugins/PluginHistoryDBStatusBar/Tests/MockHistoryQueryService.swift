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

    func fetchMessageCount() async -> Int {
        messageCount
    }

    func fetchMessagePage(limit: Int, offset: Int) async -> [HistoryMessageRow] {
        messagePages[offset] ?? []
    }

    func fetchConversationCount() async -> Int {
        conversationCount
    }

    func fetchConversationPage(limit: Int, offset: Int) async -> [HistoryConversationRow] {
        conversationPages[offset] ?? []
    }
}
