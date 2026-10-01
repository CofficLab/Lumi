import AppKit
import os
import SwiftUI

#if DEBUG
private let chatInputPerformanceLog = OSLog(
    subsystem: "com.coffic.lumi",
    category: "conversation-input-performance"
)
#endif

/// 聊天输入编辑器视图
public struct ChatInputEditorView: NSViewRepresentable {
    public static let minHeight: CGFloat = 64
    public static let maxHeight: CGFloat = 300
    public static let collapsedPasteThreshold = 1200
    static let placeholderLabelTag = 18_013

    @Binding private var text: String
    @Binding private var height: CGFloat
    @Binding private var isFocused: Bool
    @Binding private var cursorPosition: Int
    @Binding private var isImageDragHovering: Bool

    private let font: NSFont
    private let textColor: NSColor
    private let placeholder: String
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
        placeholder: String = "",
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
        self.placeholder = placeholder
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
        let scrollView = ChatInputScrollView()
        scrollView.drawsBackground = false
        scrollView.borderType = .noBorder
        scrollView.hasVerticalScroller = false
        scrollView.hasHorizontalScroller = false
        scrollView.autohidesScrollers = true

        let textView = EditorTextView()
        textView.autoresizingMask = [.width]
        textView.delegate = context.coordinator
        textView.keyDownHandler = { [weak coordinator = context.coordinator] event in
            coordinator?.handleKeyDown(event, in: textView) ?? false
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
                guard coordinator.isActive else { return }
                if coordinator.parent.isImageDragHovering != hovering {
                    coordinator.parent.isImageDragHovering = hovering
                }
            }
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
        context.coordinator.attach(to: textView)
        scrollView.onContentWidthChange = { [weak coordinator = context.coordinator, weak textView] width in
            guard let coordinator, let textView, coordinator.accepts(textView) else { return }
            textView.textContainer?.containerSize = NSSize(
                width: width,
                height: CGFloat.greatestFiniteMagnitude
            )
            coordinator.scheduleHeightUpdate(for: textView, immediately: true)
        }

        let placeholderLabel = ChatInputPlaceholderLabel(labelWithString: placeholder)
        placeholderLabel.tag = Self.placeholderLabelTag
        placeholderLabel.font = font
        placeholderLabel.textColor = .secondaryLabelColor
        placeholderLabel.isHidden = !textView.string.isEmpty
        placeholderLabel.translatesAutoresizingMaskIntoConstraints = false
        textView.addSubview(placeholderLabel)
        textView.placeholderLabel = placeholderLabel
        NSLayoutConstraint.activate([
            placeholderLabel.leadingAnchor.constraint(equalTo: textView.leadingAnchor, constant: 8),
            placeholderLabel.topAnchor.constraint(equalTo: textView.topAnchor, constant: 7),
        ])

        DispatchQueue.main.async { [weak coordinator = context.coordinator, weak textView] in
            guard let coordinator, let textView, coordinator.accepts(textView) else { return }
            coordinator.updateHeightNow(for: textView)
        }

