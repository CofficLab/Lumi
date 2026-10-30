import Foundation
import ProviderMessage
import Testing
@testable import PluginMessageListEmpty

/// Covers the async load path of ``EmptyStateActivityViewModel``.
///
/// The sibling `EmptyStateTokenTrendTests` deliberately exercise the pure
/// bucketing helpers with seeded data so they stay deterministic. That leaves
/// `loadIfNeeded(force:)` — the part that actually talks to `MessageManaging` —
/// uncovered, which is exactly where the interesting invariants live: the
/// `loadGeneration` guard against a stale slow load, the same-day cache gate,
/// and the degradation when the provider is missing entirely.

/// Minimal `MessageManaging` stub that can stall a single daily-count query.
///
/// `MessageManaging` provides default implementations for most of its surface,
/// so this stub only fills in the members the view model actually calls plus the
/// two statistic hooks, overridden so the tests can count store round-trips.
@MainActor
private final class StubMessageManager: MessageManaging {
    var messageSeries: [Date: Int] = [:]
    var tokenSeries: [Date: Int] = [:]

    private(set) var messageQueryCount = 0
    private(set) var tokenQueryCount = 0
    private(set) var queriedSince: [Date] = []

    /// When set, the *next* message query suspends until `releaseStalledQuery()`.
    ///
    /// - Important: the snapshot is taken **before** the suspension. A query that
    ///   re-read the series after being released would observe the newer data and
    ///   return it, which would make every staleness assertion pass even with the
    ///   `loadGeneration` guard deleted. Snapshotting on entry is what makes this
    ///   stub able to fail the way a real slow store would.
    private var stallNextMessageQuery = false
    private var stallResumes: [CheckedContinuation<Void, Never>] = []
    private var stallArrivedWaiters: [CheckedContinuation<Void, Never>] = []

    // MARK: - Stall control

    func stallUpcomingMessageQuery() {
        stallNextMessageQuery = true
    }

    /// Suspends until a message query has actually entered the stall, so tests
    /// never depend on how many `Task.yield()` calls it takes to get there.
    func waitUntilQueryStalls() async {
        await withCheckedContinuation { continuation in
            stallArrivedWaiters.append(continuation)
        }
    }

    func releaseStalledQuery() {
        let resumes = stallResumes
        stallResumes.removeAll()
        for continuation in resumes { continuation.resume() }

        let waiters = stallArrivedWaiters
        stallArrivedWaiters.removeAll()
        for continuation in waiters { continuation.resume() }
    }

    // MARK: - Required protocol members

    func messages(for conversationID: UUID) -> [Message] { [] }

    func message(id: UUID, in conversationID: UUID) -> Message? { nil }

    func lastMessage(in conversationID: UUID) -> Message? { nil }

    func messageCount(for conversationID: UUID) -> Int { 0 }

    func insertMessage(_ message: Message, to conversationID: UUID) {}

    func updateMessage(id: UUID, in conversationID: UUID, content: String) {}

    func deleteMessage(id: UUID, in conversationID: UUID) {}

    func clearMessages(in conversationID: UUID) {}

    func updateToolCallResult(
        _ result: MessageToolResult,
        toolCallID: String,
        assistantMessageID: UUID,
        in conversationID: UUID,
        authorizationState: String?
    ) {}

    // MARK: - Statistics

    func dailyMessageCountsAsync(since: Date) async -> [Date: Int] {
        messageQueryCount += 1
        queriedSince.append(since)

        let snapshot = messageSeries
        if stallNextMessageQuery {
            stallNextMessageQuery = false
            await withCheckedContinuation { continuation in
                stallResumes.append(continuation)
                let waiters = stallArrivedWaiters
                stallArrivedWaiters.removeAll()
                for waiter in waiters { waiter.resume() }
            }
        }
        return snapshot
    }

    func dailyTokenCountsAsync(since: Date) async -> [Date: Int] {
        tokenQueryCount += 1
        return tokenSeries
    }
}

@MainActor
@Suite("Empty state activity loading")
struct EmptyStateActivityLoadingTests {
    private let calendar = Calendar(identifier: .gregorian)

    /// Non-throwing on purpose: `#expect` evaluates its operands inside a
    /// non-throwing autoclosure, so a throwing helper cannot be called there.
    /// A `nil` here would mean the test calendar cannot step by one day, which
    /// is not a condition any of these cases are trying to express.
    private func day(_ offsetFromToday: Int) -> Date {
        let today = calendar.startOfDay(for: .now)
        return calendar.date(byAdding: .day, value: offsetFromToday, to: today)!
    }

