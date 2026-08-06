import AppKit
import Foundation

/// Native fenced-code block view.
///
/// Layout: a horizontal `NSScrollView` hosting a non-wrapping `NSTextView`,
/// with a language label and a copy button in a small header bar. Vertical
/// wheel deltas are forwarded to the outer message-list scroll view so code
/// blocks never trap the user's scroll.
@MainActor
final class AppKitCodeBlockView: NSView {
    static let headerHeight: CGFloat = 26

    private let headerBar = NSView()
    private let languageLabel = NSTextField(labelWithString: "")
    private let copyButton = NSButton(title: "复制", target: nil, action: nil)
    private let scrollView = NSScrollView()
    private let textView = NSTextView()

    /// The outer table scroll view receiving forwarded wheel events.
    private weak var outerScrollView: NSScrollView?

    var onCopy: (() -> Void)?

    override init(frame frameRect: NSRect) {
        super.init(frame: frameRect)

        headerBar.translatesAutoresizingMaskIntoConstraints = false
        languageLabel.translatesAutoresizingMaskIntoConstraints = false
        languageLabel.font = NSFont.monospacedSystemFont(ofSize: 10, weight: .medium)
        languageLabel.textColor = .secondaryLabelColor
        languageLabel.lineBreakMode = .byTruncatingTail

        copyButton.translatesAutoresizingMaskIntoConstraints = false
        copyButton.bezelStyle = .inline
        copyButton.controlSize = .mini
        copyButton.font = NSFont.systemFont(ofSize: 10)
        copyButton.target = self
        copyButton.action = #selector(copyPressed)

        headerBar.addSubview(languageLabel)
        headerBar.addSubview(copyButton)
        NSLayoutConstraint.activate([
            languageLabel.leadingAnchor.constraint(equalTo: headerBar.leadingAnchor, constant: 10),
            languageLabel.centerYAnchor.constraint(equalTo: headerBar.centerYAnchor),
            copyButton.trailingAnchor.constraint(equalTo: headerBar.trailingAnchor, constant: -6),
            copyButton.centerYAnchor.constraint(equalTo: headerBar.centerYAnchor),
        ])

        scrollView.translatesAutoresizingMaskIntoConstraints = false
        scrollView.hasHorizontalScroller = true
        scrollView.hasVerticalScroller = false
        scrollView.autohidesScrollers = true
        scrollView.drawsBackground = false
        scrollView.borderType = .noBorder

        textView.isEditable = false
        textView.isSelectable = true
        textView.drawsBackground = false
        textView.isHorizontallyResizable = true
        textView.isVerticallyResizable = false
        textView.autoresizingMask = []
        textView.textContainer?.widthTracksTextView = false
        textView.textContainer?.containerSize = NSSize(
            width: CGFloat.greatestFiniteMagnitude,
            height: CGFloat.greatestFiniteMagnitude
        )

        scrollView.documentView = textView
        textView.translatesAutoresizingMaskIntoConstraints = false

        addSubview(headerBar)
        addSubview(scrollView)
        NSLayoutConstraint.activate([
            headerBar.topAnchor.constraint(equalTo: topAnchor),
            headerBar.leadingAnchor.constraint(equalTo: leadingAnchor),
            headerBar.trailingAnchor.constraint(equalTo: trailingAnchor),
            headerBar.heightAnchor.constraint(equalToConstant: Self.headerHeight),

            scrollView.topAnchor.constraint(equalTo: headerBar.bottomAnchor),
            scrollView.leadingAnchor.constraint(equalTo: leadingAnchor),
            scrollView.trailingAnchor.constraint(equalTo: trailingAnchor),
            scrollView.bottomAnchor.constraint(equalTo: bottomAnchor),
        ])
    }

    @available(*, unavailable)
    required init?(coder: NSCoder) { fatalError("init(coder:) has not been implemented") }

    // MARK: - Configuration

    func configure(
        code: String,
        language: String?,
        theme: AppKitMessageTheme,
        outerScrollView: NSScrollView? = nil,
        onCopy: (() -> Void)? = nil
    ) {
        self.outerScrollView = outerScrollView
        self.onCopy = onCopy

        languageLabel.stringValue = language?.isEmpty == false ? language! : "code"
        copyButton.title = "复制"

        let attributes: [NSAttributedString.Key: Any] = [
            .font: theme.codeFont,
            .foregroundColor: theme.textColor,
        ]
        textView.textStorage?.setAttributedString(NSAttributedString(string: code, attributes: attributes))
        textView.layoutManager?.ensureLayout(for: textView.textContainer!)
        textView.frame.size = NSSize(
            width: max(bounds.width, (textView.layoutManager?.usedRect(for: textView.textContainer!).width ?? 0) + 16),
            height: max(1, textView.frame.height)
        )
    }

    /// Deterministic height for a code block: header + wrapped lines + padding.
    static func measureHeight(code: String, width: CGFloat, theme: AppKitMessageTheme) -> CGFloat {
        let lineCount = max(1, code.components(separatedBy: .newlines).count)
        let lineHeight = theme.codeFont.boundingRectForFont.height + 4
        return headerHeight + CGFloat(lineCount) * lineHeight + 12
    }

    // MARK: - Wheel forwarding

    override func scrollWheel(with event: NSEvent) {
        // Forward vertical scrolling to the outer list so long code blocks do
        // not trap the wheel. Horizontal remains inside the code block.
        if abs(event.scrollingDeltaY) > abs(event.scrollingDeltaX) {
            if let outerScrollView, let clipView = outerScrollView.contentView as NSClipView? {
                let newY = min(
                    max(0, clipView.bounds.origin.y + event.scrollingDeltaY),
                    max(0, (outerScrollView.documentView?.bounds.height ?? 0) - clipView.bounds.height)
                )
                clipView.scroll(to: NSPoint(x: clipView.bounds.origin.x, y: newY))
                return
            }
        }
        super.scrollWheel(with: event)
    }

    // MARK: - Actions

    @objc private func copyPressed() {
        onCopy?()
    }
}