        return scrollView
    }

    public static func dismantleNSView(_ nsView: NSScrollView, coordinator: Coordinator) {
        coordinator.invalidate()
    }

    public func updateNSView(_ nsView: NSScrollView, context: Context) {
        guard let textView = nsView.documentView as? EditorTextView else { return }

        context.coordinator.updateParent(self)

        if textView.textColor != textColor {
            textView.textColor = textColor
            textView.insertionPointColor = textColor
        }

        if textView.hasMarkedText() || textView.isIMEComposing {
            updatePlaceholder(for: textView)
            return
        }

        let currentText = resolvedText(from: textView)
        let textChanged = currentText != text
        if textChanged {
            textView.delegate = nil
            textView.hasPastePreviewAttachments = false
            textView.string = text
            textView.delegate = context.coordinator
        }

        updatePlaceholder(for: textView)

        let cursorBindingChanged = context.coordinator.lastSyncedCursorPosition != cursorPosition
        context.coordinator.lastSyncedCursorPosition = cursorPosition

        if textChanged || cursorBindingChanged {
            let position = ChatInputEditorRules.swiftToUTF16Index(cursorPosition, in: text)
            DispatchQueue.main.async { [weak coordinator = context.coordinator, weak textView] in
                guard let coordinator, let textView, coordinator.accepts(textView) else { return }
                textView.setSelectedRange(NSRange(location: position, length: 0))
            }
            if textChanged {
                context.coordinator.scheduleHeightUpdate(for: textView, immediately: true)
            }
        }
    }

    public func makeCoordinator() -> Coordinator {
        Coordinator(self)
    }

    private func updatePlaceholder(for textView: NSTextView) {
        guard let placeholderLabel = textView.viewWithTag(Self.placeholderLabelTag) as? NSTextField else {
            return
        }
        placeholderLabel.stringValue = placeholder
        if let editorTextView = textView as? EditorTextView {
            editorTextView.updatePlaceholderVisibility()
            return
        }
        placeholderLabel.isHidden = !textView.string.isEmpty || textView.hasMarkedText()
    }

    private func updateHeight(for textView: NSTextView, coordinator: Coordinator) {
#if DEBUG
        os_signpost(.event, log: chatInputPerformanceLog, name: "Height Measurement")
#endif
        guard coordinator.accepts(textView),
              let layoutManager = textView.layoutManager,
              let textContainer = textView.textContainer else { return }
        layoutManager.ensureLayout(for: textContainer)

        let usedRect = layoutManager.usedRect(for: textContainer)
        let insetHeight = textView.textContainerInset.height * 2
        guard let newHeight = Self.measuredHeight(
            usedRectHeight: usedRect.height,
            insetHeight: insetHeight,
            availableWidth: textContainer.containerSize.width
        ) else {
            return
        }
        let contentHeight = usedRect.height + insetHeight

        if let scrollView = textView.enclosingScrollView {
            scrollView.hasVerticalScroller = contentHeight > Self.maxHeight
        }

        if height != newHeight {
            coordinator.scheduleHeightBindingUpdate(newHeight)
        }
    }

    private func resolvedText(from textView: NSTextView) -> String {
        guard let editorTextView = textView as? EditorTextView,
              editorTextView.hasPastePreviewAttachments,
              let textStorage = textView.textStorage,
              textStorage.length > 0 else {
            return textView.string
        }

        let fullRange = NSRange(location: 0, length: textStorage.length)
        var result = String()
        result.reserveCapacity(textStorage.length)
        var foundAttachment = false

        textStorage.enumerateAttributes(in: fullRange, options: []) { attributes, range, _ in
            if let attachment = attributes[.attachment] as? PastePreviewAttachment {
                foundAttachment = true
                result += attachment.originalText
            } else {
                result += textStorage.attributedSubstring(from: range).string
            }
        }

        if !foundAttachment {
            editorTextView.hasPastePreviewAttachments = false
            return textView.string
        }

        return result
    }

    static func measuredHeight(
        usedRectHeight: CGFloat,
        insetHeight: CGFloat,
        availableWidth: CGFloat
    ) -> CGFloat? {
        guard availableWidth.isFinite, availableWidth > 0,
              usedRectHeight.isFinite, insetHeight.isFinite else {
            return nil
        }

        let contentHeight = usedRectHeight + insetHeight
        return min(max(contentHeight, Self.minHeight), Self.maxHeight)
    }
}

private final class ChatInputScrollView: NSScrollView {
    var onContentWidthChange: ((CGFloat) -> Void)?

    private var lastContentWidth: CGFloat?

    override func layout() {
        super.layout()

        let width = contentView.bounds.width
        guard width > 0,
              lastContentWidth.map({ abs($0 - width) > 0.5 }) ?? true else {
            return
        }

        lastContentWidth = width
        onContentWidthChange?(width)
    }
}

