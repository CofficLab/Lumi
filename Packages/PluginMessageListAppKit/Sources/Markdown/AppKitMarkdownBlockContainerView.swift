import AppKit
import Foundation
import MarkdownKitCore

/// Composes the blocks of one Markdown document into native subviews:
/// prose runs (paragraphs/headings/lists/quotes) render through
/// `AppKitMarkdownView`; fenced code, tables, Mermaid, and thematic breaks use
/// their dedicated views. Blocks are laid out top-to-bottom with a fixed
/// spacing; heights are deterministic via `measureHeight`.
@MainActor
final class AppKitMarkdownBlockContainerView: NSView {
    static let blockSpacing: CGFloat = 8

    /// Injected by the owning renderer (Task 12+ wires copy/open actions).
    var onOpenLink: ((URL) -> Void)?
    var onCopyCode: ((String) -> Void)?

    private let mermaidCache: AppKitMermaidCache
    private weak var outerScrollView: NSScrollView?

    init(mermaidCache: AppKitMermaidCache, outerScrollView: NSScrollView? = nil) {
        self.mermaidCache = mermaidCache
        self.outerScrollView = outerScrollView
        super.init(frame: .zero)
    }

    @available(*, unavailable)
    required init?(coder: NSCoder) { fatalError("init(coder:) has not been implemented") }

    // MARK: - Rendering

    func configure(
        document: AppKitMarkdownDocument,
        width: CGFloat,
        theme: AppKitMessageTheme
    ) {
        subviews.forEach { $0.removeFromSuperview() }
        let effectiveWidth = max(80, width)

        var y: CGFloat = 0
        var proseBlocks: [MarkdownBlock] = []

        func flushProse() {
            guard !proseBlocks.isEmpty else { return }
            let proseDocument = AppKitMarkdownDocument(
                source: proseBlocks.map(Self.blockKey).joined(separator: "\n"),
                contentHash: "prose",
                blocks: proseBlocks
            )
            let view = AppKitMarkdownView(frame: .zero)
            view.render(document: proseDocument, width: effectiveWidth, theme: theme) { [weak self] url in
                self?.onOpenLink?(url)
            }
            // The markdown view is frame-managed here: give it the full width,
            // or its internal NSTextView (constrained to its edges) renders at
            // zero width and the prose is invisible.
            view.frame = NSRect(x: 0, y: y, width: effectiveWidth, height: view.frame.height)
            addSubview(view)
            y += view.frame.height + Self.blockSpacing
            proseBlocks = []
        }

        for block in document.blocks {
            switch block {
            case .codeBlock(let language, let code):
                if MarkdownParser.isMermaidCodeBlock(language: language) {
                    flushProse()
                    let mermaid = AppKitMermaidView(frame: .zero)
                    mermaid.configure(source: code, cache: mermaidCache, theme: theme)
                    mermaid.frame = NSRect(
                        x: 0, y: y,
                        width: effectiveWidth,
                        height: AppKitMermaidView.placeholderHeight
                    )
                    addSubview(mermaid)
                    y += mermaid.frame.height + Self.blockSpacing
                } else {
                    flushProse()
                    let codeView = AppKitCodeBlockView(frame: .zero)
                    codeView.configure(
                        code: code,
                        language: language,
                        theme: theme,
                        outerScrollView: outerScrollView
                    ) { [weak self] in
                        self?.onCopyCode?(code)
                    }
                    codeView.frame = NSRect(
                        x: 0, y: y,
                        width: effectiveWidth,
                        height: AppKitCodeBlockView.measureHeight(code: code, width: effectiveWidth, theme: theme)
                    )
                    addSubview(codeView)
                    y += codeView.frame.height + Self.blockSpacing
                }

            case .table(let headers, let rows):
                flushProse()
                let table = AppKitMarkdownTableView(frame: .zero)
                table.configure(headers: headers, rows: rows, theme: theme)
                let height = AppKitMarkdownTableView.measureHeight(headers: headers, rows: rows)
                table.frame = NSRect(x: 0, y: y, width: effectiveWidth, height: height)
                addSubview(table)
                y += height + Self.blockSpacing

            case .thematicBreak:
                flushProse()
                let rule = NSBox()
                rule.boxType = .separator
                rule.frame = NSRect(x: 0, y: y + 4, width: effectiveWidth, height: 1)
                addSubview(rule)
                y += 9 + Self.blockSpacing

            case .paragraph, .heading, .unorderedList, .orderedList, .quote:
                proseBlocks.append(block)
            }
        }
        flushProse()

        frame.size = NSSize(width: effectiveWidth, height: max(0, y - Self.blockSpacing))
    }

    /// Deterministic height for a full document at a given width.
    static func measureHeight(
        document: AppKitMarkdownDocument,
        width: CGFloat,
        theme: AppKitMessageTheme
    ) -> CGFloat {
        let effectiveWidth = max(80, width)
        var total: CGFloat = 0
        var proseBlocks: [MarkdownBlock] = []

        func flushProse() {
            guard !proseBlocks.isEmpty else { return }
            let proseDocument = AppKitMarkdownDocument(
                source: "prose",
                contentHash: "prose",
                blocks: proseBlocks
            )
            total += AppKitMarkdownView.measureHeight(
                document: proseDocument, width: effectiveWidth, theme: theme
            )
            total += Self.blockSpacing
            proseBlocks = []
        }

        for block in document.blocks {
            switch block {
            case .codeBlock(let language, let code):
                if MarkdownParser.isMermaidCodeBlock(language: language) {
                    flushProse()
                    total += AppKitMermaidView.placeholderHeight + Self.blockSpacing
                } else {
                    flushProse()
                    total += AppKitCodeBlockView.measureHeight(code: code, width: effectiveWidth, theme: theme)
                    total += Self.blockSpacing
                }
            case .table(let headers, let rows):
                flushProse()
                total += AppKitMarkdownTableView.measureHeight(headers: headers, rows: rows)
                total += Self.blockSpacing
            case .thematicBreak:
                flushProse()
                total += 9 + Self.blockSpacing
            case .paragraph, .heading, .unorderedList, .orderedList, .quote:
                proseBlocks.append(block)
            }
        }
        flushProse()
        return max(0, total - Self.blockSpacing)
    }

    private static func blockKey(_ block: MarkdownBlock) -> String {
        // Only used to fingerprint the prose source; blocks are deterministic.
        "\(block)"
    }
}
