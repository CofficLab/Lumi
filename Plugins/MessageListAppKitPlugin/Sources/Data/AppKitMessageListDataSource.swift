import AppKit
import Foundation

/// Data source for the native message table.
///
/// Applies immutable snapshots incrementally:
/// - computes an id-based prefix/suffix diff between the previous and next row
///   arrays, then issues only targeted `insertRows` / `removeRows` / reloads
///   inside `beginUpdates`/`endUpdates`;
/// - reserves full `reloadData()` for conversation switches and unrecoverable
///   snapshot mismatches;
/// - renders the optional "load earlier" row at index 0 with a fixed identity.
@MainActor
final class AppKitMessageListDataSource: NSObject, NSTableViewDataSource {
    /// Fixed identity for the load-earlier row so diffs stay stable.
    nonisolated static let loadEarlierRowID = "__load_earlier__"

    enum Row: Equatable {
        case loadEarlier
        case message(AppKitMessageRow)

        var id: String {
            switch self {
            case .loadEarlier: AppKitMessageListDataSource.loadEarlierRowID
            case .message(let row): row.id
            }
        }
    }

    /// Resolves the renderer for a message row. The controller injects the
    /// registry here once it lands (Task 11); currently everything falls back
    /// to the plain-text renderer.
    var rendererFor: (AppKitMessageRow) -> (any AppKitMessageRenderer) = { _ in
        AppKitFallbackRenderer()
    }
    var onLoadEarlier: (() -> Void)?
    var loadEarlierTitle: String = "加载更早消息"

    /// Latest applied display rows (including the optional load-earlier head).
    private(set) var rows: [Row] = []
    private weak var tableView: NSTableView?
    private var appliedConversationID: UUID?

    func attach(tableView: NSTableView) {
        self.tableView = tableView
        tableView.dataSource = self
    }

    // MARK: - Snapshot application

    func apply(snapshot: AppKitMessageListSnapshot) {
        guard let tableView else { return }
        var next: [Row] = []
        if snapshot.hasEarlierRows {
            next.append(.loadEarlier)
        }
        next.append(contentsOf: snapshot.displayRows.map(Row.message))

        let conversationChanged = appliedConversationID != snapshot.conversationID
        let unrecoverable = rows.isEmpty || next.isEmpty || conversationChanged
        if unrecoverable {
            rows = next
            appliedConversationID = snapshot.conversationID
            tableView.reloadData()
            return
        }

        let oldIDs = rows.map(\.id)
        let newIDs = next.map(\.id)
        let diff = Self.diff(old: oldIDs, new: newIDs)

        tableView.beginUpdates()
        defer { tableView.endUpdates() }

        if !diff.removals.isEmpty {
            tableView.removeRows(at: diff.removals, withAnimation: [])
        }
        if !diff.insertions.isEmpty {
            tableView.insertRows(at: diff.insertions, withAnimation: [])
        }

        // Same-id rows whose content changed → targeted reload.
        let reloadIndexes = reloadIndexes(old: rows, new: next)
        if !reloadIndexes.isEmpty {
            tableView.reloadData(forRowIndexes: reloadIndexes, columnIndexes: IndexSet(integer: 0))
        }

        rows = next
        appliedConversationID = snapshot.conversationID
    }

    // MARK: - NSTableViewDataSource

    func numberOfRows(in tableView: NSTableView) -> Int {
        rows.count
    }

    // NOTE: recent SDKs moved `tableView:viewForTableColumn:row:` from
    // NSTableViewDataSource to NSTableViewDelegate. Implemented here it
    // satisfies no protocol requirement, so Swift does NOT infer @objc and
    // the Objective-C runtime cannot see it — `respondsToSelector` returns
    // NO and NSTableView silently falls back to cell-based mode: it asks for
    // row counts and row heights but never creates a single row view,
    // leaving the list blank. The explicit @objc keeps the method visible to
    // runtimes that query the data source; the delegate forwards as well.
    @objc(tableView:viewForTableColumn:row:)
    func tableView(
        _ tableView: NSTableView,
        viewFor tableColumn: NSTableColumn?,
        row: Int
    ) -> NSView? {
        guard rows.indices.contains(row) else { return nil }
        switch rows[row] {
        case .loadEarlier:
            let cell = tableView.makeView(
                withIdentifier: AppKitLoadEarlierCellView.reuseIdentifier,
                owner: self
            ) as? AppKitLoadEarlierCellView ?? AppKitLoadEarlierCellView()
            cell.onLoadEarlier = onLoadEarlier
            cell.configure(title: loadEarlierTitle)
            return cell

        case .message(let messageRow):
            let renderer = rendererFor(messageRow)
            let cell = tableView.makeView(
                withIdentifier: renderer.reuseIdentifier,
                owner: self
            ) as? AppKitMessageCellView ?? AppKitMessageCellView(frame: .zero)
            cell.configure(row: messageRow, renderer: renderer)
            return cell
        }
    }

    // MARK: - Diffing

    /// Computes targeted removals/insertions via common prefix + suffix.
    ///
    /// The middle segment is fully removed and re-inserted (index-safe; avoids
    /// fragile move-row math). Append/prepend/head-toggle are all exact.
    static func diff(old: [String], new: [String]) -> (removals: IndexSet, insertions: IndexSet) {
        var prefix = 0
        while prefix < old.count, prefix < new.count, old[prefix] == new[prefix] {
            prefix += 1
        }
        var suffix = 0
        while suffix < old.count - prefix,
              suffix < new.count - prefix,
              old[old.count - 1 - suffix] == new[new.count - 1 - suffix] {
            suffix += 1
        }

        var removals = IndexSet()
        let oldMidEnd = old.count - suffix
        if prefix < oldMidEnd {
            removals.insert(integersIn: prefix..<oldMidEnd)
        }
        var insertions = IndexSet()
        let newMidEnd = new.count - suffix
        if prefix < newMidEnd {
            insertions.insert(integersIn: prefix..<newMidEnd)
        }
        return (removals, insertions)
    }

    private func reloadIndexes(old: [Row], new: [Row]) -> IndexSet {
        var indexes = IndexSet()
        let commonCount = min(old.count, new.count)
        for i in 0..<commonCount where old[i] != new[i] {
            indexes.insert(i)
        }
        return indexes
    }
}