extension ChatInputEditorView {
    @MainActor
    public final class Coordinator: NSObject, NSTextViewDelegate {
        var parent: ChatInputEditorView
        var lastSyncedCursorPosition: Int?
        private var pendingHeightWorkItem: DispatchWorkItem?
        private var pendingHeightBindingWorkItem: DispatchWorkItem?
        private var heightScheduleID = UUID()
        private weak var representedTextView: NSTextView?
        private(set) var isActive = true
        private let heightBindingGate = HeightBindingGate()
        private var heightBinding: Binding<CGFloat>

        init(_ parent: ChatInputEditorView) {
            self.parent = parent
            self.heightBinding = parent.$height
        }

        func updateParent(_ parent: ChatInputEditorView) {
            self.parent = parent
            heightBinding = parent.$height
        }

        func attach(to textView: NSTextView) {
            representedTextView = textView
            isActive = true
            heightBindingGate.isActive = true
            heightBindingGate.generation = heightScheduleID
        }

        func accepts(_ textView: NSTextView) -> Bool {
            isActive && representedTextView === textView
        }

        func invalidate() {
            heightBindingGate.isActive = false
            heightBindingGate.generation = UUID()
            guard isActive || pendingHeightWorkItem != nil || pendingHeightBindingWorkItem != nil else { return }
            isActive = false
            representedTextView = nil
            pendingHeightWorkItem?.cancel()
            pendingHeightWorkItem = nil
            pendingHeightBindingWorkItem?.cancel()
            pendingHeightBindingWorkItem = nil
            heightScheduleID = UUID()
        }

        @MainActor
        func scheduleHeightUpdate(for textView: NSTextView, immediately: Bool = false) {
            guard accepts(textView) else { return }
            pendingHeightWorkItem?.cancel()
            pendingHeightBindingWorkItem?.cancel()
            heightScheduleID = UUID()
            heightBindingGate.generation = heightScheduleID
            let scheduleID = heightScheduleID

            guard !textView.hasMarkedText() else {
#if DEBUG
                os_signpost(.event, log: chatInputPerformanceLog, name: "Marked Text Update")
#endif
                return
            }
            if let editorTextView = textView as? EditorTextView,
               editorTextView.isIMEComposing {
#if DEBUG
                os_signpost(.event, log: chatInputPerformanceLog, name: "Marked Text Update")
#endif
                return
            }
            if immediately {
                updateHeightNow(for: textView)
                return
            }

            let workItem = DispatchWorkItem { [weak self, weak textView] in
                guard let self,
                      let textView,
                      self.heightScheduleID == scheduleID else { return }
                self.updateHeightNow(for: textView)
            }
            pendingHeightWorkItem = workItem
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.016, execute: workItem)
        }

        @MainActor
        func updateHeightNow(for textView: NSTextView) {
            guard accepts(textView) else { return }
            parent.updateHeight(for: textView, coordinator: self)
        }

        @MainActor
        func scheduleHeightBindingUpdate(_ height: CGFloat) {
            guard isActive else { return }
            pendingHeightBindingWorkItem?.cancel()
            heightScheduleID = UUID()
            heightBindingGate.generation = heightScheduleID
            let scheduleID = heightScheduleID
            let binding = heightBinding
            let gate = heightBindingGate
            let workItem = DispatchWorkItem { [binding, gate] in
                // Do not access `self.parent` while writing the Binding. SwiftUI can
                // synchronously dismantle this representable as a consequence of
                // the write; keeping the Binding and lifecycle gate independent
                // avoids an overlapping access to the Coordinator's parent value.
                guard gate.isActive, gate.generation == scheduleID else { return }
                binding.wrappedValue = height
            }
            pendingHeightBindingWorkItem = workItem
            DispatchQueue.main.async(execute: workItem)
        }

