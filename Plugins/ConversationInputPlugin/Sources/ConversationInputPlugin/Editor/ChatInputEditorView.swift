import AppKit
import SwiftUI

/// 聊天输入编辑器视图
public struct ChatInputEditorView: NSViewRepresentable {
    public static let minHeight: CGFloat = 64
    public static let maxHeight: CGFloat = 300
    public static let collapsedPasteThreshold = 1200

    @Binding private var text: String
    @Binding private var height: CGFloat
    @Binding private var isFocused: Bool
    @Binding private var cursorPosition: Int
    @Binding private var isImageDragHovering: Bool

    private let font: NSFont
    private let textColor: NSColor
    private let isVerbose: Bool
    private let log: (String) -> Void
    private let onSubmit: () -> Void
    private let onArrowUp: (() -> Void)?
    private let onArrowDown: (() -> Void)?
    private let onEnter: (() -> Void)?
    private let onEscape: (() -> Void)?
    private let onFileDrop: ((URL) -> Void)?

    public init(
        text: Binding<String>,
        height: Binding<CGFloat>,
        font: NSFont = .systemFont(ofSize: 15),
        textColor: NSColor = .textColor,
        isVerbose: Bool = false,
        log: @escaping (String) -> Void = { _ in },
        onSubmit: @escaping () -> Void,
        onArrowUp: (() -> Void)? = nil,
        onArrowDown: (() -> Void)? = nil,
        onEnter: (() -> Void)? = nil,
        onEscape: (() -> Void)? = nil,
        onFileDrop: ((URL) -> Void)? = nil,
        isFocused: Binding<Bool>,
        cursorPosition: Binding<Int>,
        isImageDragHovering: Binding<Bool>
    ) {
        self._text = text
        self._height = height
        self._isFocused = isFocused
        self._cursorPosition = cursorPosition
        self._isImageDragHovering = isImageDragHovering
        self.font = font
        self.textColor = textColor
        self.isVerbose = isVerbose
        self.log = log
        self.onSubmit = onSubmit
        self.onArrowUp = onArrowUp
        self.onArrowDown = onArrowDown
        self.onEnter = onEnter
        self.onEscape = onEscape
        self.onFileDrop = onFileDrop
    }

    public func makeNSView(context: Context) -> NSScrollView {
        let scrollView = NSScrollView()
        scrollView.drawsBackground = false
        scrollView.borderType = .noBorder
        scrollView.hasVerticalScroller = false
        scrollView.hasHorizontalScroller = false
        scrollView.autohidesScrollers = true

        let textView = EditorTextView()
        textView.autoresizingMask = [.width]
        textView.delegate = context.coordinator
        textView.keyDownHandler = { [weak coordinator = context.coordinator] event in
            coordinator?.handleKeyDown(event) ?? false
        }
        textView.pasteHandler = { [weak coordinator = context.coordinator, weak textView] pasteboard in
            guard let coordinator, let textView else { return false }
            return coordinator.handlePaste(pasteboard, in: textView)
        }
        textView.fileDropHandler = { [weak coordinator = context.coordinator] url in
            coordinator?.handleFileDrop(url)
        }
        textView.drawsBackground = false
        textView.font = font
        textView.isRichText = false
        textView.isAutomaticQuoteSubstitutionEnabled = false
        textView.isAutomaticDashSubstitutionEnabled = false
        textView.isVerticallyResizable = true
        textView.isHorizontallyResizable = false
        textView.allowsUndo = true
        textView.textColor = textColor
        textView.insertionPointColor = textColor
        textView.textContainer?.widthTracksTextView = true
        textView.textContainer?.containerSize = NSSize(
            width: scrollView.contentSize.width,
            height: CGFloat.greatestFiniteMagnitude
        )
        textView.textContainerInset = NSSize(width: 4, height: 4)

        scrollView.documentView = textView

        DispatchQueue.main.async {
            updateHeight(for: textView)
        }

        return scrollView
    }

