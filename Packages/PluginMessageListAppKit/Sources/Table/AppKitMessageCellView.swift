import AppKit
import Foundation

/// Reusable table cell owning exactly one renderer root view.
///
/// Reuse contract:
/// - `NSTableView` pools cells by `reuseIdentifier`, so a cell recycled into a
///   different row type receives a `configure(row:renderer:)` call with a
///   renderer whose `reuseIdentifier` differs. The cell then swaps the entire
///   root view instead of trying to mutate an incompatible one.
/// - Before any reconfiguration, `prepareForReuse` resets transient state.
@MainActor
final class AppKitMessageCellView: NSTableCellView {
    private var renderer: (any AppKitMessageRenderer)?
    private(set) var row: AppKitMessageRow?

    // MARK: - Configuration

    /// Configures the cell for a row, swapping the root view when the
    /// renderer's reuse identifier changes.
    func configure(row: AppKitMessageRow, renderer: any AppKitMessageRenderer) {
        if renderer.reuseIdentifier != self.renderer?.reuseIdentifier {
            removeRootView()
            self.renderer = renderer
            let rootView = renderer.makeView()
            rootView.translatesAutoresizingMaskIntoConstraints = false
            addSubview(rootView)
            NSLayoutConstraint.activate([
                rootView.topAnchor.constraint(equalTo: topAnchor),
                rootView.leadingAnchor.constraint(equalTo: leadingAnchor),
                rootView.trailingAnchor.constraint(equalTo: trailingAnchor),
                rootView.bottomAnchor.constraint(equalTo: bottomAnchor),
            ])
            rootView.autoresizingMask = [.width, .height]
        }

        self.row = row
        if let rootView = rootView {
            renderer.configure(view: rootView, row: row)
        }
    }

    override func prepareForReuse() {
        super.prepareForReuse()
        row = nil
        if let rootView, let renderer {
            renderer.prepareForReuse(view: rootView)
        }
    }

    // MARK: - Helpers

    private var rootView: NSView? {
        subviews.first
    }

    private func removeRootView() {
        if let rootView {
            rootView.removeFromSuperview()
        }
    }
}
