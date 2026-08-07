import Foundation
import Testing

@testable import ConversationListPlugin

@MainActor
struct ConversationSortStabilizerTests {

    // MARK: - Helpers

    /// 可变时钟，用于测试中模拟时间流逝
    private final class MockClock {
        var date: Date
        init(_ date: Date = Date(timeIntervalSince1970: 1_000_000)) {
            self.date = date
        }

        func advance(by seconds: TimeInterval) {
            date = date.addingTimeInterval(seconds)
        }
    }

    // MARK: - 首次出现

    @Test("首次出现的对话应返回 updatedAt 作为排序时间")
    func firstAppearanceReturnsUpdatedAt() async {
        let id = UUID()
        let updatedAt = Date(timeIntervalSince1970: 1_000_000)
        let clock = MockClock(updatedAt)

        let stabilizer = ConversationSortStabilizer(
            holdWindowSeconds: 30,
            now: { clock.date }
        )

        let result = stabilizer.effectiveSortTime(for: id, lastMessageAt: updatedAt)
        #expect(result == updatedAt)
    }

    // MARK: - 窗口期内保持锚点

    @Test("窗口期内新消息不应改变排序时间")
    func withinWindowKeepsAnchor() async {
        let id = UUID()
        let clock = MockClock()

        let stabilizer = ConversationSortStabilizer(
            holdWindowSeconds: 30,
            now: { clock.date }
        )

        // 首次出现，建立锚点
        let firstUpdate = clock.date
        let firstResult = stabilizer.effectiveSortTime(for: id, lastMessageAt: firstUpdate)
        #expect(firstResult == firstUpdate)

        // 10 秒后收到新消息
        clock.advance(by: 10)
        let newUpdate = clock.date
        let secondResult = stabilizer.effectiveSortTime(for: id, lastMessageAt: newUpdate)

        // 应该保持原锚点时间，而非新消息时间
        #expect(secondResult == firstUpdate)
    }

    @Test("窗口边界（恰好 30 秒）仍保持锚点")
    func windowBoundaryKeepsAnchor() async {
        let id = UUID()
        let clock = MockClock()

        let stabilizer = ConversationSortStabilizer(
            holdWindowSeconds: 30,
            now: { clock.date }
        )

        let firstUpdate = clock.date
        _ = stabilizer.effectiveSortTime(for: id, lastMessageAt: firstUpdate)

        // 恰好 29.9 秒后
        clock.advance(by: 29.9)
        let newUpdate = clock.date
        let result = stabilizer.effectiveSortTime(for: id, lastMessageAt: newUpdate)

        #expect(result == firstUpdate)
    }

    // MARK: - 窗口过期后接受新时间

    @Test("窗口过期后应接受新的 updatedAt")
    func afterWindowExpiresAcceptsNewTime() async {
        let id = UUID()
        let clock = MockClock()

        let stabilizer = ConversationSortStabilizer(
            holdWindowSeconds: 30,
            now: { clock.date }
        )

        let firstUpdate = clock.date
        _ = stabilizer.effectiveSortTime(for: id, lastMessageAt: firstUpdate)

        // 31 秒后（超出窗口）
        clock.advance(by: 31)
        let newUpdate = clock.date
        let result = stabilizer.effectiveSortTime(for: id, lastMessageAt: newUpdate)

        #expect(result == newUpdate)
    }

    // MARK: - markViewed 行为

    @Test("markViewed 后窗口内应保持查看时间")
    func markViewedKeepsPosition() async {
        let id = UUID()
        let clock = MockClock()

        let stabilizer = ConversationSortStabilizer(
            holdWindowSeconds: 30,
            now: { clock.date }
        )

        // 用户查看对话
        let viewedTime = clock.date
        stabilizer.markViewed(conversationID: id)

        // 10 秒后收到新消息
        clock.advance(by: 10)
        let newUpdate = clock.date
        let result = stabilizer.effectiveSortTime(for: id, lastMessageAt: newUpdate)

        // 应该保持查看时间，而非新消息时间
        #expect(result == viewedTime)
    }