    public func updateNSView(_ nsView: NSScrollView, context: Context) {
        guard let textView = nsView.documentView as? EditorTextView else { return }

        context.coordinator.parent = self
        textView.delegate = context.coordinator
        textView.keyDownHandler = { [weak coordinator = context.coordinator] event in
            coordinator?.handleKeyDown(event) ?? false
        }
        textView.pasteHandler = { [weak coordinator = context.coordinator, weak textView] pasteboard in
            guard let coordinator, let textView else { return false }
            return coordinator.handlePaste(pasteboard, in: textView)
        }
        textView.fileDropHandler = { [weak coordinator = context.coordinator] url in
            coordinator?.handleFileDrop(url)
        }
        textView.imageDragHoverHandler = { [weak coordinator = context.coordinator] hovering in
            guard let coordinator else { return }
            DispatchQueue.main.async {
                if coordinator.parent.isImageDragHovering != hovering {
                    coordinator.parent.isImageDragHovering = hovering
                }
            }
        }

        if textView.textColor != textColor {
            textView.textColor = textColor
            textView.insertionPointColor = textColor
        }

        if textView.hasMarkedText() {
            return
        }

        let currentText = resolvedText(from: textView)
        let textChanged = currentText != text
        if textChanged {
            textView.delegate = nil
            textView.string = text
            textView.delegate = context.coordinator
        }

        let cursorBindingChanged = context.coordinator.lastSyncedCursorPosition != cursorPosition
        context.coordinator.lastSyncedCursorPosition = cursorPosition

        if textChanged || cursorBindingChanged {
            let position = ChatInputEditorRules.swiftToUTF16Index(cursorPosition, in: text)
            DispatchQueue.main.async {
                if textChanged, let tv = nsView.documentView as? EditorTextView {
                    updateHeight(for: tv)
                }
                if let tv = nsView.documentView as? EditorTextView {
                    tv.setSelectedRange(NSRange(location: position, length: 0))
                }
            }
        }
    }

    public func makeCoordinator() -> Coordinator {
        Coordinator(self)
    }

    private func updateHeight(for textView: NSTextView) {
        let layoutManager = textView.layoutManager!
        let textContainer = textView.textContainer!
        layoutManager.ensureLayout(for: textContainer)

        let usedRect = layoutManager.usedRect(for: textContainer)
        let insetHeight = textView.textContainerInset.height * 2
        let contentHeight = usedRect.height + insetHeight
        let newHeight = min(max(contentHeight, Self.minHeight), Self.maxHeight)

        if let scrollView = textView.enclosingScrollView {
            scrollView.hasVerticalScroller = contentHeight > Self.maxHeight
        }

        if height != newHeight {
            DispatchQueue.main.async {
                self.height = newHeight
            }
        }
    }

    private func resolvedText(from textView: NSTextView) -> String {
        guard let textStorage = textView.textStorage, textStorage.length > 0 else {
            return textView.string
        }

        let fullRange = NSRange(location: 0, length: textStorage.length)
        var result = String()
        result.reserveCapacity(textStorage.length)

        textStorage.enumerateAttributes(in: fullRange, options: []) { attributes, range, _ in
            if let attachment = attributes[.attachment] as? PastePreviewAttachment {
                result += attachment.originalText
            } else {
                result += textStorage.attributedSubstring(from: range).string
            }
        }

        return result
    }
}

extension ChatInputEditorView {
    public final class Coordinator: NSObject, NSTextViewDelegate {
        var parent: ChatInputEditorView
        var lastSyncedCursorPosition: Int?

        init(_ parent: ChatInputEditorView) {
            self.parent = parent
        }

        public func textDidChange(_ notification: Notification) {
            guard let textView = notification.object as? NSTextView else { return }
            parent.text = parent.resolvedText(from: textView)

            let utf16Location = textView.selectedRange().location
            let swiftLocation = ChatInputEditorRules.utf16ToSwiftIndex(utf16Location, in: textView.string)
            if parent.cursorPosition != swiftLocation {
                parent.cursorPosition = swiftLocation
            }
            lastSyncedCursorPosition = swiftLocation

            parent.updateHeight(for: textView)
        }