        public func textDidChange(_ notification: Notification) {
            guard let textView = notification.object as? NSTextView else { return }
            guard accepts(textView) else { return }

            // Marked text is intentionally kept out of the SwiftUI binding,
            // but it still counts as visible editor content for the placeholder.
            parent.updatePlaceholder(for: textView)

            // AppKit sends text changes for every intermediate IME update.
            // Keep marked text and its selection inside NSTextView until the
            // composition is committed; publishing it here would invalidate
            // the whole SwiftUI tree and feed pinyin into the draft state.
            guard !textView.hasMarkedText() else {
#if DEBUG
                os_signpost(.event, log: chatInputPerformanceLog, name: "Marked Text Update")
#endif
                return
            }
            if let editorTextView = textView as? EditorTextView,
               editorTextView.isIMEComposing {
#if DEBUG
                os_signpost(.event, log: chatInputPerformanceLog, name: "Marked Text Update")
#endif
                return
            }

#if DEBUG
            os_signpost(.event, log: chatInputPerformanceLog, name: "Committed Text Publication")
#endif
            publishCommittedText(from: textView)
        }

        @MainActor
        private func publishCommittedText(from textView: NSTextView) {
            parent.text = parent.resolvedText(from: textView)

            let utf16Location = textView.selectedRange().location
            let swiftLocation = ChatInputEditorRules.utf16ToSwiftIndex(utf16Location, in: textView.string)
            if parent.cursorPosition != swiftLocation {
                parent.cursorPosition = swiftLocation
            }
            lastSyncedCursorPosition = swiftLocation

            scheduleHeightUpdate(for: textView)
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
            textView.hasPastePreviewAttachments = true
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
                if !textView.hasMarkedText() {
                    (textView as? EditorTextView)?.finishIMEComposition()
                    publishCommittedText(from: textView)
                }
                return submitFromEnter(in: textView)
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
        func handleKeyDown(_ event: NSEvent, in textView: EditorTextView) -> Bool {
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
            if !textView.hasMarkedText() {
                textView.finishIMEComposition()
                publishCommittedText(from: textView)
            }
            return submitFromEnter(in: textView)
        }

        @MainActor
        func handleFileDrop(_ url: URL) {
            parent.onFileDrop?(url)
        }

        @MainActor
        private func submitFromEnter(in textView: NSTextView) -> Bool {
            if let onEnter = parent.onEnter {
                onEnter()
                return true
            }
            parent.onSubmit()
            return true
        }
    }

    private final class HeightBindingGate {
        var isActive = true
        var generation = UUID()
    }
}

/// Purely visual placeholder that lets clicks reach the editor underneath.
final class ChatInputPlaceholderLabel: NSTextField {
    override func hitTest(_ point: NSPoint) -> NSView? {
        nil
    }
}

// MARK: - EditorTextView

final class EditorTextView: NSTextView {
    var hasPastePreviewAttachments = false
    private(set) var isIMEComposing = false
    weak var placeholderLabel: NSTextField?
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

    override func setMarkedText(
        _ string: Any,
        selectedRange: NSRange,
        replacementRange: NSRange
    ) {
        isIMEComposing = true
        updatePlaceholderVisibility()
        super.setMarkedText(
            string,
            selectedRange: selectedRange,
            replacementRange: replacementRange
        )
    }

    override func unmarkText() {
        super.unmarkText()
        isIMEComposing = false
        updatePlaceholderVisibility()
    }

    func finishIMEComposition() {
        isIMEComposing = false
        updatePlaceholderVisibility()
    }

    func updatePlaceholderVisibility() {
        placeholderLabel?.isHidden = !string.isEmpty || hasMarkedText() || isIMEComposing
    }

    override func insertText(_ insertString: Any, replacementRange: NSRange) {
        // Some input methods commit the candidate through insertText without
        // calling the NSTextView unmarkText override first. Clear our local
        // composition guard at the commit boundary so the following
        // textDidChange publishes the committed draft to InputState.
        isIMEComposing = false
        super.insertText(insertString, replacementRange: replacementRange)
        updatePlaceholderVisibility()
    }