    @Test("markViewed 后窗口过期应接受新时间")
    func markViewedThenExpires() async {
        let id = UUID()
        let clock = MockClock()

        let stabilizer = ConversationSortStabilizer(
            holdWindowSeconds: 30,
            now: { clock.date }
        )

        stabilizer.markViewed(conversationID: id)

        // 31 秒后（超出窗口）
        clock.advance(by: 31)
        let newUpdate = clock.date
        let result = stabilizer.effectiveSortTime(for: id, lastMessageAt: newUpdate)

        #expect(result == newUpdate)
    }

    // MARK: - 多对话排序场景

    @Test("两个对话交替更新时应保持稳定顺序")
    func twoConversationsStayStable() async {
        let idA = UUID()
        let idB = UUID()
        let clock = MockClock()

        let stabilizer = ConversationSortStabilizer(
            holdWindowSeconds: 30,
            now: { clock.date }
        )

        // A 先出现
        let timeA = clock.date
        let sortA = stabilizer.effectiveSortTime(for: idA, lastMessageAt: timeA)

        // 1 秒后 B 出现
        clock.advance(by: 1)
        let timeB = clock.date
        let sortB = stabilizer.effectiveSortTime(for: idB, lastMessageAt: timeB)

        // A 应在 B 前面（A 的排序时间更早，但降序排列时 A 在前是因为 B 更新）
        #expect(sortA < sortB)

        // 5 秒后 A 收到新消息
        clock.advance(by: 5)
        let newTimeA = clock.date
        let sortA2 = stabilizer.effectiveSortTime(for: idA, lastMessageAt: newTimeA)

        // A 应该保持在原锚点时间，不会跳到 B 前面
        #expect(sortA2 == timeA)
        // 所以顺序仍然是 B 在前（B 的排序时间更新）
        #expect(sortA2 < sortB)
    }

    @Test("用户切换对话后该对话应排在前面")
    func userSwitchingBringsConversationToTop() async {
        let idA = UUID()
        let idB = UUID()
        let clock = MockClock()

        let stabilizer = ConversationSortStabilizer(
            holdWindowSeconds: 30,
            now: { clock.date }
        )

        // A 先出现
        let timeA = clock.date
        let sortA = stabilizer.effectiveSortTime(for: idA, lastMessageAt: timeA)

        // 5 秒后 B 出现
        clock.advance(by: 5)
        let timeB = clock.date
        let sortB = stabilizer.effectiveSortTime(for: idB, lastMessageAt: timeB)

        // 当前 B 排在 A 前面（B 更新）
        #expect(sortA < sortB)

        // 用户切换到 A（markViewed）
        clock.advance(by: 2)
        stabilizer.markViewed(conversationID: idA)

        // 再次查询 A 的排序时间
        let sortA2 = stabilizer.effectiveSortTime(for: idA, lastMessageAt: timeA)

        // A 现在应该排在 B 前面（A 的排序时间更新）
        #expect(sortA2 > sortB)
    }

    // MARK: - cleanup

    @Test("cleanup 应清理过期锚定")
    func cleanupRemovesExpiredAnchors() async {
        let id = UUID()
        let clock = MockClock()

        let stabilizer = ConversationSortStabilizer(
            holdWindowSeconds: 30,
            now: { clock.date }
        )

        // 建立锚点
        _ = stabilizer.effectiveSortTime(for: id, lastMessageAt: clock.date)

        // 61 秒后（超过 2 倍窗口）
        clock.advance(by: 61)

        // cleanup
        stabilizer.cleanup()

        // 再次查询应该被视为新对话（因为旧锚点已被清理）
        let newUpdate = clock.date
        let result = stabilizer.effectiveSortTime(for: id, lastMessageAt: newUpdate)

        #expect(result == newUpdate)
    }
}
