import Foundation
import SwiftData
import Testing

@testable import ClipboardManagerPlugin

// MARK: - Helpers

private func makeTemporaryDirectory(_ prefix: String) throws -> URL {
    let root = FileManager.default.temporaryDirectory
        .appendingPathComponent("\(prefix)-\(UUID().uuidString)", isDirectory: true)
    try FileManager.default.createDirectory(at: root, withIntermediateDirectories: true)
    return root
}

private func makeHistoryItem(
    content: String,
    timestamp: Date = Date(),
    isPinned: Bool = false,
    appName: String? = nil
) -> ClipboardHistoryItem {
    ClipboardHistoryItem(
        timestamp: timestamp,
        type: ClipboardItemType.text.rawValue,
        content: content,
        isPinned: isPinned,
        appName: appName,
        searchKeywords: content
    )
}

// MARK: - History manager

@Suite("ClipboardHistoryManager")
struct ClipboardHistoryManagerTests {

    @Test("add(ClipboardItem) 走 ClipboardItem → ClipboardHistoryItem 转换并落库")
    func addsClipboardItem() async throws {
        let root = try makeTemporaryDirectory("clipm-add-item")
        defer { try? FileManager.default.removeItem(at: root) }

        let manager = ClipboardHistoryManager(databaseDirectory: root)
        let item = ClipboardItem(type: .text, content: "hello world", appName: "Notes")

        #expect(await manager.add(item))

        let stored = await manager.getAll()
        #expect(stored.count == 1)
        #expect(stored.first?.content == "hello world")
        #expect(stored.first?.appName == "Notes")
        #expect(stored.first?.id == item.id)
    }

    @Test("addBatch 批量写入后可全部读回")
    func addsBatch() async throws {
        let root = try makeTemporaryDirectory("clipm-batch")
        defer { try? FileManager.default.removeItem(at: root) }

        let manager = ClipboardHistoryManager(databaseDirectory: root)
        let items = (0..<3).map { makeHistoryItem(content: "batch \($0)") }

        #expect(await manager.addBatch(items))

        let stored = await manager.getAll()
        #expect(stored.count == 3)
        #expect(Set(stored.map(\.content)) == ["batch 0", "batch 1", "batch 2"])
    }

