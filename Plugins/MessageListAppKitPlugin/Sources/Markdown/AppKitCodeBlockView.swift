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
    private let scrollView = CodeBlockScrollView()
    private let textView = CodeBlockTextView()

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
        self.scrollView.outerScrollView = outerScrollView
        self.textView.outerScrollView = outerScrollView
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

    // MARK: - Actions

    @objc private func copyPressed() {
        onCopy?()
    }
}

// MARK: - CodeBlockScrollView

/// NSScrollView 子类：作为代码块的内部滚动容器，水平方向由自身处理，
/// 垂直方向的滚轮事件转发给外层消息列表。
private class CodeBlockScrollView: NSScrollView {
    /// 外层消息列表的 NSScrollView，由 `AppKitCodeBlockView.configure` 注入。
    weak var outerScrollView: NSScrollView?

    override func scrollWheel(with event: NSEvent) {
        let isVertical = abs(event.scrollingDeltaY) > abs(event.scrollingDeltaX)

        if isVertical {
            // 尝试转发给外层消息列表
            if let outerScrollView, let clipView = outerScrollView.contentView as NSClipView? {
                let newY = min(
                    max(0, clipView.bounds.origin.y - event.scrollingDeltaY),
                    max(0, (outerScrollView.documentView?.bounds.height ?? 0) - clipView.bounds.height)
                )
                clipView.scroll(to: NSPoint(x: clipView.bounds.origin.x, y: newY))
                return
            }
        }

        // 水平手势，或者没有外层列表时，由自身处理
        super.scrollWheel(with: event)
    }
}

// MARK: - CodeBlockTextView

/// NSTextView 子类：垂直滚动事件转发给外层消息列表，防止代码块捕获滚动。
///
/// 在 AppKit 事件路由中，hitTest 找到的最深层视图首先接收事件。
/// 代码块内的 NSTextView 会拦截滚动事件，导致外层消息列表无法滚动。
/// 通过重写 scrollWheel，垂直滚动转发给外层列表，水平滚动由自身处理。
private class CodeBlockTextView: NSTextView {
    /// 外层消息列表的 NSScrollView。
    weak var outerScrollView: NSScrollView?

    override func scrollWheel(with event: NSEvent) {
        let isVertical = abs(event.scrollingDeltaY) > abs(event.scrollingDeltaX)

        if isVertical, let outerScrollView {
            // 垂直滚动：转发给外层消息列表
            if let clipView = outerScrollView.contentView as NSClipView? {
                let newY = min(
                    max(0, clipView.bounds.origin.y - event.scrollingDeltaY),
                    max(0, (outerScrollView.documentView?.bounds.height ?? 0) - clipView.bounds.height)
                )
                clipView.scroll(to: NSPoint(x: clipView.bounds.origin.x, y: newY))
            }
            return
        }

        // 水平滚动由自身处理
        super.scrollWheel(with: event)
    }
}