        @MainActor
        func handlePaste(_ pasteboard: NSPasteboard, in textView: EditorTextView) -> Bool {
            guard let text = pasteboard.string(forType: .string)?.trimmingCharacters(in: .newlines),
                  !text.isEmpty else {
                return false
            }

            guard text.count >= ChatInputEditorView.collapsedPasteThreshold else {
                return false
            }

            let attachment = PastePreviewAttachment(originalText: text)
            let attributed = NSAttributedString(attachment: attachment)
            textView.insertText(attributed, replacementRange: textView.selectedRange())
            return true
        }

        public func textView(_ textView: NSTextView, doCommandBy commandSelector: Selector) -> Bool {
            if ChatInputEditorRules.isEnterCommand(commandSelector) {
                if let event = NSApp.currentEvent,
                   event.modifierFlags.contains(.shift) || event.modifierFlags.contains(.option)
                {
                    return false
                }
                if parent.isVerbose {
                    parent.log("doCommandBy captured return: \(NSStringFromSelector(commandSelector))")
                }
                return submitFromEnter()
            } else if commandSelector == #selector(NSResponder.moveUp(_:)) {
                if let onArrowUp = parent.onArrowUp {
                    onArrowUp()
                    return true
                }
            } else if commandSelector == #selector(NSResponder.moveDown(_:)) {
                if let onArrowDown = parent.onArrowDown {
                    onArrowDown()
                    return true
                }
            }
            return false
        }

        @MainActor
        func handleKeyDown(_ event: NSEvent) -> Bool {
            if event.keyCode == 53, let onEscape = parent.onEscape {
                onEscape()
                return true
            }

            guard ChatInputEditorRules.shouldHandleReturnKey(
                keyCode: event.keyCode,
                charactersIgnoringModifiers: event.charactersIgnoringModifiers,
                modifierFlags: event.modifierFlags
            ) else {
                return false
            }
            if parent.isVerbose {
                parent.log("keyDown captured return")
            }
            return submitFromEnter()
        }

        @MainActor
        func handleFileDrop(_ url: URL) {
            parent.onFileDrop?(url)
        }

        @MainActor
        private func submitFromEnter() -> Bool {
            if let onEnter = parent.onEnter {
                onEnter()
                return true
            }
            parent.onSubmit()
            return true
        }
    }
}

// MARK: - EditorTextView

final class EditorTextView: NSTextView {
    var pasteHandler: ((NSPasteboard) -> Bool)?
    var imageDragHoverHandler: ((Bool) -> Void)?
    var keyDownHandler: ((NSEvent) -> Bool)?
    var fileDropHandler: ((URL) -> Void)?
    private var pastePreviewPopover: NSPopover?

    override init(frame frameRect: NSRect, textContainer container: NSTextContainer?) {
        super.init(frame: frameRect, textContainer: container)
        registerForDraggedTypes([.fileURL, .string])
    }

    override init(frame frameRect: NSRect) {
        super.init(frame: frameRect)
        registerForDraggedTypes([.fileURL, .string])
    }

    required init?(coder: NSCoder) {
        super.init(coder: coder)
        registerForDraggedTypes([.fileURL, .string])
    }

    override func paste(_ sender: Any?) {
        if pasteHandler?(NSPasteboard.general) == true {
            return
        }
        super.paste(sender)
    }

    override func mouseDown(with event: NSEvent) {
        let point = convert(event.locationInWindow, from: nil)
        if showPastePreviewIfNeeded(at: point) {
            return
        }
        super.mouseDown(with: event)
    }

    override func keyDown(with event: NSEvent) {
        if !hasMarkedText(), keyDownHandler?(event) == true {
            return
        }
        super.keyDown(with: event)
    }

    override func draggingEntered(_ sender: NSDraggingInfo) -> NSDragOperation {
        if draggingInfoContainsChatImageFile(sender) {
            imageDragHoverHandler?(true)
            return .copy
        }
        imageDragHoverHandler?(false)
        return .copy
    }

