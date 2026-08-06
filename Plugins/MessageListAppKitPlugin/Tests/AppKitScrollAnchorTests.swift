import AppKit
import Foundation
import Testing
import LumiKernel
@testable import MessageListAppKitPlugin

@Suite(.serialized)
@MainActor
struct AppKitScrollAnchorTests {
    @MainActor
    private final class Environment {
        let scrollView = NSScrollView()
        let tableView = NSTableView()
        let dataSource = AppKitMessageListDataSource()
        let window: NSWindow
        let anchor: AppKitScrollAnchor

        init() {
            let column = NSTableColumn(identifier: NSUserInterfaceItemIdentifier("c"))
            tableView.addTableColumn(column)
            tableView.rowHeight = 72
            tableView.headerView = nil
            scrollView.documentView = tableView
            dataSource.attach(tableView: tableView)
            anchor = AppKitScrollAnchor(scrollView: scrollView, tableView: tableView)

            window = NSWindow(
                contentRect: NSRect(x: 0, y: 0, width: 800, height: 600),
                styleMask: [.borderless],
                backing: .buffered,
                defer: false
            )
            window.contentView = scrollView
            scrollView.frame = window.contentView!.bounds
            window.contentView?.layoutSubtreeIfNeeded()
            anchor.startObserving()
        }

        func row(_ number: Int) -> AppKitMessageRow {
            AppKitMessageRow(
                id: String(format: "row-%04d", number),
                kind: .assistant,
                message: LumiChatMessage(
                    id: UUID(),
                    conversationID: UUID(),
                    role: .assistant,
                    content: "content \(number)",
                    createdAt: Date(timeIntervalSinceReferenceDate: Double(number))
                )
            )
        }

        func apply(_ rows: [AppKitMessageRow], hasEarlierRows: Bool = false) {
            dataSource.apply(snapshot: AppKitMessageListSnapshot(
                conversationID: UUID(),
                rows: rows,
                hasEarlierRows: hasEarlierRows
            ))
            layout()
        }

        func layout() {
            window.contentView?.layoutSubtreeIfNeeded()
        }

        var clip: NSClipView { scrollView.contentView }

        func scrollToRowTop(_ rowNumber: Int) {
            let index = dataSource.rows.firstIndex { $0.id == String(format: "row-%04d", rowNumber) }
            guard let index else { return }
            clip.scroll(to: NSPoint(x: 0, y: tableView.rect(ofRow: index).origin.y))
            layout()
        }

        func topVisibleRowID() -> String? {
            let visible = tableView.rows(in: tableView.visibleRect)
            guard visible.length > 0 else { return nil }
            let index = visible.location
            guard dataSource.rows.indices.contains(index) else { return nil }
            switch dataSource.rows[index] {
            case .loadEarlier:
                guard dataSource.rows.indices.contains(index + 1) else { return nil }
                return dataSource.rows[index + 1].id
            case .message(let row):
                return row.id
            }
        }
    }

    // MARK: - Bottom detection

    @Test("在底部时 isAtBottom 为 true，滚开后为 false")
    func isAtBottomDetection() {
        let env = Environment()
        env.apply((0..<30).map { env.row($0) })
        env.anchor.scrollToBottom()
        env.layout()
        #expect(env.anchor.isAtBottom())

        env.scrollToRowTop(0)
        #expect(!env.anchor.isAtBottom())
    }

    // MARK: - Prepending

    @Test("prepend 后恢复锚点：顶部可见行不变")
    func prependRestoresAnchor() {
        let env = Environment()
        // 当前窗口：行 10..39。
        env.apply((10..<40).map { env.row($0) })
        env.scrollToRowTop(20)
        let topBefore = env.topVisibleRowID()
        #expect(topBefore == "row-0020")

        env.anchor.captureAnchor()
        // 更早的 10 行前置：行 0..39。
        env.apply((0..<40).map { env.row($0) })
        #expect(env.topVisibleRowID() != topBefore) // 未恢复前会跳
        env.anchor.restoreAnchor()
        env.layout()

        #expect(env.topVisibleRowID() == topBefore)
    }

    @Test("prepend 且带 loadEarlier 头行时锚点恢复")
    func prependWithLoadEarlierHeader() {
        let env = Environment()
        env.apply((10..<40).map { env.row($0) })
        env.scrollToRowTop(20)
        let topBefore = env.topVisibleRowID()

        env.anchor.captureAnchor()
        // 更早行前置 + 头行出现（行下移一行）。
        env.apply((0..<40).map { env.row($0) }, hasEarlierRows: true)
        env.anchor.restoreAnchor()
        env.layout()

        #expect(env.topVisibleRowID() == topBefore)
    }

    // MARK: - Dynamic height correction

    @Test("动态行高变化后 restore 保持锚点行位置")
    func heightChangeRestoresAnchor() {
        let env = Environment()
        env.apply((0..<30).map { env.row($0) })
        env.scrollToRowTop(8)
        let topBefore = env.topVisibleRowID()

        env.anchor.captureAnchor()
        // 行高 72 → 100，所有行位置变化。
        env.tableView.rowHeight = 100
        env.layout()
        env.anchor.restoreAnchor()
        env.layout()

        #expect(env.topVisibleRowID() == topBefore)
    }

    // MARK: - Bottom follow

    @Test("在底部时 captureAnchor 不记录锚点，滚动到底部")
    func bottomFollowTakesPrecedence() {
        let env = Environment()
        env.apply((0..<5).map { env.row($0) })
        env.anchor.scrollToBottom()
        env.layout()
        #expect(env.anchor.isAtBottom())

        env.anchor.captureAnchor() // 底部 → 无锚点
        env.apply((0..<8).map { env.row($0) })
        env.anchor.restoreAnchor() // 无锚点 → 不动
        env.anchor.scrollToBottom()
        env.layout()

        #expect(env.anchor.isAtBottom())
        // 文档（8×72=576）小于视口（600）时全部可见，最后一行必须可见。
        let visible = env.tableView.rows(in: env.tableView.visibleRect)
        #expect(visible.contains(7))
    }

    @Test("scrollToBottom 定位到最后一行")
    func scrollToBottomTargetsLastRow() {
        let env = Environment()
        env.apply((0..<20).map { env.row($0) })
        env.anchor.scrollToBottom()
        env.layout()
        let visible = env.tableView.rows(in: env.tableView.visibleRect)
        #expect(visible.contains(19))
    }
}
