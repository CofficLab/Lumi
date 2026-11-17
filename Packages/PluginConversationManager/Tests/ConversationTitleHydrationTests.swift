import Foundation
import ProviderConversation
import Testing
@testable import PluginConversationManager

/// 回归 #641：只有首页 40 条会话进缓存。选中分页里的旧会话时，`selectConversation`
/// 立刻按旧缓存算出 `currentTitle == "No conversation"`；随后项目同步/分页读取
/// 把真实摘要补进缓存（`for summary in page { cache(summary) }`），但 `cache`
/// 既不重算标题也不发事件，标题栏于是一直停在 "No conversation"。
///
/// 修复：`cache` 写入的正是当前选中会话时重算 `currentTitle`，标题真的变化才发
/// `.updated`，让 `ConversationTitleHeaderObserver` 重新读取标题。
@MainActor
@Suite(.serialized)
struct ConversationTitleHydrationTests {

    @Test func pageHydrationOfSelectedConversationPublishesRealTitle() async throws {
        let manager = try makeManager()
        var events: [ConversationEvent] = []
        let handle = manager.addConversationObserver { events.append($0) }
        defer { handle.cancel() }

        let id = UUID()
        manager.selectConversation(id: id)
        // 选中瞬间缓存里没有它：标题退化成占位文案。
        #expect(manager.currentTitle == "No conversation")

        // 分页读取把这一页补进缓存（生产路径逐条调用 cache）。
        manager.cache(ConversationSummary(id: id, title: "Older project"))

        #expect(manager.currentTitle == "Older project")
        #expect(events.contains(.updated(id)))
        try await Task.sleep(for: .milliseconds(20))
    }

    @Test func hydratedSummaryEntryAlsoRefreshesTitle() async throws {
        let manager = try makeManager()
        var events: [ConversationEvent] = []
        let handle = manager.addConversationObserver { events.append($0) }
        defer { handle.cancel() }

        let id = UUID()
        manager.selectConversation(id: id)
        #expect(manager.currentTitle == "No conversation")

        manager.cacheHydratedSummary(ConversationSummary(id: id, title: "Hydrated title"))

        #expect(manager.currentTitle == "Hydrated title")
        #expect(events.contains(.updated(id)))
        try await Task.sleep(for: .milliseconds(20))
    }

    @Test func staleCachedTitleIsCorrectedByLaterHydration() async throws {
        let manager = try makeManager()
        let id = UUID()
        // 缓存里已有一份旧摘要：选中时的按 ID 补载会因「已在缓存」直接跳过，
        // 只有后续分页补载能带来真实标题。
        manager.conversations = [ConversationSummary(id: id, title: "Stale title")]
        manager.selectConversation(id: id)
        #expect(manager.currentTitle == "Stale title")

        var events: [ConversationEvent] = []
        let handle = manager.addConversationObserver { events.append($0) }
        defer { handle.cancel() }

        manager.cache(ConversationSummary(id: id, title: "Real title"))

        #expect(manager.currentTitle == "Real title")
        #expect(events.contains(.updated(id)))
        try await Task.sleep(for: .milliseconds(20))
    }

    @Test func hydrationOfOtherConversationKeepsSelectedTitle() async throws {
        let manager = try makeManager()
        let selectedID = UUID()
        manager.conversations = [ConversationSummary(id: selectedID, title: "Selected")]
        manager.selectConversation(id: selectedID)

        var events: [ConversationEvent] = []
        let handle = manager.addConversationObserver { events.append($0) }
        defer { handle.cancel() }

        let otherID = UUID()
        manager.cache(ConversationSummary(id: otherID, title: "Other"))

        // 补载别的会话不得改写选中项标题，也不得为它发标题事件。
        #expect(manager.currentTitle == "Selected")
        #expect(!events.contains(.updated(otherID)))
        try await Task.sleep(for: .milliseconds(20))
    }

    @Test func repeatedHydrationWithSameTitleDoesNotRepublish() async throws {
        let manager = try makeManager()
        let id = UUID()
        let summary = ConversationSummary(id: id, title: "Stable")
        manager.conversations = [summary]
        manager.selectConversation(id: id)

        var events: [ConversationEvent] = []
        let handle = manager.addConversationObserver { events.append($0) }
        defer { handle.cancel() }

        // 整页补载会反复写入同一条摘要：标题没变就不再发事件（避免通知风暴）。
        manager.cache(summary)
        manager.cache(summary)

        #expect(manager.currentTitle == "Stable")
        #expect(!events.contains(.updated(id)))
        try await Task.sleep(for: .milliseconds(20))
    }

    private func makeManager() throws -> ConversationManager {
        let directory = FileManager.default.temporaryDirectory
            .appendingPathComponent("ConversationTitleHydration-\(UUID().uuidString)", isDirectory: true)
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        return ConversationManager(store: nil, dataDirectory: directory)
    }
}