    @Test("getAll 按时间倒序返回")
    func getAllSortsDescending() async throws {
        let root = try makeTemporaryDirectory("clipm-order")
        defer { try? FileManager.default.removeItem(at: root) }

        let manager = ClipboardHistoryManager(databaseDirectory: root)
        let base = Date(timeIntervalSince1970: 1_700_000_000)
        #expect(await manager.addBatch([
            makeHistoryItem(content: "oldest", timestamp: base),
            makeHistoryItem(content: "newest", timestamp: base.addingTimeInterval(100)),
            makeHistoryItem(content: "middle", timestamp: base.addingTimeInterval(50)),
        ]))

        let stored = await manager.getAll()
        #expect(stored.map(\.content) == ["newest", "middle", "oldest"])
    }

    @Test("query 按时间区间过滤")
    func queriesByTimeRange() async throws {
        let root = try makeTemporaryDirectory("clipm-query")
        defer { try? FileManager.default.removeItem(at: root) }

        let manager = ClipboardHistoryManager(databaseDirectory: root)
        let base = Date(timeIntervalSince1970: 1_700_000_000)
        #expect(await manager.addBatch([
            makeHistoryItem(content: "before", timestamp: base),
            makeHistoryItem(content: "inside", timestamp: base.addingTimeInterval(50)),
            makeHistoryItem(content: "after", timestamp: base.addingTimeInterval(100)),
        ]))

        let matched = await manager.query(
            from: base.addingTimeInterval(10),
            to: base.addingTimeInterval(60)
        )
        #expect(matched.map(\.content) == ["inside"])

        let wide = await manager.query(from: base, to: base.addingTimeInterval(200))
        #expect(wide.count == 3)
    }

    @Test("search 命中关键词、不命中返回空")
    func searchesByKeyword() async throws {
        let root = try makeTemporaryDirectory("clipm-search")
        defer { try? FileManager.default.removeItem(at: root) }

        let manager = ClipboardHistoryManager(databaseDirectory: root)
        #expect(await manager.addBatch([
            makeHistoryItem(content: "alpha needle"),
            makeHistoryItem(content: "beta haystack"),
        ]))

        let hits = await manager.search(keyword: "NEEDLE")
        #expect(hits.map(\.content) == ["alpha needle"])

        let misses = await manager.search(keyword: "nothing-here")
        #expect(misses.isEmpty)
    }

    @Test("delete(ids:) 批量删除命中项，其余保留")
    func deletesBatch() async throws {
        let root = try makeTemporaryDirectory("clipm-delete-ids")
        defer { try? FileManager.default.removeItem(at: root) }

        let manager = ClipboardHistoryManager(databaseDirectory: root)
        #expect(await manager.addBatch([
            makeHistoryItem(content: "keep"),
            makeHistoryItem(content: "drop-1"),
            makeHistoryItem(content: "drop-2"),
        ]))

        let all = await manager.getAll()
        let dropIDs = Set(all.filter { $0.content.hasPrefix("drop") }.map(\.id))
        #expect(dropIDs.count == 2)

        #expect(await manager.delete(ids: Array(dropIDs)))

        let remaining = await manager.getAll()
        #expect(remaining.map(\.content) == ["keep"])
    }

    @Test("updatePinStatus 对不存在的 id 返回 false")
    func pinUpdateForUnknownIDFails() async throws {
        let root = try makeTemporaryDirectory("clipm-pin-unknown")
        defer { try? FileManager.default.removeItem(at: root) }

        let manager = ClipboardHistoryManager(databaseDirectory: root)
        #expect(await manager.updatePinStatus(id: UUID(), isPinned: true) == false)
    }

    @Test("delete(id:) 对不存在的 id 返回 false")
    func deleteForUnknownIDFails() async throws {
        let root = try makeTemporaryDirectory("clipm-delete-unknown")
        defer { try? FileManager.default.removeItem(at: root) }

        let manager = ClipboardHistoryManager(databaseDirectory: root)
        #expect(await manager.delete(id: UUID()) == false)
    }

    @Test("clearAll(keepPinned: true) 保留固定项")
    func clearAllKeepsPinned() async throws {
        let root = try makeTemporaryDirectory("clipm-clear-pinned")
        defer { try? FileManager.default.removeItem(at: root) }

        let manager = ClipboardHistoryManager(databaseDirectory: root)
        #expect(await manager.addBatch([
            makeHistoryItem(content: "pinned", isPinned: true),
            makeHistoryItem(content: "loose-1"),
            makeHistoryItem(content: "loose-2"),
        ]))

        #expect(await manager.clearAll(keepPinned: true))

        let remaining = await manager.getAll()
        #expect(remaining.map(\.content) == ["pinned"])
        #expect(await manager.getPinned().count == 1)
    }

    @Test("clearAll(keepPinned: false) 清空全部")
    func clearAllRemovesEverything() async throws {
        let root = try makeTemporaryDirectory("clipm-clear-all")
        defer { try? FileManager.default.removeItem(at: root) }

        let manager = ClipboardHistoryManager(databaseDirectory: root)
        #expect(await manager.addBatch([
            makeHistoryItem(content: "pinned", isPinned: true),
            makeHistoryItem(content: "loose"),
        ]))

        #expect(await manager.clearAll(keepPinned: false))
        #expect(await manager.getAll().isEmpty)
    }

    @Test("cleanup 删除超期且未固定的记录，保留超期固定项与新记录")
    func cleanupRemovesExpiredUnpinned() async throws {
        let root = try makeTemporaryDirectory("clipm-cleanup")
        defer { try? FileManager.default.removeItem(at: root) }

        let manager = ClipboardHistoryManager(databaseDirectory: root)
        let old = Date().addingTimeInterval(-40 * 24 * 60 * 60)
        #expect(await manager.addBatch([
            makeHistoryItem(content: "expired", timestamp: old),
            makeHistoryItem(content: "expired-pinned", timestamp: old, isPinned: true),
            makeHistoryItem(content: "fresh"),
        ]))

        await manager.cleanup()

        let remaining = await manager.getAll()
        #expect(Set(remaining.map(\.content)) == ["expired-pinned", "fresh"])
    }

    @Test("migrateFromJSON 先清空旧数据再导入新数据")
    func migratesFromJSON() async throws {
        let root = try makeTemporaryDirectory("clipm-migrate")
        defer { try? FileManager.default.removeItem(at: root) }

        let manager = ClipboardHistoryManager(databaseDirectory: root)
        #expect(await manager.addBatch([makeHistoryItem(content: "old entry")]))

        let incoming = [
            ClipboardItem(type: .text, content: "migrated one"),
            ClipboardItem(type: .text, content: "migrated two"),
        ]
        #expect(await manager.migrateFromJSON(items: incoming))

        let stored = await manager.getAll()
        #expect(stored.count == 2)
        #expect(Set(stored.map(\.content)) == ["migrated one", "migrated two"])
    }

    @Test("数据库目录被文件占用时隔离该文件并重建目录")
    func quarantinesFileBlockingDatabaseDirectory() throws {
        let root = try makeTemporaryDirectory("clipm-blocked-dir")
        defer { try? FileManager.default.removeItem(at: root) }

        let blocked = root.appendingPathComponent("blocked", isDirectory: false)
        try "not a directory".write(to: blocked, atomically: true, encoding: .utf8)

        let container = ClipboardHistoryManager.makeContainer(databaseDirectory: blocked)
        let context = ModelContext(container)
        context.insert(makeHistoryItem(content: "after quarantine"))
        try context.save()

        let fetched = try context.fetch(FetchDescriptor<ClipboardHistoryItem>())
        #expect(fetched.count == 1)
        #expect(fetched.first?.content == "after quarantine")
        // 旧文件被隔离为 .corrupt-<时间戳>。
        let quarantined = try FileManager.default.contentsOfDirectory(atPath: root.path)
        #expect(quarantined.contains { $0.hasPrefix("blocked.corrupt-") })
    }
}

