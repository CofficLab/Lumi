import Combine
import Foundation
import Testing
@testable import ClipboardManagerPlugin

/// 构造使用临时目录的存储，避免测试读写开发者本机的真实数据。
private func makeStorage() throws -> (ClipboardStorage, URL) {
    let root = FileManager.default.temporaryDirectory
        .appendingPathComponent("ClipRefreshTests-\(UUID().uuidString)", isDirectory: true)
    try FileManager.default.createDirectory(at: root, withIntermediateDirectories: true)
    let manager = ClipboardHistoryManager(databaseDirectory: root)
    return (ClipboardStorage(historyManager: manager, historyLimitProvider: { 500 }), root)
}

/// 剪贴板变化刷新的可见性门控与突发合并（见 issue #1305）。
///
/// 变化观察者在 onBoot 无条件注册，面板却只在活动栏条目激活时才安装。
/// 原先每次系统级复制都全量重拉最多 5000 条并在主 actor 过滤 + 重发布，
/// 隐藏面板也不例外；多文件复制还按条目逐个广播，触发 N 次重叠全量刷新。
@MainActor
@Suite("剪贴板刷新门控")
struct ClipboardRefreshTests {

    @Test("隐藏面板时变化刷新被挡掉，重新可见后补上（#1305）")
    func hiddenPanelIgnoresRefreshUntilVisible() async throws {
        let (storage, root) = try makeStorage()
        defer { try? FileManager.default.removeItem(at: root) }

        let viewModel = ClipboardManagerViewModel(storage: storage)
        await viewModel.loadItems()
        #expect(viewModel.items.isEmpty)

        // 隐藏期间新增条目并多次触发刷新：不应发生任何重拉。
        for index in 0..<3 {
            await storage.add(item: ClipboardItem(type: .text, content: "item \(index)"))
        }
        for _ in 0..<5 {
            viewModel.refresh()
        }
        try await Task.sleep(for: .milliseconds(300))
        #expect(viewModel.items.isEmpty)

        // 重新可见：合并刷新一次，补上隐藏期间错过的变化。
        viewModel.setPanelVisible(true)
        try await Task.sleep(for: .milliseconds(300))
        #expect(viewModel.items.count == 3)
    }

    @Test("可见面板的突发刷新被合并成一次重发布（#1305）")
    func visibleRefreshCoalescesBurst() async throws {
        let (storage, root) = try makeStorage()
        defer { try? FileManager.default.removeItem(at: root) }

        await storage.add(item: ClipboardItem(type: .text, content: "alpha"))
        await storage.add(item: ClipboardItem(type: .text, content: "beta"))

        let viewModel = ClipboardManagerViewModel(storage: storage)
        await viewModel.loadItems()
        // 等待 init 内部的首次加载落定，避免它计入下面的发布计数。
        try await Task.sleep(for: .milliseconds(50))

        viewModel.setPanelVisible(true)
        var publishCount = 0
        let cancellable = viewModel.objectWillChange.sink { publishCount += 1 }
        // 模拟多文件复制的逐个通知：6 次触发应合并成一次 loadItems。
        for _ in 0..<6 {
            viewModel.refresh()
        }
        try await Task.sleep(for: .milliseconds(400))
        cancellable.cancel()

        #expect(publishCount == 1)
        #expect(viewModel.items.count == 2)
    }

    @Test("隐藏面板会取消待执行的刷新（#1305）")
    func hidingCancelsPendingRefresh() async throws {
        let (storage, root) = try makeStorage()
        defer { try? FileManager.default.removeItem(at: root) }

        let viewModel = ClipboardManagerViewModel(storage: storage)
        await viewModel.loadItems()
        viewModel.setPanelVisible(true)

        await storage.add(item: ClipboardItem(type: .text, content: "pending"))
        viewModel.refresh()
        // 在防抖窗口结束前隐藏：待执行的刷新必须被取消，不再重拉。
        viewModel.setPanelVisible(false)
        try await Task.sleep(for: .milliseconds(300))
        #expect(viewModel.items.isEmpty)
    }
}