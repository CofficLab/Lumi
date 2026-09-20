import AppKit
import Foundation
import WebKit

struct HTMLPreviewElementContextMenuItem: Equatable {
    let title: String
    let displayLabel: String
    let systemImage: String
    let isEnabled: Bool
    let reference: HTMLPreviewElementReference
}

enum HTMLPreviewElementContextMenuModel {
    static func items(
        candidates: [HTMLPreviewElementReference],
        isEnabled: Bool,
        locale: Locale = .current
    ) -> [HTMLPreviewElementContextMenuItem] {
        items(
            candidates: candidates,
            isEnabled: isEnabled,
            locale: locale,
            localize: { localized($0, locale: locale) }
        )
    }

    static func items(
        candidates: [HTMLPreviewElementReference],
        isEnabled: Bool,
        locale: Locale,
        localize: (String) -> String
    ) -> [HTMLPreviewElementContextMenuItem] {
        guard let first = candidates.first else { return [] }
        guard isEnabled else {
            return [HTMLPreviewElementContextMenuItem(
                title: localize("Conversation Unavailable"),
                displayLabel: truncatedLabel(first.label),
                systemImage: "text.bubble",
                isEnabled: false,
                reference: first
            )]
        }

        let labelCounts = Dictionary(grouping: candidates, by: { $0.label.lowercased() })
            .mapValues(\.count)
        return candidates.enumerated().map { index, reference in
            let displayLabel = truncatedLabel(reference.label)
            let needsQualifier = labelCounts[reference.label.lowercased(), default: 0] > 1
            let qualifier = reference.blockID ?? reference.tagName
            let menuLabel = needsQualifier ? "\(displayLabel) · \(qualifier)" : displayLabel
            let key = index == 0 ? "Send “%@” to Conversation" : "Send Parent “%@” to Conversation"
            let template = localize(key)
            return HTMLPreviewElementContextMenuItem(
                title: String(format: template, locale: locale, arguments: [menuLabel]),
                displayLabel: displayLabel,
                systemImage: index == 0 ? "text.bubble" : "square.dashed.inset.filled",
                isEnabled: true,
                reference: reference
            )
        }
    }

    private static func truncatedLabel(_ label: String) -> String {
        guard label.count > 48 else { return label }
        return String(label.prefix(47)) + "…"
    }

    private static func localized(_ key: String, locale: Locale) -> String {
        KitHTMLPreviewLocalization.string(key, bundle: .module, locale: locale)
    }
}

@MainActor
final class HTMLPreviewElementContextMenuPresenter: NSObject, NSMenuDelegate {
    private var menu: NSMenu?
    private var items: [HTMLPreviewElementContextMenuItem] = []
    private var onSelect: ((HTMLPreviewElementReference) -> Void)?
    private var onCancel: (() -> Void)?
    private var didSelect = false

    func present(
        request: HTMLPreviewContextMenuRequest,
        in webView: WKWebView,
        isEnabled: Bool,
        onSelect: @escaping (HTMLPreviewElementReference) -> Void,
        onCancel: @escaping () -> Void
    ) {
        dismiss()
        items = HTMLPreviewElementContextMenuModel.items(
            candidates: request.candidates,
            isEnabled: isEnabled
        )
        guard !items.isEmpty else {
            onCancel()
            return
        }

        self.onSelect = onSelect
        self.onCancel = onCancel
        didSelect = false

        let menu = NSMenu()
        menu.autoenablesItems = false
        menu.delegate = self
        for (index, itemModel) in items.enumerated() {
            if index == 1 { menu.addItem(.separator()) }
            let item = NSMenuItem(
                title: itemModel.title,
                action: #selector(selectItem(_:)),
                keyEquivalent: ""
            )
            item.target = self
            item.tag = index
            item.isEnabled = itemModel.isEnabled
            item.image = NSImage(
                systemSymbolName: itemModel.systemImage,
                accessibilityDescription: nil
            )
            menu.addItem(item)
        }
        self.menu = menu

        let point = presentationPoint(for: request, in: webView)
        menu.popUp(positioning: nil, at: point, in: webView)
    }

    func dismiss() {
        guard let menu else { return }
        menu.cancelTracking()
        finishIfNeeded()
    }

    func menuDidClose(_ menu: NSMenu) {
        finishIfNeeded()
    }

    @objc private func selectItem(_ sender: NSMenuItem) {
        guard items.indices.contains(sender.tag), items[sender.tag].isEnabled else { return }
        didSelect = true
        let reference = items[sender.tag].reference
        onSelect?(reference)
    }

    private func finishIfNeeded() {
        if !didSelect { onCancel?() }
        menu = nil
        items = []
        onSelect = nil
        onCancel = nil
        didSelect = false
    }

    private func presentationPoint(
        for request: HTMLPreviewContextMenuRequest,
        in webView: WKWebView
    ) -> NSPoint {
        let candidate = NSPoint(x: request.clientX, y: webView.bounds.height - request.clientY)
        if webView.bounds.insetBy(dx: -2, dy: -2).contains(candidate) {
            return candidate
        }
        guard let window = webView.window else { return candidate }
        let windowPoint = window.convertPoint(fromScreen: NSEvent.mouseLocation)
        return webView.convert(windowPoint, from: nil)
    }
}
