import Foundation
import Testing
import LumiKernel
@testable import MessageListAppKitPlugin

/// Performance-focused tests for the AppKit message-list plugin.
///
/// These tests verify that the performance gates from the plan are met:
/// - Snapshot build/apply times stay within bounds
/// - Pagination keeps initial page small even for large conversations
/// - Repeated refreshes do not grow the row count unboundedly
/// - Conversation switches complete quickly
///
/// The gates are intentionally loose to avoid flaky failures on slower CI
/// machines, but tight enough to catch major regressions.
@Suite(.serialized)
@MainActor
struct AppKitMessageListPerformanceTests {

    // MARK: - Fixtures

    /// Build a conversation with N mixed messages (some plain, some Markdown, some code).
    private func seedMixedConversation(
        count: Int,
        conversationID: UUID,
        messages: MockMessageManager
    ) {
        for i in 0..<count {
            let content: String
            switch i % 4 {
            case 0:
                content = "Plain message \(i)"
            case 1:
                content = "**Bold** and *italic* message \(i) with `inline code`"
            case 2:
                content = """
                ```swift
                func hello() {
                    print("world \\(\\(i))")
                }
                ```
                """
            default:
                content = """
                # Heading \(i)

                - List item 1
                - List item 2
                - List item 3

                > Quote block
                """
            }
            let message = LumiChatMessage(
                id: UUID(),
                conversationID: conversationID,
                role: .assistant,
                content: content,
                turnID: nil,
                createdAt: Date(timeIntervalSinceReferenceDate: 100 + Double(i))
            )
            messages.seed([message], conversationID: conversationID)
        }
    }

    private func makeCoordinator(
        messages: MockMessageManager,
        pageSize: Int = 40
    ) -> AppKitMessageListCoordinator {
        AppKitMessageListCoordinator(
            dependencies: .init(
                conversations: MockConversationManager(),
                messageManager: messages,
                agentTurnManager: MockAgentTurnManager(),
                messageStreaming: MockMessageStreaming(),
                messageSender: nil
            ),
            pageSize: pageSize
        )
    }

    private func elapsedMilliseconds(_ interval: Duration) -> Double {
        let components = interval.components
        return Double(components.seconds) * 1000
            + Double(components.attoseconds) / 1_000_000_000_000_000
    }

    // MARK: - Snapshot build/apply performance

    @Test("40-row snapshot builds within 500ms")
    func snapshot40Rows() async throws {
        let conversationID = UUID()
        let messages = MockMessageManager()
        seedMixedConversation(count: 40, conversationID: conversationID, messages: messages)
        let coordinator = makeCoordinator(messages: messages, pageSize: 40)

        let start = ContinuousClock.now
        await coordinator.activate(conversationID: conversationID)
        let elapsed = ContinuousClock.now - start

        let snapshot = coordinator.latestSnapshot
        #expect(snapshot.conversationID == conversationID)
        #expect(snapshot.displayRows.count == 40)

        let ms = elapsedMilliseconds(elapsed)
        #expect(ms < 500, "Snapshot build took \(ms)ms, expected < 500ms")
    }

    @Test("300-row snapshot: pagination keeps initial page at 40")
    func snapshot300Rows() async throws {
        let conversationID = UUID()
        let messages = MockMessageManager()
        seedMixedConversation(count: 300, conversationID: conversationID, messages: messages)
        let coordinator = makeCoordinator(messages: messages, pageSize: 40)

        let start = ContinuousClock.now
        await coordinator.activate(conversationID: conversationID)
        let elapsed = ContinuousClock.now - start

        let snapshot = coordinator.latestSnapshot
        #expect(snapshot.conversationID == conversationID)
        #expect(snapshot.displayRows.count == 40, "Expected 40 rows, got \(snapshot.displayRows.count)")

        let ms = elapsedMilliseconds(elapsed)
        #expect(ms < 1000, "Snapshot build took \(ms)ms, expected < 1000ms")
    }

