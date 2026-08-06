import AppKit
import Foundation
import MarkdownKitCore

/// Native TextKit view that renders prose Markdown blocks.
///
/// One non-scrolling `NSTextView` hosts paragraphs, headings, lists, quotes,
/// and inline styling (bold/italic/code/links). Code, tables, and Mermaid are
/// handled by dedicated views in Task 10; until then they degrade to plain
/// text lines. Width changes recompute height exactly once — repeated queries
/// return the cached measurement.
@MainActor
final class AppKitMarkdownView: NSView, NSTextViewDelegate {
    private let textView: NSTextView
    private let layoutManager = NSLayoutManager()
    private let textContainer = NSTextContainer()
    private var renderedWidth: CGFloat = 0
    private var onOpenLink: ((URL) -> Void)?

    override init(frame frameRect: NSRect) {
        let storage = NSTextStorage()
        layoutManager.addTextContainer(textContainer)
        storage.addLayoutManager(layoutManager)
        textContainer.lineFragmentPadding = 0
        textContainer.widthTracksTextView = false

        textView = NSTextView(frame: .zero, textContainer: textContainer)
        textView.translatesAutoresizingMaskIntoConstraints = false
        textView.drawsBackground = false
        textView.isEditable = false
        textView.isSelectable = true
        textView.isRichText = false
        textView.allowsUndo = false
        textView.textContainerInset = .zero
        textView.autoresizingMask = []

        super.init(frame: frameRect)

        textView.delegate = self
        addSubview(textView)
        NSLayoutConstraint.activate([
            textView.topAnchor.constraint(equalTo: topAnchor),
            textView.leadingAnchor.constraint(equalTo: leadingAnchor),
            textView.trailingAnchor.constraint(equalTo: trailingAnchor),
            textView.bottomAnchor.constraint(equalTo: bottomAnchor),
        ])
    }

    @available(*, unavailable)
    required init?(coder: NSCoder) { fatalError("init(coder:) has not been implemented") }

    // MARK: - Rendering

    /// Renders the document at the given width with the given theme.
    func render(
        document: AppKitMarkdownDocument,
        width: CGFloat,
        theme: AppKitMessageTheme,
        onOpenLink: ((URL) -> Void)? = nil
    ) {
        self.onOpenLink = onOpenLink
        let effectiveWidth = max(80, width)
        let attributed = Self.buildAttributedString(
            blocks: document.blocks,
            theme: theme
        )

        if effectiveWidth != renderedWidth {
            textContainer.size = NSSize(width: effectiveWidth, height: .greatestFiniteMagnitude)
            renderedWidth = effectiveWidth
        }
        textView.textStorage?.setAttributedString(attributed)
        textView.layoutManager?.ensureLayout(for: textContainer)

        // Fit the view to the laid-out height.
        let used = layoutManager.usedRect(for: textContainer).height
        frame.size.height = used
        textView.frame.size.height = used
    }

    /// Deterministically measures the height a document would take at `width`.
    /// Uses a throwaway layout so measurements never mutate the view.
    static func measureHeight(
        document: AppKitMarkdownDocument,
        width: CGFloat,
        theme: AppKitMessageTheme
    ) -> CGFloat {
        let effectiveWidth = max(80, width)
        let storage = NSTextStorage(attributedString: buildAttributedString(
            blocks: document.blocks,
            theme: theme
        ))
        let layout = NSLayoutManager()
        let container = NSTextContainer(size: NSSize(width: effectiveWidth, height: .greatestFiniteMagnitude))
        container.lineFragmentPadding = 0
        storage.addLayoutManager(layout)
        layout.addTextContainer(container)
        layout.ensureLayout(for: container)
        return layout.usedRect(for: container).height
    }

    // MARK: - NSTextViewDelegate

    func textView(_ textView: NSTextView, clickedOnLink link: Any, at charIndex: Int) -> Bool {
        guard let url = link as? URL else { return false }
        onOpenLink?(url)
        return true
    }

    // MARK: - Attributed string building