    @Test("loading fills the window and derives totals from both series")
    func loadPopulatesWindowAndTotals() async throws {
        let manager = StubMessageManager()
        manager.messageSeries = [day(-2): 3, day(0): 5]
        manager.tokenSeries = [day(-2): 1_200, day(0): 800]

        let model = EmptyStateActivityViewModel(messages: manager, calendar: calendar)
        // Before the first load the strip must stay hidden rather than flash an
        // empty grid, so the totals are `nil` — not zero.
        #expect(model.totalMessages == nil)
        #expect(model.hasActivity == false)

        await model.loadIfNeeded()

        #expect(model.days.count == EmptyStateActivityViewModel.windowDayCount)
        #expect(model.totalMessages == 8)
        #expect(model.totalTokens == 2_000)
        #expect(model.hasActivity)
        #expect(model.hasTokenActivity)
        #expect(model.isLoading == false)

        let range = try #require(model.visibleRange)
        #expect(range.lowerBound == day(-29))
        #expect(range.upperBound == day(0))
    }

    @Test("the provider is asked for a window anchored at the model calendar")
    func loadQueriesWindowStart() async throws {
        let manager = StubMessageManager()
        manager.messageSeries = [day(0): 1]

        let model = EmptyStateActivityViewModel(messages: manager, calendar: calendar)
        await model.loadIfNeeded()

        let since = try #require(manager.queriedSince.first)
        #expect(since == day(-(EmptyStateActivityViewModel.windowDayCount - 1)))
    }

    @Test("re-entering the empty state on the same day reuses the loaded window")
    func sameDayReentryHitsTheCacheGate() async throws {
        let manager = StubMessageManager()
        manager.messageSeries = [day(0): 4]

        let model = EmptyStateActivityViewModel(messages: manager, calendar: calendar)
        await model.loadIfNeeded()
        #expect(manager.messageQueryCount == 1)
        #expect(manager.tokenQueryCount == 1)

        // The strip is pure history, so repeated appearances within one calendar
        // day must not re-query the store.
        await model.loadIfNeeded()
        await model.loadIfNeeded()
        #expect(manager.messageQueryCount == 1)
        #expect(manager.tokenQueryCount == 1)
        #expect(model.totalMessages == 4)

        // An explicit force is the documented escape hatch.
        await model.loadIfNeeded(force: true)
        #expect(manager.messageQueryCount == 2)
        #expect(manager.tokenQueryCount == 2)
    }

    @Test("an empty history resolves to zero instead of staying unknown")
    func emptyHistoryResolvesToZero() async throws {
        let manager = StubMessageManager()

        let model = EmptyStateActivityViewModel(messages: manager, calendar: calendar)
        await model.loadIfNeeded()

        // `0` rather than `nil`: the window did load, it simply found nothing.
        // The distinction matters because `hasActivity` maps both to `false`,
        // so only the resolved case may claim it knows there is nothing.
        #expect(model.totalMessages == 0)
        #expect(model.totalTokens == 0)
        #expect(model.hasActivity == false)
        #expect(model.hasTokenActivity == false)
        // The days are still materialized so the range exists; the view decides
        // to render nothing on top of `hasActivity`.
        #expect(model.days.count == EmptyStateActivityViewModel.windowDayCount)
    }

    @Test("a missing message provider degrades to an invisible strip")
    func missingProviderDegrades() async throws {
        let model = EmptyStateActivityViewModel(messages: nil, calendar: calendar)

        await model.loadIfNeeded(force: true)

        // No crash, no spinner: the strip simply never materialises.
        #expect(model.totalMessages == nil)
        #expect(model.hasActivity == false)
        #expect(model.days.isEmpty)
        #expect(model.visibleRange == nil)
        #expect(model.isLoading == false)
    }