    override func draggingUpdated(_ sender: NSDraggingInfo) -> NSDragOperation {
        if draggingInfoContainsChatImageFile(sender) {
            imageDragHoverHandler?(true)
            return .copy
        }
        imageDragHoverHandler?(false)
        return .copy
    }

    override func draggingExited(_ sender: NSDraggingInfo?) {
        imageDragHoverHandler?(false)
        super.draggingExited(sender)
    }

    override func concludeDragOperation(_ sender: NSDraggingInfo?) {
        imageDragHoverHandler?(false)
        super.concludeDragOperation(sender)
    }

    override func performDragOperation(_ sender: NSDraggingInfo) -> Bool {
        let pasteboard = sender.draggingPasteboard

        if let urls = pasteboard.readObjects(forClasses: [NSURL.self], options: nil) as? [URL],
           !urls.isEmpty {
            for url in urls {
                fileDropHandler?(url)
            }
            return true
        }

        if let strings = pasteboard.readObjects(forClasses: [NSString.self], options: nil) as? [String] {
            let urls = strings.flatMap(ChatInputEditorRules.fileURLs(fromDroppedString:))
            guard !urls.isEmpty else {
                return super.performDragOperation(sender)
            }
            for url in urls {
                fileDropHandler?(url)
            }
            return true
        }

        return super.performDragOperation(sender)
    }

    private func draggingInfoContainsChatImageFile(_ sender: NSDraggingInfo) -> Bool {
        let pasteboard = sender.draggingPasteboard
        if let urls = pasteboard.readObjects(forClasses: [NSURL.self], options: nil) as? [URL] {
            return urls.contains(where: ChatInputEditorRules.isChatImageFileURL)
        }
        if let strings = pasteboard.readObjects(forClasses: [NSString.self], options: nil) as? [String] {
            return strings
                .flatMap(ChatInputEditorRules.fileURLs(fromDroppedString:))
                .contains(where: ChatInputEditorRules.isChatImageFileURL)
        }
        return false
    }

    private func showPastePreviewIfNeeded(at point: NSPoint) -> Bool {
        guard let textStorage, let layoutManager, let textContainer else {
            return false
        }

        let containerPoint = NSPoint(
            x: point.x - textContainerOrigin.x,
            y: point.y - textContainerOrigin.y
        )
        let charIndex = layoutManager.characterIndex(
            for: containerPoint,
            in: textContainer,
            fractionOfDistanceBetweenInsertionPoints: nil
        )
        guard charIndex < textStorage.length,
              let attachment = textStorage.attribute(.attachment, at: charIndex, effectiveRange: nil) as? PastePreviewAttachment
        else {
            return false
        }

        let glyphRange = layoutManager.glyphRange(
            forCharacterRange: NSRange(location: charIndex, length: 1),
            actualCharacterRange: nil
        )
        let attachmentRect = layoutManager.boundingRect(forGlyphRange: glyphRange, in: textContainer)
            .offsetBy(dx: textContainerOrigin.x, dy: textContainerOrigin.y)

        showPastePreviewPopover(attachment: attachment, from: attachmentRect)
        return true
    }

    private func showPastePreviewPopover(attachment: PastePreviewAttachment, from rect: NSRect) {
        pastePreviewPopover?.performClose(nil)

        let popover = NSPopover()
        popover.behavior = .transient
        popover.contentSize = NSSize(width: 620, height: 460)
        popover.contentViewController = PastePreviewPopoverViewController(
            text: attachment.originalText,
            characterCount: attachment.characterCount,
            lineCount: attachment.lineCount
        )
        popover.show(relativeTo: rect, of: self, preferredEdge: .maxY)
        pastePreviewPopover = popover
    }
}

// MARK: - PastePreviewAttachment

final class PastePreviewAttachment: NSTextAttachment {
    let originalText: String
    let previewText: String
    let summaryText: String
    let lineCount: Int
    let characterCount: Int

