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
final class HTMLPreviewElementContextMenuSession {
    let items: [HTMLPreviewElementContextMenuItem]
    private(set) var didSelect = false
    private var onSelect: ((HTMLPreviewElementReference) -> Void)?
    private var onCancel: (() -> Void)?
    private var didFinish = false

    init(
        items: [HTMLPreviewElementContextMenuItem],
        onSelect: @escaping (HTMLPreviewElementReference) -> Void,
        onCancel: @escaping () -> Void
    ) {
        self.items = items
        self.onSelect = onSelect
        self.onCancel = onCancel
    }

    func select(at index: Int) {
        guard !didFinish,
              items.indices.contains(index),
              items[index].isEnabled else { return }
        didSelect = true
        onSelect?(items[index].reference)
    }

    func finish() {
        guard !didFinish else { return }
        didFinish = true
        if !didSelect { onCancel?() }
        onSelect = nil
        onCancel = nil
    }
}

enum HTMLPreviewElementContextMenuGeometry {
    static func presentationPoint(
        clientX: Double,
        clientY: Double,
        bounds: NSRect,
        isFlipped: Bool
    ) -> NSPoint {
        NSPoint(
            x: bounds.minX + clientX,
            y: isFlipped ? bounds.minY + clientY : bounds.maxY - clientY
        )
    }
}

@MainActor
final class HTMLPreviewElementContextMenuPresenter: NSObject {
    private var menu: NSMenu?
    private var session: HTMLPreviewElementContextMenuSession?

    func present(
        request: HTMLPreviewContextMenuRequest,
        in webView: WKWebView,
        isEnabled: Bool,
        onSelect: @escaping (HTMLPreviewElementReference) -> Void,
        onCancel: @escaping () -> Void
    ) {
        dismiss()
        let items = HTMLPreviewElementContextMenuModel.items(
            candidates: request.candidates,
            isEnabled: isEnabled
        )
        guard !items.isEmpty else {
            onCancel()
            return
        }

        let session = HTMLPreviewElementContextMenuSession(
            items: items,
            onSelect: onSelect,
            onCancel: onCancel
        )
        self.session = session

        let menu = NSMenu()
        menu.autoenablesItems = false
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
        let didChooseItem = menu.popUp(positioning: nil, at: point, in: webView)

        // AppKit may close the menu before dispatching its target/action. Do not
        // tear down the callbacks from menuDidClose; finish only after tracking
        // returns, and allow one main-run-loop turn if a selection is pending.
        if didChooseItem, !session.didSelect {
            DispatchQueue.main.async { [weak self, weak menu, weak session] in
                guard let self, let menu, let session else { return }
                self.finish(session: session, menu: menu)
            }
        } else {
            finish(session: session, menu: menu)
        }
    }

    func dismiss() {
        guard let menu, let session else { return }
        menu.cancelTracking()
        finish(session: session, menu: menu)
    }

    @objc private func selectItem(_ sender: NSMenuItem) {
        session?.select(at: sender.tag)
    }

    private func finish(
        session: HTMLPreviewElementContextMenuSession,
        menu: NSMenu
    ) {
        guard self.session === session, self.menu === menu else { return }
        session.finish()
        self.menu = nil
        self.session = nil
    }

    private func presentationPoint(
        for request: HTMLPreviewContextMenuRequest,
        in webView: WKWebView
    ) -> NSPoint {
        let candidate = HTMLPreviewElementContextMenuGeometry.presentationPoint(
            clientX: request.clientX,
            clientY: request.clientY,
            bounds: webView.bounds,
            isFlipped: webView.isFlipped
        )
        if webView.bounds.insetBy(dx: -2, dy: -2).contains(candidate) {
            return candidate
        }
        guard let window = webView.window else { return candidate }
        let windowPoint = window.convertPoint(fromScreen: NSEvent.mouseLocation)
        return webView.convert(windowPoint, from: nil)
    }
}
