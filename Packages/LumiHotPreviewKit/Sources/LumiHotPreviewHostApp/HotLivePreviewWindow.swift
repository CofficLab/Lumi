import AppKit

@MainActor
final class HotLivePreviewWindow: NSPanel {
    private static let previewCornerRadius: CGFloat = 6

    init(contentRect: NSRect) {
        super.init(
            contentRect: contentRect,
            styleMask: [.borderless, .nonactivatingPanel],
            backing: .buffered,
            defer: false
        )

        isReleasedWhenClosed = false
        backgroundColor = .clear
        ignoresMouseEvents = false
        hasShadow = false
        level = .normal
        isFloatingPanel = false
        hidesOnDeactivate = false
        collectionBehavior = [.fullScreenAuxiliary]
        isOpaque = false
        becomesKeyOnlyIfNeeded = true
    }

    override var contentView: NSView? {
        didSet {
            configureContentView()
        }
    }

    override var canBecomeMain: Bool { false }
    override var canBecomeKey: Bool { true }

    override func addChildWindow(_ childWin: NSWindow, ordered place: NSWindow.OrderingMode) {
        configureAuxiliaryWindow(childWin)
        super.addChildWindow(childWin, ordered: place)
    }

    override func orderFront(_ sender: Any?) {
        normalizeAuxiliaryWindows()
        super.orderFront(sender)
    }

    override func orderOut(_ sender: Any?) {
        hideAuxiliaryWindows(sender)
        super.orderOut(sender)
    }

    override func close() {
        hideAuxiliaryWindows(nil)
        super.close()
    }

    override func performKeyEquivalent(with event: NSEvent) -> Bool {
        if event.modifierFlags.contains(.command) {
            return false
        }
        return super.performKeyEquivalent(with: event)
    }

    private func configureContentView() {
        guard let contentView else { return }
        contentView.wantsLayer = true
        contentView.layer?.cornerRadius = Self.previewCornerRadius
        contentView.layer?.masksToBounds = true
        contentView.layer?.backgroundColor = NSColor.clear.cgColor
    }

    private func normalizeAuxiliaryWindows() {
        if let attachedSheet {
            configureAuxiliaryWindow(attachedSheet)
        }
        childWindows?.forEach(configureAuxiliaryWindow)
    }

    private func configureAuxiliaryWindow(_ window: NSWindow) {
        window.level = level
        window.collectionBehavior = window.collectionBehavior.union([.fullScreenAuxiliary])
    }

    private func hideAuxiliaryWindows(_ sender: Any?) {
        attachedSheet?.orderOut(sender)
        childWindows?.forEach { $0.orderOut(sender) }
    }
}
