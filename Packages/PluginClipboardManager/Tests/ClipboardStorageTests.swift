import AppKit
import Foundation
import KitTestIsolation
import KitTestSupport
import Testing

@testable import ClipboardManagerPlugin

// MARK: - Helpers

private func makeTemporaryDirectory(_ prefix: String) throws -> URL {
    let root = FileManager.default.temporaryDirectory
        .appendingPathComponent("\(prefix)-\(UUID().uuidString)", isDirectory: true)
    try FileManager.default.createDirectory(at: root, withIntermediateDirectories: true)
    return root
}

private func makeStorage() throws -> (ClipboardStorage, URL) {
    let root = try makeTemporaryDirectory("clipm-storage")
    let manager = ClipboardHistoryManager(databaseDirectory: root)
    return (ClipboardStorage(historyManager: manager), root)
}

// MARK: - Storage

@Suite("ClipboardStorage")
struct ClipboardStorageTests {

    @Test("add 后可通过 getItems / getLatest 读回")
    func storesItems() async throws {
        let (storage, root) = try makeStorage()
        defer { try? FileManager.default.removeItem(at: root) }

        await storage.add(item: ClipboardItem(type: .text, content: "stored"))
        await storage.add(item: ClipboardItem(type: .text, content: "second"))

        let items = await storage.getItems()
        #expect(items.count == 2)
        #expect(Set(items.map(\.content)) == ["stored", "second"])

        let latest = await storage.getLatest(limit: 1)
        #expect(latest.count == 1)
    }

    @Test("连续添加相同内容时移除旧的未固定项")
    func deduplicatesConsecutiveContent() async throws {
        let (storage, root) = try makeStorage()
        defer { try? FileManager.default.removeItem(at: root) }

        await storage.add(item: ClipboardItem(type: .text, content: "same"))
        await storage.add(item: ClipboardItem(type: .text, content: "same"))

        let items = await storage.getItems()
        #expect(items.count == 1)
        #expect(items.first?.content == "same")
    }

    @Test("内容相同但类型不同不去重")
    func keepsDifferentTypes() async throws {
        let (storage, root) = try makeStorage()
        defer { try? FileManager.default.removeItem(at: root) }

        await storage.add(item: ClipboardItem(type: .text, content: "same"))
        await storage.add(item: ClipboardItem(type: .html, content: "same"))

        let items = await storage.getItems()
        #expect(items.count == 2)
    }

    @Test("已有项被固定时，重复内容不去重")
    func keepsPinnedDuplicate() async throws {
        let (storage, root) = try makeStorage()
        defer { try? FileManager.default.removeItem(at: root) }

        await storage.add(item: ClipboardItem(type: .text, content: "pinned"))
        let stored = await storage.getItems()
        let id = try #require(stored.first?.id)
        await storage.togglePin(id: id)

        await storage.add(item: ClipboardItem(type: .text, content: "pinned"))

        let items = await storage.getItems()
        #expect(items.count == 2)
        #expect(await storage.getPinned().count == 1)
    }

    @Test("togglePin 翻转固定状态，未知 id 为空操作")
    func togglesPin() async throws {
        let (storage, root) = try makeStorage()
        defer { try? FileManager.default.removeItem(at: root) }

        await storage.add(item: ClipboardItem(type: .text, content: "pin me"))
        let id = try #require(await storage.getItems().first?.id)

        await storage.togglePin(id: id)
        #expect(await storage.getPinned().map(\.id) == [id])

        await storage.togglePin(id: id)
        #expect(await storage.getPinned().isEmpty)

        // 未知 id 不应崩溃，也不改变状态。
        await storage.togglePin(id: UUID())
        #expect(await storage.getItems().count == 1)
    }

    @Test("clear 默认保留固定项")
    func clearsKeepingPinnedByDefault() async throws {
        let (storage, root) = try makeStorage()
        defer { try? FileManager.default.removeItem(at: root) }

        await storage.add(item: ClipboardItem(type: .text, content: "pinned"))
        await storage.add(item: ClipboardItem(type: .text, content: "loose"))
        let id = try #require(await storage.getItems().first(where: { $0.content == "pinned" })?.id)
        await storage.togglePin(id: id)

        await storage.clear()

        let remaining = await storage.getItems()
        #expect(remaining.map(\.content) == ["pinned"])
    }

    @Test("clear(keepPinned: false) 清空全部")
    func clearsEverything() async throws {
        let (storage, root) = try makeStorage()
        defer { try? FileManager.default.removeItem(at: root) }

        await storage.add(item: ClipboardItem(type: .text, content: "a"))
        await storage.add(item: ClipboardItem(type: .text, content: "b"))

        await storage.clear(keepPinned: false)
        #expect(await storage.getItems().isEmpty)
    }

