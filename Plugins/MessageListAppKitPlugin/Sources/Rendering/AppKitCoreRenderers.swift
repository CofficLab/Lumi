import AppKit
import Foundation

// MARK: - User Renderer

/// User message: Markdown body in a light container, no header chrome.
@MainActor
final class AppKitUserRenderer: AppKitMessageRenderer {
    let reuseIdentifier = NSUserInterfaceItemIdentifier("AppKitUserRow")
    private let environment: AppKitMessageRendererRegistry.Environment

    init(environment: AppKitMessageRendererRegistry.Environment) {
        self.environment = environment
    }

    func makeView() -> NSView {
        let root = NSView()
        let container = AppKitMarkdownBlockContainerView(
            mermaidCache: environment.mermaidCache,
            outerScrollView: environment.outerScrollView
        )
        container.translatesAutoresizingMaskIntoConstraints = false
        root.addSubview(container)
        NSLayoutConstraint.activate([
            container.topAnchor.constraint(equalTo: root.topAnchor, constant: 6),
            container.leadingAnchor.constraint(equalTo: root.leadingAnchor, constant: 12),
            container.trailingAnchor.constraint(equalTo: root.trailingAnchor, constant: -12),
            container.bottomAnchor.constraint(lessThanOrEqualTo: root.bottomAnchor),
        ])
        return root
    }

    func configure(view: NSView, row: AppKitMessageRow) {
        guard let container = view.subviews.compactMap({ $0 as? AppKitMarkdownBlockContainerView }).first else { return }
        container.onOpenLink = { url in NSWorkspace.shared.open(url) }
        let document = environment.layoutCache.document(for: row.content)
        container.configure(document: document, width: max(80, view.bounds.width - 24), theme: environment.theme)
    }

    func prepareForReuse(view: NSView) {
        view.subviews.forEach { $0.subviews.forEach { $0.removeFromSuperview() } }
    }

    func measure(row: AppKitMessageRow, width: CGFloat) -> CGFloat {
        let document = environment.layoutCache.document(for: row.content)
        return environment.layoutCache.height(
            for: AppKitRowLayoutKey(
                rowID: row.id,
                contentHash: document.contentHash,
                availableWidth: width,
                scale: NSScreen.main?.backingScaleFactor ?? 2,
                themeRevision: environment.theme.revision,
                verbosity: "default"
            )
        ) {
            AppKitMarkdownBlockContainerView.measureHeight(
                document: document, width: width, theme: environment.theme
            ) + 12
        }
    }
}

// MARK: - System Renderer

/// System message: bordered utility box with secondary text.
@MainActor
final class AppKitSystemRenderer: AppKitMessageRenderer {
    let reuseIdentifier = NSUserInterfaceItemIdentifier("AppKitSystemRow")
    private let environment: AppKitMessageRendererRegistry.Environment
    private let box = NSBox()

    init(environment: AppKitMessageRendererRegistry.Environment) {
        self.environment = environment
    }

    func makeView() -> NSView {
        box.boxType = .custom
        box.borderType = .lineBorder
        box.borderWidth = 0.5
        box.cornerRadius = 8
        box.borderColor = NSColor.separatorColor
        box.fillColor = NSColor.controlBackgroundColor.withAlphaComponent(0.5)
        box.contentViewMargins = NSSize(width: 10, height: 6)
        return box
    }

    func configure(view: NSView, row: AppKitMessageRow) {
        guard let box = view as? NSBox else { return }
        let label = NSTextField(wrappingLabelWithString: row.content)
        label.font = NSFont.systemFont(ofSize: 12)
        label.textColor = .secondaryLabelColor
        box.contentView = label
    }

    func prepareForReuse(view: NSView) {
        (view as? NSBox)?.contentView = nil
    }

    func measure(row: AppKitMessageRow, width: CGFloat) -> CGFloat {
        let label = NSTextField(wrappingLabelWithString: row.content)
        label.font = NSFont.systemFont(ofSize: 12)
        label.frame = NSRect(x: 0, y: 0, width: max(80, width - 24), height: .greatestFiniteMagnitude)
        label.sizeToFit()
        return label.frame.height + 20
    }
}

// MARK: - Status Renderer

/// Status row: spinner + text (e.g. "正在生成回复…").
@MainActor
final class AppKitStatusRenderer: AppKitMessageRenderer {
    let reuseIdentifier = NSUserInterfaceItemIdentifier("AppKitStatusRow")
    private let theme: AppKitMessageTheme

    init(theme: AppKitMessageTheme) {
        self.theme = theme
    }