    @Test("1000-row conversation: pagination keeps initial page small")
    func snapshot1000RowsPagination() async throws {
        let conversationID = UUID()
        let messages = MockMessageManager()
        seedMixedConversation(count: 1000, conversationID: conversationID, messages: messages)
        let coordinator = makeCoordinator(messages: messages, pageSize: 40)

        await coordinator.activate(conversationID: conversationID)

        let snapshot = coordinator.latestSnapshot
        #expect(snapshot.conversationID == conversationID)
        #expect(snapshot.displayRows.count == 40, "Initial page should be 40 rows, got \(snapshot.displayRows.count)")
        #expect(snapshot.displayRows.first?.message != nil)
        #expect(snapshot.displayRows.last?.message != nil)
    }

    // MARK: - Layout cache performance

    @Test("Layout cache: repeated measurements with the same key hit the cache")
    func layoutCacheHitRate() async throws {
        let cache = AppKitMessageLayoutCache()
        let theme = AppKitMessageTheme.systemDefault()
        let message = LumiChatMessage(
            id: UUID(),
            conversationID: UUID(),
            role: .assistant,
            content: "**Test** message with `code`",
            turnID: nil,
            createdAt: Date()
        )
        let row = AppKitMessageRow(
            kind: .assistant,
            message: message,
            sourceTurnID: nil
        )

        let key = AppKitRowLayoutKey(
            rowID: row.id,
            contentHash: "test-hash",
            availableWidth: 400,
            scale: 2.0,
            themeRevision: theme.revision,
            verbosity: "standard"
        )

        // First measure: cache miss, fallback computes the value
        let firstHeight = cache.height(for: key, fallback: { 120 })
        #expect(firstHeight == 120)

        // Second measure: should hit the cache, fallback is not called
        let secondHeight = cache.height(for: key, fallback: { 999 })
        #expect(secondHeight == 120, "Second call should return cached 120, not fallback 999")

        // Different width: cache miss, new entry
        let key2 = AppKitRowLayoutKey(
            rowID: row.id,
            contentHash: "test-hash",
            availableWidth: 600,
            scale: 2.0,
            themeRevision: theme.revision,
            verbosity: "standard"
        )
        let thirdHeight = cache.height(for: key2, fallback: { 200 })
        #expect(thirdHeight == 200)
    }

    // MARK: - Memory stability

    @Test("Repeated refreshes do not grow the row count unboundedly")
    func memoryStabilityOnRepeatedRefresh() async throws {
        let conversationID = UUID()
        let messages = MockMessageManager()
        seedMixedConversation(count: 100, conversationID: conversationID, messages: messages)
        let coordinator = makeCoordinator(messages: messages, pageSize: 40)

        await coordinator.activate(conversationID: conversationID)
        let initialCount = coordinator.latestSnapshot.displayRows.count

        // Simulate 10 refreshes (like receiving notifications)
        for _ in 0..<10 {
            _ = await coordinator.refresh()
        }

        let finalCount = coordinator.latestSnapshot.displayRows.count
        #expect(finalCount == initialCount, "Row count should remain stable after refreshes: was \(initialCount), now \(finalCount)")
    }

    // MARK: - Conversation switch performance

    @Test("Conversation switch: snapshot replaces cleanly")
    func conversationSwitchPerformance() async throws {
        let conversationA = UUID()
        let conversationB = UUID()
        let messages = MockMessageManager()
        seedMixedConversation(count: 50, conversationID: conversationA, messages: messages)
        seedMixedConversation(count: 50, conversationID: conversationB, messages: messages)
        let coordinator = makeCoordinator(messages: messages, pageSize: 40)

        // Load A
        await coordinator.activate(conversationID: conversationA)
        let snapshotA = coordinator.latestSnapshot
        #expect(snapshotA.conversationID == conversationA)
        #expect(snapshotA.displayRows.count == 40)

        // Switch to B
        let start = ContinuousClock.now
        await coordinator.activate(conversationID: conversationB)
        let elapsed = ContinuousClock.now - start

        let snapshotB = coordinator.latestSnapshot
        #expect(snapshotB.conversationID == conversationB)
        #expect(snapshotB.displayRows.count == 40)

        let ms = elapsedMilliseconds(elapsed)
        #expect(ms < 500, "Conversation switch took \(ms)ms, expected < 500ms")
    }
}
