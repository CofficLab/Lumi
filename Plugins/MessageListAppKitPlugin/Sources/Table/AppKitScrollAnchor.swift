import AppKit
import Foundation

/// Native scroll anchoring for the message table.
///
/// Responsibilities:
/// - observes `NSClipView.boundsDidChangeNotification` (no SwiftUI geometry
///   readers anywhere);
/// - defines "at bottom" with a 48 pt tolerance over document/clip geometry;
/// - before a prepend, captures the top visible stable row ID plus its pixel
///   offset, then restores the same row to the same offset after rows and
///   heights are applied;
/// - follows status/streaming/final rows only while the user was already at
///   the bottom.
@MainActor
final class AppKitScrollAnchor {
    struct AnchorPoint: Equatable {
        let rowID: String
        /// Distance from the row's top edge to the top of the clip view.
        let pixelOffset: CGFloat
    }

    let bottomTolerance: CGFloat

    private weak var scrollView: NSScrollView?
    private weak var tableView: NSTableView?
    private var currentAnchor: AnchorPoint?
    private var observation: NSObjectProtocol?

    init(
        scrollView: NSScrollView,
        tableView: NSTableView,
        bottomTolerance: CGFloat = 48
    ) {
        self.scrollView = scrollView
        self.tableView = tableView
        self.bottomTolerance = bottomTolerance
    }

    /// Starts observing clip-view bounds changes. Call once after the scroll
    /// view is attached to a window.
    func startObserving() {
        guard observation == nil, let scrollView else { return }
        observation = NotificationCenter.default.addObserver(
            forName: NSView.boundsDidChangeNotification,
            object: scrollView.contentView,
            queue: .main
        ) { [weak self] _ in
            Task { @MainActor [weak self] in
                self?.handleBoundsChange()
            }
        }
    }

    func stopObserving() {
        if let observation {
            NotificationCenter.default.removeObserver(observation)
        }
        observation = nil
    }

    // MARK: - Bottom detection

    /// Whether the user is at the bottom of the document (48 pt tolerance).
    func isAtBottom() -> Bool {
        guard let scrollView, let clipView = scrollView.contentView as NSClipView? else {
            return true
        }
        let documentHeight = scrollView.documentView?.bounds.height ?? 0
        let visibleHeight = clipView.bounds.height
        let offsetY = clipView.bounds.origin.y
        let distance = documentHeight - (offsetY + visibleHeight)
        return distance <= bottomTolerance
    }

    // MARK: - Anchoring

    /// Captures the top visible stable row before a structural change
    /// (prepend / height correction). No-op while at the bottom, where the
    /// bottom-follow path handles position.
    func captureAnchor() {
        guard !isAtBottom(),
              let tableView,
              let rowID = topVisibleRowID(in: tableView),
              let rowIndex = rowIndex(for: rowID, in: tableView),
              let clipView = tableView.enclosingScrollView?.contentView
        else {
            currentAnchor = nil
            return
        }
        let rowRect = tableView.rect(ofRow: rowIndex)
        // Offset of the row's top edge *within the visible region* (0 when the
        // row sits exactly at the top of the clip view).
        let offset = clipView.bounds.origin.y - rowRect.origin.y
        currentAnchor = AnchorPoint(rowID: rowID, pixelOffset: max(0, offset))
    }

    /// Restores the captured row to its captured pixel offset after rows or
    /// heights changed. Returns true when a restore was applied.
    @discardableResult
    func restoreAnchor() -> Bool {
        guard let anchor = currentAnchor,
              let tableView,
              let rowIndex = rowIndex(for: anchor.rowID, in: tableView) else {
            currentAnchor = nil
            return false
        }
        scroll(toRowTop: rowIndex, pixelOffset: anchor.pixelOffset)
        currentAnchor = nil
        return true
    }

    /// Clears any pending anchor (e.g. conversation switch).
    func clearAnchor() {
        currentAnchor = nil
    }

    /// Scrolls so the row with the given stable ID is at the top of the view.
    func scrollToRow(id: String) {
        guard let tableView,
              let rowIndex = rowIndex(for: id, in: tableView) else { return }
        tableView.scrollRowToVisible(rowIndex)
    }

    func scrollToBottom() {
        guard let scrollView, let tableView else { return }
        let rowCount = tableView.numberOfRows
        guard rowCount > 0 else { return }
        tableView.scrollRowToVisible(rowCount - 1)
        // Force the clip to the very bottom edge (scrollRowToVisible can land
        // short when the last row is taller than the viewport).
        if let clipView = scrollView.contentView as NSClipView? {
            let maxY = max(0, (scrollView.documentView?.bounds.height ?? 0) - clipView.bounds.height)
            clipView.scroll(to: NSPoint(x: 0, y: maxY))
        }
    }

    // MARK: - Private

    private func handleBoundsChange() {
        // Anchor restoration is invoked explicitly by the controller after
        // structural updates; this observer currently only invalidates stale
        // anchors when the user scrolls manually.
        if !isAtBottom() {
            // Keep the anchor — it is only consumed right after a prepend.
        }
    }

    private func topVisibleRowID(in tableView: NSTableView) -> String? {
        guard let dataSource = tableView.dataSource as? AppKitMessageListDataSource else {
            return nil
        }
        let visible = tableView.rows(in: tableView.visibleRect)
        guard visible.length > 0 else { return nil }
        let rowIndex = visible.location
        guard dataSource.rows.indices.contains(rowIndex) else { return nil }
        switch dataSource.rows[rowIndex] {
        case .loadEarlier:
            // Anchor below the load-earlier header so it survives its
            // appearance/disappearance.
            guard dataSource.rows.indices.contains(rowIndex + 1) else { return nil }
            return dataSource.rows[rowIndex + 1].id
        case .message(let row):
            return row.id
        }
    }

    private func rowIndex(for id: String, in tableView: NSTableView) -> Int? {
        guard let dataSource = tableView.dataSource as? AppKitMessageListDataSource else {
            return nil
        }
        return dataSource.rows.firstIndex { $0.id == id }
    }

    private func scroll(toRowTop rowIndex: Int, pixelOffset: CGFloat) {
        guard let scrollView, let tableView else { return }
        let rowRect = tableView.rect(ofRow: rowIndex)
        let targetY = max(0, rowRect.origin.y - pixelOffset)
        if let clipView = scrollView.contentView as NSClipView? {
            clipView.scroll(to: NSPoint(x: 0, y: targetY))
        }
    }
}
