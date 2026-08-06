import AppKit
import Foundation
import Testing
import LumiKernel
@testable import MessageListAppKitPlugin

/// Test renderer with a distinct reuse identifier.
@MainActor
private final class StubRenderer: AppKitMessageRenderer {
    let reuseIdentifier: NSUserInterfaceItemIdentifier
    private(set) var configureCount = 0

    init(reuseIdentifier: NSUserInterfaceItemIdentifier) {
        self.reuseIdentifier = reuseIdentifier
    }

    func makeView() -> NSView {
        let view = NSView()
        view.identifier = reuseIdentifier
        return view
    }

    func configure(view: NSView, row: AppKitMessageRow) {
        configureCount += 1
    }

    func prepareForReuse(view: NSView) {}

    func measure(row: AppKitMessageRow, width: CGFloat) -> CGFloat { 40 }
}

/// Serialized: creates real windows/table views whose layout work would
/// starve MainActor tasks of other suites when run in parallel.
@Suite(.serialized)
@MainActor
struct AppKitCellReuseTests {
    private func message(_ i: Int) -> LumiChatMessage {
        LumiChatMessage(
            id: UUID(uuidString: String(format: "%08X-0000-0000-0000-000000000000", i)) ?? UUID(),
            conversationID: UUID(),
            role: .assistant,
            content: "message \(i)",
            createdAt: Date(timeIntervalSinceReferenceDate: Double(i))
        )
    }

    private func row(_ i: Int) -> AppKitMessageRow {
        AppKitMessageRow(kind: .assistant, message: message(i))
    }

    // MARK: - Diffing

    @Test("diff：尾部追加只插入新增行")
    func diffAppend() {
        let old = (0..<5).map { "id\($0)" }
        let new = (0..<8).map { "id\($0)" }
        let diff = AppKitMessageListDataSource.diff(old: old, new: new)
        #expect(diff.removals.isEmpty)
        #expect(diff.insertions == IndexSet(integersIn: 5..<8))
    }

    @Test("diff：头部前置只插入新行")
    func diffPrepend() {
        let old = (2..<7).map { "id\($0)" }
        let new = (0..<7).map { "id\($0)" }
        let diff = AppKitMessageListDataSource.diff(old: old, new: new)
        #expect(diff.removals.isEmpty)
        #expect(diff.insertions == IndexSet(integersIn: 0..<2))
    }

    @Test("diff：中间替换为移除+插入")
    func diffMiddle() {
        let old = ["a", "b", "c", "d"]
        let new = ["a", "x", "y", "d"]
        let diff = AppKitMessageListDataSource.diff(old: old, new: new)
        #expect(diff.removals == IndexSet(integersIn: 1..<3))
        #expect(diff.insertions == IndexSet(integersIn: 1..<3))
    }

    @Test("diff：完全相同无操作")
    func diffIdentical() {
        let ids = (0..<5).map { "id\($0)" }
        let diff = AppKitMessageListDataSource.diff(old: ids, new: ids)
        #expect(diff.removals.isEmpty)
        #expect(diff.insertions.isEmpty)
    }

    // MARK: - Cell reuse

    @Test("换不兼容 renderer 时根视图被整体替换，无残留子视图")
    func incompatibleRendererSwapsRootView() {
        let cell = AppKitMessageCellView()
        let rendererA = StubRenderer(reuseIdentifier: NSUserInterfaceItemIdentifier("A"))
        let rendererB = StubRenderer(reuseIdentifier: NSUserInterfaceItemIdentifier("B"))

        cell.configure(row: row(0), renderer: rendererA)
        #expect(cell.subviews.count == 1)
        #expect(cell.subviews.first?.identifier == NSUserInterfaceItemIdentifier("A"))

        cell.configure(row: row(1), renderer: rendererB)
        // 旧的 A 根视图被移除，仅剩 B 根视图。
        #expect(cell.subviews.count == 1)
        #expect(cell.subviews.first?.identifier == NSUserInterfaceItemIdentifier("B"))
    }

    @Test("同 renderer 复用根视图且重新配置")
    func sameRendererReusesRootView() {
        let cell = AppKitMessageCellView()
        let renderer = StubRenderer(reuseIdentifier: NSUserInterfaceItemIdentifier("same"))

        cell.configure(row: row(0), renderer: renderer)
        let root = cell.subviews.first
        cell.prepareForReuse()
        cell.configure(row: row(1), renderer: renderer)

        #expect(cell.subviews.first === root) // 根视图复用
        #expect(renderer.configureCount == 2)
    }

    @Test("prepareForReuse 清空 transient 状态（fallback 文本）")
    func prepareForReuseClearsContent() {
        let cell = AppKitMessageCellView()
        let renderer = AppKitFallbackRenderer()
        cell.configure(row: row(7), renderer: renderer)

        let body = cell.subviews.first?.subviews.dropFirst().first as? NSTextField
        #expect(body?.stringValue == "message 7")

        cell.prepareForReuse()
        #expect(body?.stringValue == "")
        #expect(cell.row == nil)
    }

    // MARK: - Bounded cell instantiation

    @Test("1000 行数据：实例化 cell 数接近可见行数")
    func boundedCellInstantiation() throws {
        let rows = (0..<1000).map { row($0) }
        let snapshot = AppKitMessageListSnapshot(
            conversationID: UUID(),
            rows: rows
        )

        let tableView = NSTableView()
        tableView.addTableColumn(NSTableColumn(identifier: NSUserInterfaceItemIdentifier("c")))
        let dataSource = AppKitMessageListDataSource()
        dataSource.attach(tableView: tableView)
        dataSource.apply(snapshot: snapshot)

        let window = NSWindow(
            contentRect: NSRect(x: 0, y: 0, width: 800, height: 600),
            styleMask: [.borderless],
            backing: .buffered,
            defer: false
        )
        window.contentView = tableView
        window.contentView?.layoutSubtreeIfNeeded()
        tableView.layoutSubtreeIfNeeded()

        let visibleRows = tableView.rows(in: tableView.visibleRect)
        #expect(visibleRows.length > 0)
        #expect(visibleRows.length < 30)

        // 非可见行不应被实例化（没有滚动时只有可见区的 cell 存在）。
        let instantiatedCells = tableView.subviews.count
        #expect(instantiatedCells <= visibleRows.length + 4)
    }
}