    override func insertText(_ insertString: Any) {
        isIMEComposing = false
        super.insertText(insertString)
        updatePlaceholderVisibility()
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
        if !hasMarkedText() {
            isIMEComposing = false
        }
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
            summaryText: attachment.summaryText
        )
        popover.show(relativeTo: rect, of: self, preferredEdge: .maxY)
        pastePreviewPopover = popover
    }
}

// MARK: - PastePreviewAttachment

/// 折叠后的大段粘贴内容。
///
/// 通过 ``PasteLinkAttachmentCell`` 在正文里绘制成一行内联的「链接样式」chip，
/// 而不是过去那种 392×74 的卡片图片，视觉上只占用一行、随文本一起排版。
final class PastePreviewAttachment: NSTextAttachment {
    let originalText: String
    let characterCount: Int
    let lineCount: Int
    let byteCountText: String

    init(originalText: String) {
        self.originalText = originalText
        self.characterCount = originalText.count
        self.lineCount = Self.lineCount(for: originalText)
        self.byteCountText = ByteCountFormatter.string(
            fromByteCount: Int64(originalText.utf8.count),
            countStyle: .file
        )
        super.init(data: nil, ofType: nil)
        self.attachmentCell = PasteLinkAttachmentCell(
            title: Self.chipTitle(characterCount: characterCount, lineCount: lineCount)
        )
    }

    @available(*, unavailable)
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    /// 预览弹窗里展示的完整摘要。
    var summaryText: String {
        "\(Self.countText(characterCount)) · \(Self.lineText(lineCount)) · \(byteCountText)"
    }

    /// 内联 chip 上显示的一行文案，例如「粘贴的文本 · 12,480 字 · 312 行」。
    static func chipTitle(characterCount: Int, lineCount: Int) -> String {
        [
            LumiPluginLocalization.string("Pasted text", bundle: .module),
            countText(characterCount),
            lineText(lineCount)
        ].joined(separator: " · ")
    }

    static func countText(_ count: Int) -> String {
        String(
            format: LumiPluginLocalization.string("%@ chars", bundle: .module),
            Self.decimalNumber(count)
        )
    }

    static func lineText(_ count: Int) -> String {
        String(
            format: LumiPluginLocalization.string("%@ lines", bundle: .module),
            Self.decimalNumber(count)
        )
    }

    private static func decimalNumber(_ value: Int) -> String {
        NumberFormatter.localizedString(from: NSNumber(value: value), number: .decimal)
    }

    private static func lineCount(for text: String) -> Int {
        let normalized = text.replacingOccurrences(of: "\r\n", with: "\n").replacingOccurrences(of: "\r", with: "\n")
        return max(1, normalized.split(separator: "\n", omittingEmptySubsequences: false).count)
    }
}

// MARK: - PasteLinkAttachmentCell

/// 把折叠的大段粘贴绘制成一行「链接样式」的内联 chip。
///
/// chip 跟随正文基线排版，只占一行，包含一个图标和一行摘要文字，外观接近一段
/// 可点击的文本链接（accent 色 + 下划线），而不是过去那种独立的卡片图片。
/// 宽度在初始化时按文本测量并缓存，避免布局阶段反复测量字符串。
final class PasteLinkAttachmentCell: NSTextAttachmentCell {
    private static let titleFont = NSFont.systemFont(ofSize: 12, weight: .medium)
    private static let symbolPointSize: CGFloat = 10
    private static let symbolName = "doc.on.clipboard"
    private static let leadingPadding: CGFloat = 1
    private static let trailingPadding: CGFloat = 2
    private static let iconSize: CGFloat = 12
    private static let iconTitleSpacing: CGFloat = 4
    private static let maximumWidth: CGFloat = 320
    private static let chipHeight: CGFloat = 18
    private static let baselineOffset: CGFloat = -4

    private static var titleAttributes: [NSAttributedString.Key: Any] {
        [
            .font: titleFont,
            .foregroundColor: NSColor.controlAccentColor,
            .underlineStyle: NSUnderlineStyle.single.rawValue,
            .underlineColor: NSColor.controlAccentColor
        ]
    }

