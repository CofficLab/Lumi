import AppKit
import SwiftUI

public struct ChatInputEditorView: NSViewRepresentable {
    public static let minHeight: CGFloat = 64
    public static let maxHeight: CGFloat = 300

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

        let textChanged = textView.string != text
        if textChanged {
            textView.delegate = nil
            textView.string = text
            textView.delegate = context.coordinator
        }

        // 仅在 cursorPosition binding 真正变化（程序化移动光标，如点击命令建议补全）
        // 或 text 变化（程序化设置文本后需恢复光标）时同步光标。
        //
        // 关键：流式输出期间 updateNSView 会被高频触发（ChatService.revision 每 token
        // 自增，经 coordinator 转发导致 composer 重渲染）。此时 text 和 cursorPosition
        // 都没变，但用户可能已用键盘把光标移到文本中间——若每次都比较 textView 当前选区
        // 与 binding 值并强制 setSelectedRange，会把用户光标拉回旧位置（通常在末尾）。
        // 用 lastSyncedCursorPosition 记录上次同步值，只有它变了才同步，避免覆盖用户操作。
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
}

extension ChatInputEditorView {
    public final class Coordinator: NSObject, NSTextViewDelegate {
        var parent: ChatInputEditorView
        /// 记录上次通过 updateNSView 同步给 textView 的 cursorPosition。
        /// 用于判断 binding 是否真正变化，避免流式期间高频 updateNSView 覆盖用户的手动光标移动。
        var lastSyncedCursorPosition: Int?

        init(_ parent: ChatInputEditorView) {
            self.parent = parent
        }

        public func textDidChange(_ notification: Notification) {
            guard let textView = notification.object as? NSTextView else { return }
            parent.text = textView.string

            let utf16Location = textView.selectedRange().location
            let swiftLocation = ChatInputEditorRules.utf16ToSwiftIndex(utf16Location, in: textView.string)
            if parent.cursorPosition != swiftLocation {
                parent.cursorPosition = swiftLocation
            }
            // 用户输入后光标位置已由 textView 自己管理，同步记录避免下次 updateNSView 冗余刷新
            lastSyncedCursorPosition = swiftLocation

            parent.updateHeight(for: textView)
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

final class EditorTextView: NSTextView {
    var imageDragHoverHandler: ((Bool) -> Void)?
    var keyDownHandler: ((NSEvent) -> Bool)?
    var fileDropHandler: ((URL) -> Void)?

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
        return super.draggingEntered(sender)
    }

    override func draggingUpdated(_ sender: NSDraggingInfo) -> NSDragOperation {
        if draggingInfoContainsChatImageFile(sender) {
            imageDragHoverHandler?(true)
            return .copy
        }
        imageDragHoverHandler?(false)
        return super.draggingUpdated(sender)
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
}
