import Testing
import Foundation
@testable import HistoryDBStatusBarPlugin
@testable import LumiKernel

/// 用于测试的 Mock 实现
@MainActor
final class MockHistoryQueryService: HistoryQueryService {
    var messageCount: Int = 0
    var conversationCount: Int = 0
    var messagePages: [Int: [HistoryMessageRow]] = [:]   // offset → rows
    var conversationPages: [Int: [HistoryConversationRow]] = [:]
    var messagePageRequests: [(limit: Int, offset: Int)] = []
    var conversationPageRequests: [(limit: Int, offset: Int)] = []
    var messagePageDelayNanoseconds: UInt64 = 0
    var conversationPageDelayNanoseconds: UInt64 = 0
    /// Day (local-midnight `Date`) → message count, returned verbatim by
    /// `fetchDailyMessageCounts(since:)`.
    var dailyMessageCounts: [Date: Int] = [:]
    /// Captures every `since` argument the service was queried with.
    private(set) var dailyMessageCountsRequests: [Date] = []

    /// Day (local-midnight `Date`) → token count, returned verbatim by
    /// `fetchDailyTokenCounts(since:)`.
    var dailyTokenCounts: [Date: Int] = [:]
    /// Captures every `since` argument the token query was queried with.
    private(set) var dailyTokenCountsRequests: [Date] = []

    func fetchMessageCount() async -> Int {
        messageCount
    }

    func fetchMessagePage(limit: Int, offset: Int) async -> [HistoryMessageRow] {
        messagePageRequests.append((limit: limit, offset: offset))
        if messagePageDelayNanoseconds > 0 {
            try? await Task.sleep(nanoseconds: messagePageDelayNanoseconds)
        }
        return messagePages[offset] ?? []
    }

    func fetchConversationCount() async -> Int {
        conversationCount
    }

    func fetchConversationPage(limit: Int, offset: Int) async -> [HistoryConversationRow] {
        conversationPageRequests.append((limit: limit, offset: offset))
        if conversationPageDelayNanoseconds > 0 {
            try? await Task.sleep(nanoseconds: conversationPageDelayNanoseconds)
        }
        return conversationPages[offset] ?? []
    }

    func fetchDailyMessageCounts(since: Date) async -> [Date: Int] {
        dailyMessageCountsRequests.append(since)
        return dailyMessageCounts
    }

    func fetchDailyTokenCounts(since: Date) async -> [Date: Int] {
        dailyTokenCountsRequests.append(since)
        return dailyTokenCounts
    }
}