// MARK: - Models

@Suite("Clipboard models")
struct ClipboardModelTests {

    @Test("ClipboardItem.title 按类型派生")
    func clipboardItemTitle() {
        #expect(ClipboardItem(type: .text, content: "  hello  ").title == "hello")
        #expect(ClipboardItem(type: .html, content: " <p>x</p> ").title == "<p>x</p>")
        #expect(ClipboardItem(type: .file, content: "/tmp/dir/report.pdf").title == "report.pdf")
        #expect(ClipboardItem(type: .image, content: "/tmp/dir/shot.png").title == "Image")
        #expect(ClipboardItem(type: .color, content: "#FF0000").title == "#FF0000")
    }

    @Test("ClipboardItem 初始化时把搜索关键词转小写")
    func clipboardItemLowercasesKeywords() {
        let item = ClipboardItem(type: .text, content: "MiXeD Case")
        #expect(item.searchKeywords == "mixed case")
        #expect(item.isPinned == false)
        #expect(item.appName == nil)
    }

    @Test("ClipboardHistoryItem 初始化时把搜索关键词转小写")
    func historyItemLowercasesKeywords() {
        let item = makeHistoryItem(content: "MiXeD Case")
        #expect(item.searchKeywords == "mixed case")
    }

    @Test("ClipboardHistoryItem → ClipboardItem 往返保留核心字段")
    func historyItemRoundTrips() throws {
        let source = ClipboardItem(type: .text, content: "round trip", appName: "Editor")
        let history = ClipboardHistoryItem(from: source)
        #expect(history.id == source.id)
        #expect(history.content == source.content)
        #expect(history.appName == "Editor")
        #expect(history.type == ClipboardItemType.text.rawValue)

        let restored = history.toClipboardItem()
        #expect(restored.type == .text)
        #expect(restored.content == "round trip")
        #expect(restored.appName == "Editor")
        #expect(restored.isPinned == false)
    }

    @Test("未知类型字符串回退为 text")
    func unknownTypeFallsBackToText() {
        let item = ClipboardHistoryItem(
            type: "not-a-known-type",
            content: "x",
            searchKeywords: "x"
        )
        #expect(item.toClipboardItem().type == .text)
    }
}