    @Test("delete(id:) 与 delete(ids:) 删除对应项")
    func deletesItems() async throws {
        let (storage, root) = try makeStorage()
        defer { try? FileManager.default.removeItem(at: root) }

        await storage.add(item: ClipboardItem(type: .text, content: "one"))
        await storage.add(item: ClipboardItem(type: .text, content: "two"))
        await storage.add(item: ClipboardItem(type: .text, content: "three"))

        let items = await storage.getItems()
        let oneID = try #require(items.first(where: { $0.content == "one" })?.id)
        let twoID = try #require(items.first(where: { $0.content == "two" })?.id)

        await storage.delete(id: oneID)
        #expect(await storage.getItems().count == 2)

        await storage.delete(ids: [twoID])
        #expect(await storage.getItems().map(\.content) == ["three"])
    }

    @Test("search 与 query 走历史管理器过滤")
    func searchesAndQueries() async throws {
        let (storage, root) = try makeStorage()
        defer { try? FileManager.default.removeItem(at: root) }

        await storage.add(item: ClipboardItem(type: .text, content: "needle here"))
        await storage.add(item: ClipboardItem(type: .text, content: "other"))

        let hits = await storage.search(keyword: "needle")
        #expect(hits.count == 1)

        let range = await storage.query(
            from: Date().addingTimeInterval(-3600),
            to: Date().addingTimeInterval(3600)
        )
        #expect(range.count == 2)
    }

    @Test("migrateFromJSON 覆盖历史数据")
    func migratesFromJSON() async throws {
        let (storage, root) = try makeStorage()
        defer { try? FileManager.default.removeItem(at: root) }

        await storage.add(item: ClipboardItem(type: .text, content: "old"))
        await storage.migrateFromJSON(items: [ClipboardItem(type: .text, content: "migrated")])

        let items = await storage.getItems()
        #expect(items.count == 1)
        #expect(items.first?.content == "migrated")
    }
}

// MARK: - View model

@MainActor
@Suite("ClipboardManagerViewModel")
struct ClipboardManagerViewModelTests {

    @Test("loadItems 拉取存储层数据")
    func loadsItems() async throws {
        let (storage, root) = try makeStorage()
        defer { try? FileManager.default.removeItem(at: root) }

        await storage.add(item: ClipboardItem(type: .text, content: "alpha"))
        await storage.add(item: ClipboardItem(type: .text, content: "beta"))

        let viewModel = ClipboardManagerViewModel(storage: storage)
        await viewModel.loadItems()

        #expect(viewModel.items.count == 2)
    }

    @Test("filterItems 按搜索词过滤，空搜索词返回全部")
    func filtersItems() async throws {
        let (storage, root) = try makeStorage()
        defer { try? FileManager.default.removeItem(at: root) }

        await storage.add(item: ClipboardItem(type: .text, content: "alpha needle"))
        await storage.add(item: ClipboardItem(type: .text, content: "beta haystack"))

        let viewModel = ClipboardManagerViewModel(storage: storage)
        await viewModel.loadItems()
        #expect(viewModel.items.count == 2)

        viewModel.searchText = "NEEDLE"
        viewModel.filterItems()
        #expect(viewModel.items.map(\.content) == ["alpha needle"])

        viewModel.searchText = ""
        viewModel.filterItems()
        #expect(viewModel.items.count == 2)
    }

    @Test("delete / togglePin / clearAll 变更后刷新列表")
    func mutatesAndRefreshes() async throws {
        let (storage, root) = try makeStorage()
        defer { try? FileManager.default.removeItem(at: root) }

        await storage.add(item: ClipboardItem(type: .text, content: "one"))
        await storage.add(item: ClipboardItem(type: .text, content: "two"))

        let viewModel = ClipboardManagerViewModel(storage: storage)
        await viewModel.loadItems()
        #expect(viewModel.items.count == 2)

        let target = try #require(viewModel.items.first(where: { $0.content == "one" }))
        viewModel.delete(id: target.id)
        try await Task.sleep(for: .milliseconds(200))
        await viewModel.loadItems()
        #expect(viewModel.items.map(\.content) == ["two"])

        let remaining = try #require(viewModel.items.first)
        viewModel.togglePin(id: remaining.id)
        try await Task.sleep(for: .milliseconds(200))
        await viewModel.loadItems()
        #expect(await storage.getPinned().count == 1)

        viewModel.clearAll()
        try await Task.sleep(for: .milliseconds(200))
        await viewModel.loadItems()
        // `clearAll` 走 `storage.clear()`，默认保留固定项。
        #expect(viewModel.items.map(\.content) == ["two"])
    }

