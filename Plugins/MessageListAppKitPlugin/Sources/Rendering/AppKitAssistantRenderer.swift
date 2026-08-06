import AppKit
import Foundation

/// Assistant / streaming renderer: full Markdown document in a block
/// container, with a compact header (timestamp, tokens, copy).
@MainActor
final class AppKitAssistantRenderer: AppKitMessageRenderer {
    let reuseIdentifier = NSUserInterfaceItemIdentifier("AppKitAssistantRow")

    private let environment: AppKitMessageRendererRegistry.Environment
    private let header = AppKitMessageHeaderView()

    init(environment: AppKitMessageRendererRegistry.Environment) {
        self.environment = environment
    }

    func makeView() -> NSView {
        let root = NSView()
        header.translatesAutoresizingMaskIntoConstraints = false
        root.addSubview(header)
        header.topAnchor.constraint(equalTo: root.topAnchor, constant: 4).isActive = true
        header.leadingAnchor.constraint(equalTo: root.leadingAnchor).isActive = true
        header.trailingAnchor.constraint(lessThanOrEqualTo: root.trailingAnchor).isActive = true
        return root
    }

    func configure(view: NSView, row: AppKitMessageRow) {
        let container: AppKitMarkdownBlockContainerView
        if let existing = view.subviews.compactMap({ $0 as? AppKitMarkdownBlockContainerView }).first {
            container = existing
        } else {
            container = AppKitMarkdownBlockContainerView(
                mermaidCache: environment.mermaidCache,
                outerScrollView: environment.outerScrollView
            )
            container.translatesAutoresizingMaskIntoConstraints = false
            view.addSubview(container)
            container.topAnchor.constraint(equalTo: view.subviews[0].bottomAnchor, constant: 2).isActive = true
            container.leadingAnchor.constraint(equalTo: view.leadingAnchor, constant: 12).isActive = true
            container.trailingAnchor.constraint(equalTo: view.trailingAnchor, constant: -12).isActive = true
            container.bottomAnchor.constraint(lessThanOrEqualTo: view.bottomAnchor).isActive = true
        }

        container.onOpenLink = { [weak self] url in
            NSWorkspace.shared.open(url)
        }
        container.onCopyCode = { [weak self] code in
            NSPasteboard.general.clearContents()
            NSPasteboard.general.setString(code, forType: .string)
        }

        header.configure(message: row.message)
        header.isHidden = row.kind == .streaming

        let document = environment.layoutCache.document(for: row.content)
        container.configure(document: document, width: effectiveWidth(in: view), theme: environment.theme)
    }

    func prepareForReuse(view: NSView) {
        for subview in view.subviews {
            if let container = subview as? AppKitMarkdownBlockContainerView {
                container.subviews.forEach { $0.removeFromSuperview() }
            }
            if let header = subview as? AppKitMessageHeaderView {
                header.prepareForReuse()
            }
        }
    }

    func measure(row: AppKitMessageRow, width: CGFloat) -> CGFloat {
        let document = environment.layoutCache.document(for: row.content)
        let key = AppKitRowLayoutKey(
            rowID: row.id,
            contentHash: document.contentHash,
            availableWidth: width,
            scale: NSScreen.main?.backingScaleFactor ?? 2,
            themeRevision: environment.theme.revision,
            verbosity: "default"
        )
        return environment.layoutCache.height(for: key) {
            let body = AppKitMarkdownBlockContainerView.measureHeight(
                document: document, width: width, theme: environment.theme
            )
            return (row.kind == .streaming ? 0 : AppKitMessageHeaderView.headerHeight) + 6 + body
        }
    }

    private func effectiveWidth(in view: NSView) -> CGFloat {
        max(80, view.bounds.width - 24)
    }
}