    func makeView() -> NSView {
        let root = NSView()
        let indicator = NSProgressIndicator()
        indicator.translatesAutoresizingMaskIntoConstraints = false
        indicator.style = .spinning
        indicator.controlSize = .small
        indicator.isIndeterminate = true
        indicator.startAnimation(nil)

        let label = NSTextField(labelWithString: "")
        label.translatesAutoresizingMaskIntoConstraints = false
        label.font = NSFont.systemFont(ofSize: 12)
        label.textColor = theme.secondaryTextColor
        label.identifier = NSUserInterfaceItemIdentifier("statusLabel")

        root.addSubview(indicator)
        root.addSubview(label)
        NSLayoutConstraint.activate([
            indicator.leadingAnchor.constraint(equalTo: root.leadingAnchor, constant: 14),
            indicator.centerYAnchor.constraint(equalTo: root.centerYAnchor),
            label.leadingAnchor.constraint(equalTo: indicator.trailingAnchor, constant: 8),
            label.trailingAnchor.constraint(lessThanOrEqualTo: root.trailingAnchor, constant: -12),
            label.centerYAnchor.constraint(equalTo: root.centerYAnchor),
        ])
        return root
    }

    func configure(view: NSView, row: AppKitMessageRow) {
        let label = view.subviews.compactMap { $0 as? NSTextField }.first { $0.identifier?.rawValue == "statusLabel" }
        label?.stringValue = row.content.isEmpty ? "处理中…" : row.content
    }

    func prepareForReuse(view: NSView) {
        let label = view.subviews.compactMap { $0 as? NSTextField }.first { $0.identifier?.rawValue == "statusLabel" }
        label?.stringValue = ""
    }

    func measure(row: AppKitMessageRow, width: CGFloat) -> CGFloat {
        28
    }
}

// MARK: - Error Renderer

/// Error row: summary + HTTP status/body + raw detail, all selectable.
@MainActor
final class AppKitErrorRenderer: AppKitMessageRenderer {
    let reuseIdentifier = NSUserInterfaceItemIdentifier("AppKitErrorRow")
    private let theme: AppKitMessageTheme

    init(theme: AppKitMessageTheme) {
        self.theme = theme
    }

    func makeView() -> NSView {
        let root = NSView()
        let box = NSBox()
        box.boxType = .custom
        box.borderType = .lineBorder
        box.borderWidth = 0.5
        box.cornerRadius = 8
        box.borderColor = NSColor.systemRed.withAlphaComponent(0.4)
        box.fillColor = NSColor.systemRed.withAlphaComponent(0.06)
        box.translatesAutoresizingMaskIntoConstraints = false
        root.addSubview(box)
        NSLayoutConstraint.activate([
            box.topAnchor.constraint(equalTo: root.topAnchor, constant: 4),
            box.leadingAnchor.constraint(equalTo: root.leadingAnchor, constant: 12),
            box.trailingAnchor.constraint(equalTo: root.trailingAnchor, constant: -12),
            box.bottomAnchor.constraint(lessThanOrEqualTo: root.bottomAnchor),
        ])
        return root
    }

    func configure(view: NSView, row: AppKitMessageRow) {
        guard let box = view.subviews.compactMap({ $0 as? NSBox }).first else { return }
        let message = row.message
        var lines: [String] = ["⚠️ 请求失败"]
        if let status = message.httpStatusCode {
            lines.append("HTTP \(status)")
        }
        let summary = (message.rawErrorDetail ?? message.content).trimmingCharacters(in: .whitespacesAndNewlines)
        if !summary.isEmpty {
            lines.append(summary)
        }
        if let body = message.httpBody, !body.isEmpty {
            lines.append(body)
        }

        let label = NSTextField(wrappingLabelWithString: lines.joined(separator: "\n"))
        label.font = NSFont.monospacedSystemFont(ofSize: 11, weight: .regular)
        label.textColor = .systemRed
        box.contentView = label
    }

    func prepareForReuse(view: NSView) {
        (view.subviews.compactMap { $0 as? NSBox }).first?.contentView = nil
    }

    func measure(row: AppKitMessageRow, width: CGFloat) -> CGFloat {
        let message = row.message
        var lines: [String] = ["⚠️ 请求失败"]
        if let status = message.httpStatusCode { lines.append("HTTP \(status)") }
        let summary = (message.rawErrorDetail ?? message.content).trimmingCharacters(in: .whitespacesAndNewlines)
        if !summary.isEmpty { lines.append(summary) }
        let text = lines.joined(separator: "\n")
        let label = NSTextField(wrappingLabelWithString: text)
        label.font = NSFont.monospacedSystemFont(ofSize: 11, weight: .regular)
        label.frame = NSRect(x: 0, y: 0, width: max(80, width - 24), height: .greatestFiniteMagnitude)
        label.sizeToFit()
        return label.frame.height + 16
    }
}