    @Test("write 按类型写入不同剪贴板表示")
    func writesToPasteboard() throws {
        let pasteboard = NSPasteboard.withUniqueName()

        let text = ClipboardHistoryItem(type: ClipboardItemType.text.rawValue, content: "plain", searchKeywords: "plain")
        #expect(ClipboardManagerViewModel.write(text, to: pasteboard))
        #expect(pasteboard.string(forType: .string) == "plain")

        let color = ClipboardHistoryItem(type: ClipboardItemType.color.rawValue, content: "#FF0000", searchKeywords: "x")
        #expect(ClipboardManagerViewModel.write(color, to: pasteboard))
        #expect(pasteboard.string(forType: .string) == "#FF0000")

        // 未知类型回退为纯文本。
        let unknown = ClipboardHistoryItem(type: "mystery", content: "fallback", searchKeywords: "x")
        #expect(ClipboardManagerViewModel.write(unknown, to: pasteboard))
        #expect(pasteboard.string(forType: .string) == "fallback")

        // 图片路径不存在时写入失败。
        let missingImage = ClipboardHistoryItem(
            type: ClipboardItemType.image.rawValue,
            content: "/definitely/missing/image.png",
            searchKeywords: "x"
        )
        #expect(ClipboardManagerViewModel.write(missingImage, to: pasteboard) == false)
    }
}

// MARK: - Observers

@MainActor
@Suite("Clipboard history change center")
struct ClipboardHistoryObserverTests {

    @Test("注册观察者后 notify 会回调，取消后不再回调")
    func notifiesAndCancels() {
        let center = ClipboardHistoryChangeCenter()
        var count = 0
        let token = center.addObserver { count += 1 }

        center.notify()
        #expect(count == 1)

        center.notify()
        #expect(count == 2)

        token.cancel()
        center.notify()
        #expect(count == 2)
    }

    @Test("多个观察者各自收到通知")
    func notifiesAllObservers() {
        let center = ClipboardHistoryChangeCenter()
        var first = 0
        var second = 0
        let firstToken = center.addObserver { first += 1 }
        let secondToken = center.addObserver { second += 1 }

        center.notify()
        #expect(first == 1)
        #expect(second == 1)

        firstToken.cancel()
        center.notify()
        #expect(first == 1)
        #expect(second == 2)

        secondToken.cancel()
    }

    @Test("ClipboardHistoryObserver 把变化转发给回调")
    func observerForwardsChanges() {
        // `ClipboardHistoryObserver` 注册在共享的 `ClipboardHistoryChangeCenter` 上。
        // 该单例的观察者注册表会跨用例残留：进入前先清空，避免收到别的用例
        // 留下的通知导致计数漂移。
        let center = ClipboardHistoryChangeCenter.shared
        center.removeAllObservers()
        defer { center.removeAllObservers() }

        var changes = 0
        let observer = ClipboardHistoryObserver(onChange: { changes += 1 })

        center.notify()
        #expect(changes == 1)

        observer.cancel()
        center.notify()
        #expect(changes == 1)
    }
}

// MARK: - Runtime

/// 运行时目录守卫的测试。
///
/// `ClipboardManagerRuntime.databaseDirectory()` 在测试进程里未注入即拒绝
/// （`fatalError`，直接终止整个测试进程），因此这里既不能依赖生产回退目录，
/// 也不能让注入状态在用例之间互相污染。
///
/// 所有涉及注入状态的用例都标注 `@MainActor` 且不挂起：MainActor 是串行执行器，
/// 这些用例因此不会并发读写同一份进程级注入状态。
@Suite("ClipboardManagerRuntime", .serialized)
@MainActor
struct ClipboardManagerRuntimeTests {

    @Test("注入目录后 databaseDirectory 返回该目录")
    func usesInjectedDatabaseDirectory() throws {
        let directory = try TemporaryDirectory.make("clipboard-runtime-injected")
        defer { directory.remove() }
        ClipboardManagerRuntime.injectedDatabaseDirectory = directory.url
        defer { ClipboardManagerRuntime.injectedDatabaseDirectory = nil }

        #expect(ClipboardManagerRuntime.databaseDirectory() == directory.url)
    }

    @Test("未注入目录时守卫拒绝回退到真实数据目录")
    func refusesFallbackWithoutInjection() {
        ClipboardManagerRuntime.injectedDatabaseDirectory = nil
        defer { ClipboardManagerRuntime.injectedDatabaseDirectory = nil }

        #expect(ClipboardManagerRuntime.injectedDatabaseDirectory == nil)

        // 未注入目录时不得回退到本机真实数据目录：测试进程里这条路径必须被拒绝。
        switch IsolatedDirectoryGuard.resolve(
            injected: ClipboardManagerRuntime.injectedDatabaseDirectory,
            owner: "ClipboardManagerRuntime",
            accessor: "databaseDirectory()",
            fallback: { URL(fileURLWithPath: "/tmp/clipboard-fallback", isDirectory: true) }
        ) {
        case .resolved:
            Issue.record("测试进程下未注入目录时不应回退到真实数据目录")
        case let .refused(reason):
            #expect(reason.contains("ClipboardManagerRuntime"))
            #expect(reason.contains("databaseDirectory()"))
        }
    }
}