    /// Locks the `loadGeneration` guard.
    ///
    /// A slow load from an earlier window must never overwrite a newer result:
    /// the plugin reboots and the conversation selection both change while the
    /// strip is off screen, and whichever query happened to return last would
    /// otherwise win purely because of timing.
    ///
    /// The stub snapshots its series when the query *enters*, so the stalled
    /// query resolves with the older numbers even after the test swaps them.
    @Test("a stale slow load cannot overwrite a newer window")
    func staleSlowLoadLosesToTheNewerOne() async throws {
        let manager = StubMessageManager()
        manager.messageSeries = [day(0): 100]
        manager.tokenSeries = [day(0): 10_000]

        let model = EmptyStateActivityViewModel(messages: manager, calendar: calendar)

        // Start a load whose provider query hangs. It will resolve with 100.
        manager.stallUpcomingMessageQuery()
        let stale = Task { @MainActor in
            await model.loadIfNeeded(force: true)
        }
        await manager.waitUntilQueryStalls()

        // While it is suspended, the underlying history changes and a second
        // load runs to completion against the newer data.
        manager.messageSeries = [day(0): 7]
        manager.tokenSeries = [day(0): 70]
        await model.loadIfNeeded(force: true)
        #expect(model.totalMessages == 7)

        // Now let the stale load finish. Its `generation` no longer matches, so
        // its 100/10_000 must be discarded rather than landing last.
        manager.releaseStalledQuery()
        await stale.value

        #expect(model.totalMessages == 7, "过期的慢加载覆盖了更新的窗口结果")
        #expect(model.totalTokens == 70, "过期的慢加载覆盖了更新的 token 窗口")
        #expect(model.isLoading == false)
    }

    /// Locks the zero-result retry rule.
    ///
    /// A zero result is "the store may not be ready yet", not "the user has no
    /// history". App startup renders the empty state before the cross-conversation
    /// statistics are ready, so the first query legitimately returns 0 and the
    /// data arrives moments later. Treating that 0 as final pinned the strip to
    /// "never shows" for the rest of the session.
    ///
    /// - Important: 只有**非零**结果才命中缓存门。零结果必须保持可重试，
    ///   否则会在启动早期把「还没准备好」永久误判成「确实没有历史」。
    @Test("a zero result stays retryable so late-arriving data still shows")
    func zeroResultDoesNotPinTheStrip() async throws {
        let manager = StubMessageManager()
        // 首次查询：数据尚未就绪。
        manager.messageSeries = [:]

        let model = EmptyStateActivityViewModel(messages: manager, calendar: calendar)
        await model.loadIfNeeded()
        #expect(model.totalMessages == 0)
        #expect(model.hasActivity == false)
        #expect(manager.messageQueryCount == 1)

        // 数据就绪后再次进入空态：零结果不得命中缓存门，必须重查。
        manager.messageSeries = [day(0): 9]
        manager.tokenSeries = [day(0): 100]
        await model.loadIfNeeded()
        #expect(manager.messageQueryCount == 2, "零结果被缓存门钉死，数据就绪后不再重查")
        #expect(model.totalMessages == 9)
        #expect(model.hasActivity, "数据就绪后活动条仍不显示")
    }

    /// 非零结果仍然受益于缓存门：同一天内重复进入不重复查库。
    @Test("a non-zero result still short-circuits repeat queries")
    func nonZeroResultKeepsTheCacheGate() async throws {
        let manager = StubMessageManager()
        manager.messageSeries = [day(0): 3]

        let model = EmptyStateActivityViewModel(messages: manager, calendar: calendar)
        await model.loadIfNeeded()
        #expect(manager.messageQueryCount == 1)

        // 再加一条消息，属于「同一天历史小幅变化」——维持原缓存语义。
        manager.messageSeries = [day(0): 4]
        await model.loadIfNeeded()
        #expect(manager.messageQueryCount == 1, "非零结果不应重复查库")
        #expect(model.totalMessages == 3)
    }

    /// Messages and tokens gate the two visuals independently: a day can have
    /// messages but zero recorded tokens, and the heatmap must survive that.
    @Test("token activity is tracked independently from message activity")
    func tokenActivityIsIndependentFromMessages() async throws {
        let manager = StubMessageManager()
        manager.messageSeries = [day(0): 4]
        manager.tokenSeries = [:]

        let model = EmptyStateActivityViewModel(messages: manager, calendar: calendar)
        await model.loadIfNeeded()

        #expect(model.hasActivity)
        #expect(model.hasTokenActivity == false)
        // The token series is still materialized across the whole window so a
        // later load with data needs no structural change.
        #expect(model.tokenDays.count == EmptyStateActivityViewModel.windowDayCount)
    }
}