    init(originalText: String) {
        self.originalText = originalText
        self.previewText = Self.previewText(for: originalText)
        self.lineCount = Self.lineCount(for: originalText)
        self.characterCount = originalText.count
        self.summaryText = Self.summaryText(for: originalText, lineCount: lineCount, characterCount: characterCount)

        let image = Self.makeImage(
            previewText: previewText,
            summaryText: summaryText
        )

        super.init(data: nil, ofType: nil)
        self.image = image
        self.bounds = CGRect(origin: .zero, size: image.size)
    }

    @available(*, unavailable)
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    private static func previewText(for text: String) -> String {
        let collapsed = text
            .replacingOccurrences(of: "\\s+", with: " ", options: .regularExpression)
            .trimmingCharacters(in: .whitespacesAndNewlines)
        if collapsed.isEmpty {
            return "Empty paste"
        }
        if collapsed.count <= 60 {
            return collapsed
        }
        let prefix = String(collapsed.prefix(60))
        return prefix + "…"
    }

    private static func lineCount(for text: String) -> Int {
        let normalized = text.replacingOccurrences(of: "\r\n", with: "\n").replacingOccurrences(of: "\r", with: "\n")
        return max(1, normalized.split(separator: "\n", omittingEmptySubsequences: false).count)
    }

    private static func summaryText(for text: String, lineCount: Int, characterCount: Int) -> String {
        let sizeText = ByteCountFormatter.string(fromByteCount: Int64(text.utf8.count), countStyle: .file)
        return "\(characterCount) chars · \(lineCount) lines · \(sizeText)"
    }

    private static func makeImage(previewText: String, summaryText: String) -> NSImage {
        let size = NSSize(width: 392, height: 74)
        let image = NSImage(size: size)
        image.lockFocusFlipped(false)
        defer { image.unlockFocus() }

        let rect = NSRect(origin: .zero, size: size)
        let rounded = NSBezierPath(roundedRect: rect.insetBy(dx: 0.5, dy: 0.5), xRadius: 14, yRadius: 14)

        NSColor.controlBackgroundColor.withAlphaComponent(0.96).setFill()
        rounded.fill()

        NSColor.separatorColor.withAlphaComponent(0.65).setStroke()
        rounded.lineWidth = 1
        rounded.stroke()

        let iconRect = NSRect(x: 14, y: 24, width: 24, height: 24)
        if let icon = NSImage(systemSymbolName: "doc.text.fill", accessibilityDescription: nil) {
            icon.isTemplate = true
            icon.draw(in: iconRect)
        }

        let titleAttributes: [NSAttributedString.Key: Any] = [
            .font: NSFont.systemFont(ofSize: 13, weight: .semibold),
            .foregroundColor: NSColor.labelColor
        ]
        let summaryAttributes: [NSAttributedString.Key: Any] = [
            .font: NSFont.monospacedSystemFont(ofSize: 10.5, weight: .medium),
            .foregroundColor: NSColor.secondaryLabelColor
        ]
        let previewAttributes: [NSAttributedString.Key: Any] = [
            .font: NSFont.systemFont(ofSize: 12),
            .foregroundColor: NSColor.secondaryLabelColor
        ]

        ("Large paste" as NSString).draw(
            in: NSRect(x: 48, y: 42, width: 324, height: 16),
            withAttributes: titleAttributes
        )
        ((summaryText + " · click to inspect") as NSString).draw(
            in: NSRect(x: 48, y: 25, width: 324, height: 14),
            withAttributes: summaryAttributes
        )
        (previewText as NSString).draw(
            in: NSRect(x: 48, y: 8, width: 324, height: 14),
            withAttributes: previewAttributes
        )

        return image
    }
}

// MARK: - PastePreviewPopoverViewController

final class PastePreviewPopoverViewController: NSViewController {
    private let text: String
    private let characterCount: Int
    private let lineCount: Int
    private weak var copyButton: NSButton?
    private var copyFeedbackResetItem: DispatchWorkItem?

    init(text: String, characterCount: Int, lineCount: Int) {
        self.text = text
        self.characterCount = characterCount
        self.lineCount = lineCount
        super.init(nibName: nil, bundle: nil)
    }

