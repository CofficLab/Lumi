import Foundation
import Testing

@testable import ClipboardManagerPlugin

/// 回归 #421：固定项被清理策略永久保留，但可能落在「最新 maxFetchLimit 条」
/// 时间窗之外；只取时间窗会让固定项从 UI 和搜索结果中消失。
@Suite("固定项不被取回时间窗挤出")
struct ClipboardPinnedWindowTests {
    @Test("早于 5000 条新记录的固定项仍在 getItems 结果中")
    func pinnedItemOutsideFetchWindowIsIncluded() async throws {
        let root = FileManager.default.temporaryDirectory
            .appendingPathComponent("clipm-pinned-window-\(UUID().uuidString)", isDirectory: true)
        try FileManager.default.createDirectory(at: root, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: root) }

        let manager = ClipboardHistoryManager(databaseDirectory: root)
        let storage = ClipboardStorage(historyManager: manager, historyLimitProvider: { 500 })

        let base = Date().addingTimeInterval(-5200)
        var records = [
            ClipboardHistoryItem(
                timestamp: base,
                type: ClipboardItemType.text.rawValue,
                content: "old pinned unique content",
                isPinned: true,
                searchKeywords: "old pinned unique content"
            )
        ]
        for index in 1...ClipboardHistoryManager.maxFetchLimit {
            records.append(
                ClipboardHistoryItem(
                    timestamp: base.addingTimeInterval(Double(index)),
                    type: ClipboardItemType.text.rawValue,
                    content: "filler \(index)",
                    searchKeywords: "filler \(index)"
                )
            )
        }
        #expect(await manager.addBatch(records))

        let items = await storage.getItems()
        #expect(items.count == ClipboardHistoryManager.maxFetchLimit + 1)
        #expect(items.contains { $0.isPinned && $0.content == "old pinned unique content" })
        // 合并结果统一按时间倒序，最旧的一条正是被并入的固定项。
        #expect(items.last?.isPinned == true)
    }

    @Test("窗口内已固定的项不会因两条查询重复")
    func pinnedItemInsideWindowIsNotDuplicated() async throws {
        let root = FileManager.default.temporaryDirectory
            .appendingPathComponent("clipm-pinned-dup-\(UUID().uuidString)", isDirectory: true)
        try FileManager.default.createDirectory(at: root, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: root) }

        let manager = ClipboardHistoryManager(databaseDirectory: root)
        let storage = ClipboardStorage(historyManager: manager, historyLimitProvider: { 500 })

        await storage.add(item: ClipboardItem(type: .text, content: "pinned inside"))
        await storage.add(item: ClipboardItem(type: .text, content: "newer"))
        let before = await storage.getItems()
        let pinnedID = try #require(before.first { $0.content == "pinned inside" }?.id)
        await storage.togglePin(id: pinnedID)

        let merged = await storage.getItems()
        #expect(merged.count == 2)
        #expect(merged.filter { $0.content == "pinned inside" }.count == 1)
        // 时间倒序：更新的未固定记录在前，固定不上浮，只保证可见。
        #expect(merged.first?.content == "newer")
    }

    @Test("mergingPinned 纯函数：按 id 去重、时间倒序、并入窗外固定项")
    func mergePureFunctionDeduplicatesAndOrders() {
        let base = Date(timeIntervalSince1970: 1_000_000)
        let newest = ClipboardHistoryItem(
            id: UUID(), timestamp: base + 30, type: "text", content: "a", searchKeywords: "a"
        )
        let middle = ClipboardHistoryItem(
            id: UUID(), timestamp: base + 20, type: "text", content: "b", searchKeywords: "b"
        )
        let outsidePinned = ClipboardHistoryItem(
            id: UUID(), timestamp: base + 1, type: "text", content: "p", isPinned: true, searchKeywords: "p"
        )
        let duplicateOfNewest = ClipboardHistoryItem(
            id: newest.id, timestamp: base + 30, type: "text", content: "a",
            isPinned: true, searchKeywords: "a"
        )

        let merged = ClipboardStorage.mergingPinned([newest, middle], pinned: [duplicateOfNewest, outsidePinned])
        #expect(merged.map(\.content) == ["a", "b", "p"])
    }
}