    private let chipTitle: String
    private let chipTitleWidth: CGFloat

    init(title: String) {
        self.chipTitle = title
        let measured = ceil((title as NSString).size(withAttributes: Self.titleAttributes).width)
        let maximum = Self.maximumWidth
            - Self.leadingPadding
            - Self.trailingPadding
            - Self.iconSize
            - Self.iconTitleSpacing
        self.chipTitleWidth = min(measured, maximum)
        super.init()
    }

    @available(*, unavailable)
    required init(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    override func cellSize() -> NSSize {
        NSSize(
            width: Self.leadingPadding + Self.iconSize + Self.iconTitleSpacing + chipTitleWidth + Self.trailingPadding,
            height: Self.chipHeight
        )
    }

    override func cellBaselineOffset() -> NSPoint {
        NSPoint(x: 0, y: Self.baselineOffset)
    }

    override func draw(withFrame cellFrame: NSRect, in controlView: NSView?) {
        var cursorX = cellFrame.minX + Self.leadingPadding
        if let symbol = Self.symbolImage() {
            let iconRect = NSRect(
                x: cursorX,
                y: cellFrame.midY - Self.iconSize / 2,
                width: Self.iconSize,
                height: Self.iconSize
            )
            symbol.draw(in: iconRect)
            cursorX = iconRect.maxX + Self.iconTitleSpacing
        }

        let lineHeight = ceil(Self.titleFont.ascender - Self.titleFont.descender)
        let titleRect = NSRect(
            x: cursorX,
            y: cellFrame.midY - lineHeight / 2,
            width: max(0, cellFrame.maxX - Self.trailingPadding - cursorX),
            height: lineHeight
        )

        let paragraph = NSMutableParagraphStyle()
        paragraph.lineBreakMode = .byTruncatingTail
        var attributes = Self.titleAttributes
        attributes[.paragraphStyle] = paragraph
        (chipTitle as NSString).draw(in: titleRect, withAttributes: attributes)
    }

    private static func symbolImage() -> NSImage? {
        guard let symbol = NSImage(systemSymbolName: symbolName, accessibilityDescription: nil) else {
            return nil
        }
        let configuration = NSImage.SymbolConfiguration(pointSize: symbolPointSize, weight: .semibold)
            .applying(NSImage.SymbolConfiguration(paletteColors: [.controlAccentColor]))
        return symbol.withSymbolConfiguration(configuration)
    }
}

// MARK: - PastePreviewPopoverViewController

final class PastePreviewPopoverViewController: NSViewController {
    private let text: String
    private let summaryText: String
    private weak var copyButton: NSButton?
    private var copyFeedbackResetItem: DispatchWorkItem?

    init(text: String, summaryText: String) {
        self.text = text
        self.summaryText = summaryText
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

        let titleLabel = NSTextField(
            labelWithString: LumiPluginLocalization.string("Pasted text", bundle: .module)
        )
        titleLabel.font = .systemFont(ofSize: 13, weight: .semibold)
        titleLabel.textColor = .labelColor

        let detailLabel = NSTextField(labelWithString: summaryText)
        detailLabel.font = .monospacedSystemFont(ofSize: 11, weight: .medium)
        detailLabel.textColor = .secondaryLabelColor

        titleStack.addArrangedSubview(titleLabel)
        titleStack.addArrangedSubview(detailLabel)

        let spacer = NSView()
        spacer.translatesAutoresizingMaskIntoConstraints = false
        spacer.setContentHuggingPriority(.defaultLow, for: .horizontal)

        let copyButton = NSButton(title: LumiPluginLocalization.string("Copy original", bundle: .module), target: self, action: #selector(copyOriginalText))
        copyButton.bezelStyle = .rounded
        copyButton.translatesAutoresizingMaskIntoConstraints = false
        let closeButton = NSButton(title: LumiPluginLocalization.string("Close", bundle: .module), target: self, action: #selector(closePopover))
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
