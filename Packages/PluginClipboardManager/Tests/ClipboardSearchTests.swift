import Foundation
import Testing
@testable import ClipboardManagerPlugin

/// 构造使用临时目录的存储，避免测试读写开发者本机的真实数据。
private func makeStorage() throws -> (ClipboardStorage, URL) {
    let root = FileManager.default.temporaryDirectory
        .appendingPathComponent("ClipSearchTests-\(UUID().uuidString)", isDirectory: true)
    try FileManager.default.createDirectory(at: root, withIntermediateDirectories: true)
    let manager = ClipboardHistoryManager(databaseDirectory: root)
    // 固定上限，避免测试读取真实设置文件而依赖开发者本机状态。
    return (ClipboardStorage(historyManager: manager, historyLimitProvider: { 500 }), root)
}

/// 剪贴板搜索的防抖与后台扫描（见 issue #1192）。
///
/// 搜索要扫描最多 5000 条全文记录。原先每次按键都在主线程同步扫描一遍，
/// 逐字输入时是持续的主线程占用。
@MainActor
@Suite("剪贴板搜索")
struct ClipboardSearchTests {

    private func makeItem(content: String) -> ClipboardHistoryItem {
        ClipboardHistoryItem(
            type: ClipboardItemType.text.rawValue,
            content: content,
            searchKeywords: ClipboardItem.searchKeywords(from: content)
        )
    }

    @Test("过滤按关键词匹配搜索关键词")
    func filterMatchesSearchKeywords() {
        let needle = makeItem(content: "alpha needle")
        let haystack = makeItem(content: "beta haystack")
        let items = [needle, haystack]

        let matched = ClipboardManagerViewModel.filter(items, keyword: "NEEDLE")
        #expect(matched.map(\.content) == ["alpha needle"])
    }

    @Test("空关键词返回全部条目")
    func emptyKeywordReturnsAll() {
        let items = [makeItem(content: "a"), makeItem(content: "b")]

        #expect(ClipboardManagerViewModel.filter(items, keyword: "").count == 2)
    }

    @Test("搜索关键词有长度上界")
    func searchKeywordsAreBounded() {
        let long = String(repeating: "x", count: 10000)
        let keywords = ClipboardItem.searchKeywords(from: long)

        #expect(keywords.count == ClipboardItem.searchKeywordLimit)
    }

    @Test("短内容不被截断")
    func shortContentIsNotTruncated() {
        let keywords = ClipboardItem.searchKeywords(from: "hello")

        #expect(keywords == "hello")
    }

    @Test("搜索关键词统一小写")
    func searchKeywordsAreLowercased() {
        #expect(ClipboardItem.searchKeywords(from: "MiXeD Case") == "mixed case")
    }

    @Test("防抖搜索最终给出正确结果")
    func debouncedSearchProducesCorrectResults() async throws {
        let (storage, root) = try makeStorage()
        defer { try? FileManager.default.removeItem(at: root) }

        await storage.add(item: ClipboardItem(type: .text, content: "alpha needle"))
        await storage.add(item: ClipboardItem(type: .text, content: "beta haystack"))

        let viewModel = ClipboardManagerViewModel(storage: storage)
        await viewModel.loadItems()
        #expect(viewModel.items.count == 2)

        viewModel.searchText = "needle"
        viewModel.scheduleFilter()

        // 防抖窗口结束后结果才落地。
        try await Task.sleep(for: .milliseconds(400))

        #expect(viewModel.items.map(\.content) == ["alpha needle"])
    }

    @Test("清空搜索词立即恢复全部条目")
    func clearingSearchRestoresAllItems() async throws {
        let (storage, root) = try makeStorage()
        defer { try? FileManager.default.removeItem(at: root) }

        await storage.add(item: ClipboardItem(type: .text, content: "alpha"))
        await storage.add(item: ClipboardItem(type: .text, content: "beta"))

        let viewModel = ClipboardManagerViewModel(storage: storage)
        await viewModel.loadItems()

        viewModel.searchText = "alpha"
        viewModel.scheduleFilter()
        try await Task.sleep(for: .milliseconds(400))
        #expect(viewModel.items.count == 1)

        viewModel.searchText = ""
        viewModel.scheduleFilter()
        #expect(viewModel.items.count == 2)
    }
}
