import AppKit
import Foundation
import Testing
import LumiKernel
@testable import MessageListAppKitPlugin

/// Bisection harness: a plain view-based NSTableView in an NSScrollView,
/// applying the view controller's configuration piece by piece to find
/// what prevents row-view creation (blank list).
@Suite(.serialized)
@MainActor
struct AppKitTableBisectTests {
    @MainActor
    private final class PlainDataSource: NSObject, NSTableViewDataSource, NSTableViewDelegate {
        var viewForCalls = 0

        func numberOfRows(in tableView: NSTableView) -> Int { 8 }

        func tableView(_ tableView: NSTableView, viewFor tableColumn: NSTableColumn?, row: Int) -> NSView? {
            viewForCalls += 1
            let label = NSTextField(labelWithString: "row \(row)")
            label.frame = NSRect(x: 0, y: 0, width: 200, height: 20)
            return label
        }

        func tableView(_ tableView: NSTableView, heightOfRow row: Int) -> CGFloat { 28 }
    }

    private func makeWindowedTable(
        configure: (NSScrollView, NSTableView) -> Void
    ) -> (NSWindow, NSTableView, PlainDataSource) {
        let scrollView = NSScrollView()
        scrollView.frame = NSRect(x: 0, y: 0, width: 824, height: 655)
        scrollView.hasVerticalScroller = true

        let table = NSTableView()
        let dataSource = PlainDataSource()
        table.dataSource = dataSource
        table.delegate = dataSource

        configure(scrollView, table)

        let window = NSWindow(
            contentRect: NSRect(x: 0, y: 0, width: 824, height: 655),
            styleMask: [.titled],
            backing: .buffered,
            defer: false
        )
        window.contentView?.addSubview(scrollView)
        window.orderFront(nil)
        window.layoutIfNeeded()
        table.reloadData()
        table.layoutSubtreeIfNeeded()
        table.displayIfNeeded()
        RunLoop.main.run(until: Date().addingTimeInterval(0.1))
        table.layoutSubtreeIfNeeded()
        return (window, table, dataSource)
    }

    private func rowViewCount(_ table: NSTableView) -> Int {
        table.subviews.compactMap { $0 as? NSTableRowView }.count
    }

    @Test("裸配置：scrollView + table + 一列")
    func baseline() {
        let (_, table, ds) = makeWindowedTable { scrollView, table in
            table.addTableColumn(NSTableColumn(identifier: NSUserInterfaceItemIdentifier("c")))
            scrollView.documentView = table
        }
        print("BISECT baseline: viewFor=\(ds.viewForCalls) rowViews=\(rowViewCount(table)) visible=\(table.visibleRect)")
        #expect(rowViewCount(table) > 0)
    }

    @Test("VC 完整 table 配置")
    func fullViewControllerConfig() {
        let (_, table, ds) = makeWindowedTable { scrollView, table in
            scrollView.hasHorizontalScroller = false
            scrollView.autohidesScrollers = true
            scrollView.drawsBackground = false
            scrollView.borderType = .noBorder

            table.autoresizingMask = [.width]
            table.allowsMultipleSelection = false
            table.allowsEmptySelection = true
            table.usesAlternatingRowBackgroundColors = false
            table.selectionHighlightStyle = .none
            table.headerView = nil
            table.rowSizeStyle = .custom
            table.floatsGroupRows = false
            table.columnAutoresizingStyle = .lastColumnOnlyAutoresizingStyle

            let column = NSTableColumn(identifier: NSUserInterfaceItemIdentifier("message"))
            column.resizingMask = .autoresizingMask
            column.width = 300
            column.minWidth = 80
            table.addTableColumn(column)

            scrollView.documentView = table
        }
        print("BISECT full: viewFor=\(ds.viewForCalls) rowViews=\(rowViewCount(table)) visible=\(table.visibleRect)")
        #expect(rowViewCount(table) > 0)
    }

    @Test("真实 dataSource/delegate + 快照 apply")
    func realDataSourceAndDelegate() {
        let scrollView = NSScrollView()
        scrollView.frame = NSRect(x: 0, y: 0, width: 824, height: 655)
        scrollView.hasVerticalScroller = true
        scrollView.hasHorizontalScroller = false
        scrollView.autohidesScrollers = true
        scrollView.drawsBackground = false
        scrollView.borderType = .noBorder

        let table = NSTableView()
        table.autoresizingMask = [.width]
        table.allowsMultipleSelection = false
        table.allowsEmptySelection = true
        table.usesAlternatingRowBackgroundColors = false
        table.selectionHighlightStyle = .none
        table.headerView = nil
        table.rowSizeStyle = .custom
        table.floatsGroupRows = false
        table.columnAutoresizingStyle = .lastColumnOnlyAutoresizingStyle
        let column = NSTableColumn(identifier: NSUserInterfaceItemIdentifier("message"))
        column.resizingMask = .autoresizingMask
        column.width = 300
        column.minWidth = 80
        table.addTableColumn(column)
        scrollView.documentView = table

        let dataSource = AppKitMessageListDataSource()
        dataSource.attach(tableView: table)
        let delegate = AppKitMessageTableDelegate()
        delegate.attach(tableView: table, dataSource: dataSource)

        let window = NSWindow(
            contentRect: NSRect(x: 0, y: 0, width: 824, height: 655),
            styleMask: [.titled],
            backing: .buffered,
            defer: false
        )
        window.contentView?.addSubview(scrollView)
        window.orderFront(nil)
        window.layoutIfNeeded()

        var rows: [AppKitMessageRow] = []
        for i in 0..<8 {
            let id = UUID(uuidString: String(format: "%08X-0000-0000-0000-0000000000%02d", i, i % 100)) ?? UUID()
            let role: LumiChatMessageRole = i % 2 == 0 ? .user : .assistant
            let message = LumiChatMessage(
                id: id,
                conversationID: UUID(),
                role: role,
                content: "message \(i)",
                createdAt: Date(timeIntervalSinceReferenceDate: 100 + Double(i))
            )
            rows.append(AppKitMessageRow(kind: role == .user ? .user : .assistant, message: message))
        }
        dataSource.apply(snapshot: AppKitMessageListSnapshot(conversationID: UUID(), rows: rows))

        table.layoutSubtreeIfNeeded()
        table.displayIfNeeded()
        RunLoop.main.run(until: Date().addingTimeInterval(0.1))
        table.layoutSubtreeIfNeeded()

        print("BISECT realDS: rowViews=\(rowViewCount(table)) visible=\(table.visibleRect) numRows=\(table.numberOfRows)")
        #expect(rowViewCount(table) > 0)
    }
}
