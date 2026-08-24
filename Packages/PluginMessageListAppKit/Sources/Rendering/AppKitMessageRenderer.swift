import AppKit
import Foundation

/// Native renderer protocol for one message row type.
///
/// Every renderer owns exactly one root view per cell. Cells cache views in
/// `NSTableView`'s per-identifier reuse pool, so a reused cell never holds
/// subviews from a previous, incompatible renderer — `reuseIdentifier`
/// separates the pools.
@MainActor
protocol AppKitMessageRenderer: AnyObject {
    /// Table view reuse identifier (one pool per renderer type).
    var reuseIdentifier: NSUserInterfaceItemIdentifier { get }

    /// Creates a fresh root view for this row type.
    func makeView() -> NSView

    /// Binds the row's content to the given view (view comes from this
    /// renderer's reuse pool).
    func configure(view: NSView, row: AppKitMessageRow)

    /// Resets transient state (selection, actions, async installs) so the
    /// view can be reconfigured with a different row.
    func prepareForReuse(view: NSView)

    /// Returns the row's height for the given available width. Results are
    /// cached by the layout cache (Task 8+); this method must be deterministic
    /// and must not mutate state.
    func measure(row: AppKitMessageRow, width: CGFloat) -> CGFloat
}