    @available(*, unavailable)
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    override func loadView() {
        let container = NSView()
        let scrollView = NSScrollView()
        scrollView.drawsBackground = false
        scrollView.hasVerticalScroller = true
        scrollView.hasHorizontalScroller = false
        scrollView.autohidesScrollers = true

        let textView = NSTextView()
        textView.isEditable = false
        textView.isSelectable = true
        textView.isRichText = false
        textView.drawsBackground = false
        textView.font = .monospacedSystemFont(ofSize: 12, weight: .regular)
        textView.textColor = .labelColor
        textView.textContainerInset = NSSize(width: 12, height: 12)
        textView.textContainer?.widthTracksTextView = true
        textView.textContainer?.containerSize = NSSize(width: 560, height: CGFloat.greatestFiniteMagnitude)
        textView.frame = NSRect(x: 0, y: 0, width: 560, height: 360)
        textView.string = text

        scrollView.documentView = textView

        let header = NSStackView()
        header.orientation = .horizontal
        header.alignment = .centerY
        header.distribution = .fill
        header.spacing = 10
        header.translatesAutoresizingMaskIntoConstraints = false
        header.heightAnchor.constraint(equalToConstant: 44).isActive = true

        let titleStack = NSStackView()
        titleStack.orientation = .vertical
        titleStack.alignment = .leading
        titleStack.spacing = 2
        titleStack.translatesAutoresizingMaskIntoConstraints = false

        let titleLabel = NSTextField(labelWithString: "Large paste preview")
        titleLabel.font = .systemFont(ofSize: 13, weight: .semibold)
        titleLabel.textColor = .labelColor

        let detailLabel = NSTextField(labelWithString: "\(characterCount) chars · \(lineCount) lines")
        detailLabel.font = .monospacedSystemFont(ofSize: 11, weight: .medium)
        detailLabel.textColor = .secondaryLabelColor

        titleStack.addArrangedSubview(titleLabel)
        titleStack.addArrangedSubview(detailLabel)

        let spacer = NSView()
        spacer.translatesAutoresizingMaskIntoConstraints = false
        spacer.setContentHuggingPriority(.defaultLow, for: .horizontal)

        let copyButton = NSButton(title: "Copy original", target: self, action: #selector(copyOriginalText))
        copyButton.bezelStyle = .rounded
        copyButton.translatesAutoresizingMaskIntoConstraints = false
        let closeButton = NSButton(title: "Close", target: self, action: #selector(closePopover))
        closeButton.bezelStyle = .rounded
        closeButton.translatesAutoresizingMaskIntoConstraints = false

        header.addArrangedSubview(titleStack)
        header.addArrangedSubview(spacer)
        header.addArrangedSubview(copyButton)
        header.addArrangedSubview(closeButton)
        self.copyButton = copyButton

        let stack = NSStackView(views: [header, scrollView])
        stack.orientation = .vertical
        stack.alignment = .leading
        stack.spacing = 8
        stack.translatesAutoresizingMaskIntoConstraints = false

        container.addSubview(stack)
        NSLayoutConstraint.activate([
            stack.leadingAnchor.constraint(equalTo: container.leadingAnchor),
            stack.trailingAnchor.constraint(equalTo: container.trailingAnchor),
            stack.topAnchor.constraint(equalTo: container.topAnchor),
            stack.bottomAnchor.constraint(equalTo: container.bottomAnchor)
        ])

        view = container
    }

    @objc private func copyOriginalText() {
        NSPasteboard.general.clearContents()
        NSPasteboard.general.setString(text, forType: .string)

        copyButton?.title = "Copied"
        copyButton?.isEnabled = false

        copyFeedbackResetItem?.cancel()
        let resetItem = DispatchWorkItem { [weak self] in
            self?.copyButton?.title = "Copy original"
            self?.copyButton?.isEnabled = true
        }
        copyFeedbackResetItem = resetItem
        DispatchQueue.main.asyncAfter(deadline: .now() + 1.0, execute: resetItem)
    }

    @objc private func closePopover() {
        view.window?.performClose(nil)
    }
}