    private static func buildAttributedString(
        blocks: [MarkdownBlock],
        theme: AppKitMessageTheme
    ) -> NSAttributedString {
        let output = NSMutableAttributedString()
        for (index, block) in blocks.enumerated() {
            switch block {
            case let .heading(level, text):
                appendHeading(text, level: level, theme: theme, into: output)
            case let .paragraph(text):
                appendInline(text, font: theme.bodyFont, color: theme.textColor, theme: theme, into: output)
            case let .quote(text):
                appendQuote(text, theme: theme, into: output)
            case let .unorderedList(items):
                for item in items {
                    let prefix = item.taskState == nil ? "•  " : (item.taskState == .done ? "☑  " : "☐  ")
                    appendInline(prefix + item.text, font: theme.bodyFont, color: theme.textColor, theme: theme, into: output)
                }
            case let .orderedList(items):
                for item in items {
                    appendInline("\(item.index).  \(item.text)", font: theme.bodyFont, color: theme.textColor, theme: theme, into: output)
                }
            case let .codeBlock(language, code):
                // Full native code view lands in Task 10; degrade to plain text.
                appendInline(code, font: theme.codeFont, color: theme.textColor, theme: theme, into: output)
                _ = language
            case let .table(headers, rows):
                // Native table view lands in Task 10; degrade to a text matrix.
                let lines = [headers.joined(separator: " | ")] + rows.map { $0.joined(separator: " | ") }
                appendInline(lines.joined(separator: "\n"), font: theme.codeFont, color: theme.textColor, theme: theme, into: output)
            case .thematicBreak:
                output.append(NSAttributedString(
                    string: String(repeating: "─", count: 24),
                    attributes: [.foregroundColor: theme.secondaryTextColor]
                ))
            }

            if index < blocks.count - 1 {
                output.append(NSAttributedString(string: "\n"))
            }
        }
        return output
    }

    private static func appendHeading(
        _ text: String,
        level: Int,
        theme: AppKitMessageTheme,
        into output: NSMutableAttributedString
    ) {
        let font = theme.headingFonts[level] ?? theme.bodyFont
        appendInline(
            text,
            font: font,
            color: theme.textColor,
            theme: theme,
            into: output
        )
    }

    private static func appendQuote(
        _ text: String,
        theme: AppKitMessageTheme,
        into output: NSMutableAttributedString
    ) {
        let font = theme.bodyFont
        let indented = text.split(separator: "\n").map { "  \($0)" }.joined(separator: "\n")
        let attributed = NSMutableAttributedString(string: indented, attributes: [
            .font: font,
            .foregroundColor: theme.quoteColor,
        ])
        output.append(attributed)
    }

    /// Applies inline runs (bold/italic/code/link) on top of the base style.
    private static func appendInline(
        _ text: String,
        font: NSFont,
        color: NSColor,
        theme: AppKitMessageTheme,
        into output: NSMutableAttributedString
    ) {
        let attributed = NSMutableAttributedString(string: text, attributes: [
            .font: font,
            .foregroundColor: color,
        ])
        let runs = AppKitInlineMarkdownFormatter.parseRuns(in: text)
        for run in runs {
            guard run.range.location != NSNotFound,
                  run.range.location + run.range.length <= attributed.length else { continue }
            switch run.kind {
            case .plain:
                break
            case .bold:
                let bold = NSFontManager.shared.convert(font, toHaveTrait: .boldFontMask)
                attributed.addAttribute(.font, value: bold, range: run.range)
            case .italic:
                let italic = NSFontManager.shared.convert(font, toHaveTrait: .italicFontMask)
                attributed.addAttribute(.font, value: italic, range: run.range)
            case .code:
                attributed.addAttribute(.font, value: theme.codeFont, range: run.range)
                attributed.addAttribute(.backgroundColor, value: theme.codeBackgroundColor, range: run.range)
            case let .link(url):
                attributed.addAttribute(.link, value: URL(string: url) ?? url as NSString, range: run.range)
                attributed.addAttribute(.foregroundColor, value: theme.linkColor, range: run.range)
                attributed.addAttribute(.underlineStyle, value: NSUnderlineStyle.single.rawValue, range: run.range)
            }
        }
        output.append(attributed)
    }
}
