import AppKit
import Foundation

/// Table delegate for the native message list.
///
/// Row heights currently use a fixed placeholder; the layout cache (Task 8+)
/// will provide deterministic, width/theme-aware measurements here.
@MainActor
final class AppKitMessageTableDelegate: NSObject, NSTableViewDelegate {
    static let fixedRowHeight: CGFloat = 72
    static let loadEarlierRowHeight: CGFloat = 40

    /// Resolves the renderer for a message row (mirrors the data source).
    var rendererFor: (AppKitMessageRow) -> (any AppKitMessageRenderer) = { _ in
        AppKitFallbackRenderer()
    }

    private weak var dataSource: AppKitMessageListDataSource?
    private var availableWidth: CGFloat = 0

    func attach(tableView: NSTableView, dataSource: AppKitMessageListDataSource) {
        tableView.delegate = self
        self.dataSource = dataSource
    }

    func tableView(_ tableView: NSTableView, heightOfRow row: Int) -> CGFloat {
        guard let rows = dataSource?.rows, rows.indices.contains(row) else {
            return Self.fixedRowHeight
        }
        switch rows[row] {
        case .loadEarlier:
            return Self.loadEarlierRowHeight
        case .message(let messageRow):
            let width = max(200, tableView.bounds.width - 24)
            if width != availableWidth {
                availableWidth = width
            }
            let height = rendererFor(messageRow).measure(row: messageRow, width: width)
            print("[MessageListAppKit] heightOfRow row=\(row) h=\(height)")
            return height
        }
    }

    func tableView(_ tableView: NSTableView, shouldSelectRow row: Int) -> Bool {
        // Keep the table non-selecting: text selection lives inside row views.
        false
    }

    func tableView(_ tableView: NSTableView, rowActionsForRow row: Int, edge: NSTableView.RowActionEdge) -> [NSTableViewRowAction] {
        []
    }
}
