import AppKit
import Foundation

/// Native Markdown table view.
///
/// A horizontally scrollable grid of labels. Column widths are measured once
/// per configure call (equal split with a content-aware minimum for overflow
/// support); the grid never nests a vertical scroll view.
@MainActor
final class AppKitMarkdownTableView: NSView {
    static let cellPadding: CGFloat = 8
    static let headerPadding: CGFloat = 6
    static let rowHeight: CGFloat = 22

    private let scrollView = NSScrollView()
    private let gridView = NSView()

    override init(frame frameRect: NSRect) {
        super.init(frame: frameRect)

        scrollView.translatesAutoresizingMaskIntoConstraints = false
        scrollView.hasHorizontalScroller = true
        scrollView.hasVerticalScroller = false
        scrollView.autohidesScrollers = true
        scrollView.drawsBackground = false
        scrollView.borderType = .noBorder

        gridView.translatesAutoresizingMaskIntoConstraints = false
        scrollView.documentView = gridView

        addSubview(scrollView)
        NSLayoutConstraint.activate([
            scrollView.topAnchor.constraint(equalTo: topAnchor),
            scrollView.leadingAnchor.constraint(equalTo: leadingAnchor),
            scrollView.trailingAnchor.constraint(equalTo: trailingAnchor),
            scrollView.bottomAnchor.constraint(equalTo: bottomAnchor),
        ])
    }

    @available(*, unavailable)
    required init?(coder: NSCoder) { fatalError("init(coder:) has not been implemented") }

    func configure(headers: [String], rows: [[String]], theme: AppKitMessageTheme) {
        gridView.subviews.forEach { $0.removeFromSuperview() }

        guard !headers.isEmpty else { return }
        let columnCount = headers.count
        let colWidth = Self.contentWidth(headers: headers, rows: rows, columnCount: columnCount)

        let gridWidth = colWidth * CGFloat(columnCount)
        gridView.frame.size = NSSize(width: gridWidth, height: 1)
        gridView.wantsLayer = true

        var y: CGFloat = 0
        // Header row.
        for (index, header) in headers.enumerated() {
            let label = makeLabel(text: header, font: NSFont.systemFont(ofSize: 11, weight: .semibold), color: theme.textColor)
            label.frame = NSRect(
                x: CGFloat(index) * colWidth,
                y: y,
                width: colWidth - 1,
                height: Self.rowHeight
            )
            gridView.addSubview(label)
        }
        y += Self.rowHeight

        // Body rows.
        for row in rows {
            for (index, cell) in row.prefix(columnCount).enumerated() {
                let label = makeLabel(text: cell, font: theme.bodyFont, color: theme.textColor)
                label.frame = NSRect(
                    x: CGFloat(index) * colWidth,
                    y: y,
                    width: colWidth - 1,
                    height: Self.rowHeight
                )
                gridView.addSubview(label)
            }
            y += Self.rowHeight
        }

        gridView.frame.size.height = y
    }

    static func measureHeight(headers: [String], rows: [[String]]) -> CGFloat {
        let header = headers.isEmpty ? 0 : 1
        return CGFloat(header + rows.count) * rowHeight + headerPadding
    }

    // MARK: - Private

    private func makeLabel(text: String, font: NSFont, color: NSColor) -> NSTextField {
        let label = NSTextField(labelWithString: text)
        label.font = font
        label.textColor = color
        label.lineBreakMode = .byTruncatingTail
        label.maximumNumberOfLines = 1
        return label
    }

    /// Column width: equal split of the viewport width, but never below the
    /// widest cell's estimated width (enables horizontal overflow).
    private static func contentWidth(headers: [String], rows: [[String]], columnCount: Int) -> CGFloat {
        var widest = headers.map { estimatedWidth($0) }.max() ?? 80
        for row in rows {
            for cell in row.prefix(columnCount) {
                widest = max(widest, estimatedWidth(cell))
            }
        }
        return max(120, widest + cellPadding * 2)
    }

    private static func estimatedWidth(_ text: String) -> CGFloat {
        let font = NSFont.systemFont(ofSize: 11)
        let size = (text as NSString).size(withAttributes: [.font: font])
        return size.width + 4
    }
}
