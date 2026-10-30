import AppKit
import CoreText
import os
import ProviderMessage
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
    /// chip 配色。由 SwiftUI 层按主题注入，保证与消息列表里的 chip 一致。
    private let chipPalette: PasteChipPalette
    private let log: (String) -> Void
    private let onSubmit: () -> Void
    private let onArrowUp: (() -> Void)?
    private let onArrowDown: (() -> Void)?
    private let onEnter: (() -> Void)?
    private let onEscape: (() -> Void)?
    private let onFileDrop: ((URL) -> Void)?
    /// 编辑器插入完折叠块后的回调，ViewModel 据此清空待插入状态。
    private let onBlockInserted: ((UUID) -> Void)?
    /// 编辑器内容里的折叠块区间变化时回调。
    ///
    /// 区间以「拍平后的正文」为基准（chip 的原文已还原进正文），
    /// ViewModel 据此在发送时把折叠块一起落库，消息列表才能还原成 chip。
    private let onCollapsedBlocksChanged: (([CollapsedContentBlock]) -> Void)?
    /// 待插入输入框的折叠块请求（如编辑器选区发送到对话）。
    /// 消费一次后由 ViewModel 置空，避免重复插入同一个 chip。
    private let pendingBlock: ConversationInputBlockRequest?

    public init(
        text: Binding<String>,
        height: Binding<CGFloat>,
        font: NSFont = .systemFont(ofSize: 15),
        textColor: NSColor = .textColor,
        placeholder: String = "",
        isVerbose: Bool = false,
        chipPalette: PasteChipPalette = .fallback,
        log: @escaping (String) -> Void = { _ in },
        onSubmit: @escaping () -> Void,
        onArrowUp: (() -> Void)? = nil,
        onArrowDown: (() -> Void)? = nil,
        onEnter: (() -> Void)? = nil,
        onEscape: (() -> Void)? = nil,
        onFileDrop: ((URL) -> Void)? = nil,
        onBlockInserted: ((UUID) -> Void)? = nil,
        onCollapsedBlocksChanged: (([CollapsedContentBlock]) -> Void)? = nil,
        isFocused: Binding<Bool>,
        cursorPosition: Binding<Int>,
        isImageDragHovering: Binding<Bool>,
        pendingBlock: ConversationInputBlockRequest? = nil
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
        self.chipPalette = chipPalette
        self.log = log
        self.onSubmit = onSubmit
        self.onArrowUp = onArrowUp
        self.onArrowDown = onArrowDown
        self.onEnter = onEnter
        self.onEscape = onEscape
        self.onFileDrop = onFileDrop
        self.onBlockInserted = onBlockInserted
        self.onCollapsedBlocksChanged = onCollapsedBlocksChanged
        self.pendingBlock = pendingBlock
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
        textView.setAccessibilityIdentifier("lumi.conversation-input.editor")

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

        let resolved = resolvedContent(from: textView)
        let currentText = resolved.text
        let textChanged = currentText != text

        if textChanged, context.coordinator.shouldPublishEditorTextUp(currentText) {
            // 补偿性回写：编辑器里有 binding 尚不知道的内容。
            //
            // 正常输入靠 `textViewDidChange` → `publishCommittedText` 上报。
            // 但不是所有写入都会产生该通知——粘贴、语音输入、以及 UI 测试的
            // `typeText`（一次性合成整段文本）都只改 `textView.string`。
            // 此时 binding 仍是旧值，若按下面的分支把 binding 灌回编辑器，
            // 用户刚输入的内容会被静默清空；即使侥幸没清空，状态层也永远
            // 不知道「输入框有字」，导致发送按钮停在 disabled。
            //
            // 因此这里必须先判断方向：内容若是编辑器侧产生且从未上报过，
            // 就向上写入 binding，而不是向下覆盖编辑器。
            context.coordinator.publishEditorTextUp(currentText, from: textView)
            // 文本未变但折叠块变了（用户删掉了 chip 之外的文字）也要上报，
            // 否则上层会拿着过期的区间发送。
            reportCollapsedBlocks(resolved.blocks)
            updatePlaceholder(for: textView)
            insertPendingBlockIfNeeded(in: textView, context: context)
            // 本轮不回写选区：编辑器刚被外部写入，binding 的 cursorPosition
            // 还是上一次同步的陈旧值，用它恢复选区会把刚输入的末尾字符吃掉
            // （实测 `typeText("ZZVERIFY1")` 后只剩 `ZZVERIFY`）。
            return
        }

        if textChanged {
            textView.delegate = nil
            textView.hasPastePreviewAttachments = false
            textView.string = text
            textView.delegate = context.coordinator
            context.coordinator.noteBindingTextPushedDown(text)
            // 纯文本写回编辑器后，chip 已不存在，区间必须一并清空，
            // 否则发送时会带着早已不存在的区间落库。
            reportCollapsedBlocks([])
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

        insertPendingBlockIfNeeded(in: textView, context: context)
    }

    /// 把外部递交的折叠块插进编辑器。
    ///
    /// 超过块自带的折叠阈值时插入 chip（一行内联按钮），否则按纯文本插入，
    /// 让用户仍能在发送前直接改写短内容。
    private func insertPendingBlockIfNeeded(in textView: EditorTextView, context: Context) {
        guard let block = pendingBlock,
              context.coordinator.lastInsertedBlockID != block.id else {
            return
        }
        context.coordinator.lastInsertedBlockID = block.id
        context.coordinator.insert(block, in: textView)
        onBlockInserted?(block.id)
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
        let measured = Self.measuredHeight(
            usedRectHeight: usedRect.height,
            insetHeight: insetHeight,
            availableWidth: textContainer.containerSize.width
        )
        // `usedRect` 带亚像素误差。这里把高度量化到行数：行数没变就不上报，
        // 避免 `.frame(height:)` 在极小范围内反复变动——该输入框是 bottomFixed
        // 的，每次变动都会让整条消息列表重排。
        let newHeight = Self.stabilizedHeight(measured, previous: height)
        guard let scrollView = textView.enclosingScrollView else { return }
        let contentHeight = usedRect.height + insetHeight

        scrollView.hasVerticalScroller = contentHeight > Self.maxHeight

        if height != newHeight {
            coordinator.scheduleHeightBindingUpdate(newHeight)
        }
    }

    /// 编辑器内容拍平后的结果。
    ///
    /// `text` 是 chip 原文已还原的完整正文（发给上层的正是它）；
    /// `blocks` 记录每个 chip 在该正文中的 Character 区间。
    struct ResolvedEditorContent {
        var text: String
        var blocks: [CollapsedContentBlock]
    }

    /// 拍平编辑器内容，并顺带算出折叠块在拍平正文中的区间。
    ///
    /// 折叠 chip 只是编辑器里的 attachment，本身不携带「我在正文里的位置」。
    /// 若不把区间一并上报，发送后消息里就只剩一长串纯文字——这正是
    /// 「粘贴时是折叠块、发出后却展开成一大段」的根因。
    private func resolvedContent(from textView: NSTextView) -> ResolvedEditorContent {
        guard let editorTextView = textView as? EditorTextView,
              editorTextView.hasPastePreviewAttachments,
              let textStorage = textView.textStorage,
              textStorage.length > 0 else {
            return ResolvedEditorContent(text: textView.string, blocks: [])
        }

        let flattened = Self.flattenedContent(from: textStorage)
        if !flattened.hasAttachments {
            editorTextView.hasPastePreviewAttachments = false
            return ResolvedEditorContent(text: textView.string, blocks: [])
        }
        return ResolvedEditorContent(text: flattened.text, blocks: flattened.blocks)
    }

    /// 把带 chip 的富文本拍平成纯文本，并算出每个 chip 在纯文本中的区间。
    ///
    /// 抽成静态纯函数是为了能脱离 AppKit 视图单独验证：区间算错会让消息
    /// 里的 chip 覆盖到错误的文字上。
    static func flattenedContent(
        from textStorage: NSTextStorage
    ) -> (text: String, blocks: [CollapsedContentBlock], hasAttachments: Bool) {
        let fullRange = NSRange(location: 0, length: textStorage.length)
        var result = String()
        result.reserveCapacity(textStorage.length)
        var blocks: [CollapsedContentBlock] = []
        var foundAttachment = false

        textStorage.enumerateAttributes(in: fullRange, options: []) { attributes, range, _ in
            if let attachment = attributes[.attachment] as? PastePreviewAttachment {
                foundAttachment = true
                // 区间以**已拍平的正文**为基准：`result.count` 是 chip 之前
                // 已累积的 Character 数，正是该 chip 在正文里的起点。
                let start = result.count
                result += attachment.originalText
                blocks.append(CollapsedContentBlock(
                    start: start,
                    length: attachment.originalText.count,
                    title: attachment.chipTitle,
                    systemImage: attachment.systemImage
                ))
            } else {
                result += textStorage.attributedSubstring(from: range).string
            }
        }

        return (result, blocks, foundAttachment)
    }

    private func resolvedText(from textView: NSTextView) -> String {
        resolvedContent(from: textView).text
    }

    /// 把折叠块区间上报给上层。
    func reportCollapsedBlocks(_ blocks: [CollapsedContentBlock]) {
        onCollapsedBlocksChanged?(blocks)
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

    /// 行高。用于把连续的高度值换算成行数。
    ///
    /// 输入框用 15pt 系统字体，单行约 19pt。这里取该值做行数换算即可——
    /// 目的是判断「有没有多一行 / 少一行」，不要求与实际行高完全一致。
    static let nominalLineHeight: CGFloat = 19

    /// 抑制亚像素抖动后再决定是否上报高度。
    ///
    /// - Important: 输入框是 `bottomFixed` 的，`height` binding 一变，SwiftUI
    ///   就改 `.frame(height:)`，整条消息列表随之重排。而 AppKit 的
    ///   `usedRect(for:)` 带亚像素误差：同一行内容下相邻两次测量可能相差零点几个点。
    ///   若原样上报，frame 会在极小范围内反复变动，每个字符都触发一次全区重排。
    ///
    ///   做法是把高度量化到行数再取整：行数没变就沿用上一次高度，行数变了才上报。
    ///
    /// - Parameters:
    ///   - measured: 本次测得的高度；`nil` 表示测量不可用（宽度为 0 的临时布局等）。
    ///   - previous: 上一次已上报的高度。
    ///   - lineHeight: 行高，用于行数换算。
    /// - Returns: 应上报的高度。测量失败时沿用 ``previous``，不把输入框压回最小高度。
    static func stabilizedHeight(
        _ measured: CGFloat?,
        previous: CGFloat,
        lineHeight: CGFloat = nominalLineHeight
    ) -> CGFloat {
        guard let measured, measured.isFinite, lineHeight > 0 else { return previous }

        // 行数一致 → 认为只是亚像素抖动，沿用上一次已上报的值。
        guard Int((measured / lineHeight).rounded(.down)) != Int((previous / lineHeight).rounded(.down))
        else {
            return previous
        }

        return measured
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

// MARK: - ConversationInputBlockRequest

/// 待插入输入框的折叠块请求。
///
/// 与 Provider 层的 `ConversationInputBlock` 内容一致，但在插件内部多一层
/// 传递：ViewModel 把它作为可发布状态交给 SwiftUI，编辑器消费后由
/// ``ChatInputEditorView/Coordinator/lastInsertedBlockID`` 去重，避免同一个块
/// 在后续的 `updateNSView` 中被反复插入。
public struct ConversationInputBlockRequest: Equatable {
    public let id: UUID
    public let text: String
    public let title: String
    public let systemImage: String
    /// 折叠阈值：文本短于此值时按纯文本插入，方便用户直接改写。
    public let collapseThreshold: Int

    public init(
        id: UUID = UUID(),
        text: String,
        title: String,
        systemImage: String,
        collapseThreshold: Int
    ) {
        self.id = id
        self.text = text
        self.title = title
        self.systemImage = systemImage
        self.collapseThreshold = collapseThreshold
    }

    public var shouldCollapse: Bool {
        !text.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
            && text.count >= max(0, collapseThreshold)
    }
}

extension ChatInputEditorView {
    public final class Coordinator: NSObject, NSTextViewDelegate {
        var parent: ChatInputEditorView
        var lastSyncedCursorPosition: Int?
        /// 最近一次已插入的折叠块 ID。用于在多次 `updateNSView` 之间去重。
        var lastInsertedBlockID: UUID?
        /// 最近一次已同步的文本，无论同步方向是「binding → 编辑器」还是
        /// 「编辑器 → binding」。
        ///
        /// `updateNSView` 发现两边不一致时，必须先回答「这个差异是谁造成的」，
        /// 否则就会把方向判反：
        /// - binding 变了（典型：发送后清空草稿）→ 必须下发到编辑器；
        /// - 编辑器变了且 binding 不知情（粘贴、`typeText` 等一次性写入）
        ///   → 必须上报到 binding。
        ///
        /// - Important: 上报路径**必须**也记录在这里。只有「binding → 编辑器」
        ///   的下发被记录时，逐字输入后再发送的场景会被误判成「编辑器有未知
        ///   新内容」，把已清空的草稿又写回 binding，输入框停留在原地。
        private var lastSyncedBindingText: String?
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

        // MARK: - 文本方向判定（binding ⇄ 编辑器）

        /// binding 的文本刚被我们灌进编辑器时，编辑器与 binding「本该一致」。
        /// 此时若仍不相等，说明是绑定侧的后续变更（或编辑器被外部改写后
        /// binding 又动过），应按「binding → 编辑器」处理。
        func noteBindingTextPushedDown(_ text: String) {
            lastSyncedBindingText = text
        }

        /// 编辑器里的差异是否应判定为「编辑器侧变更」并向上发布。
        ///
        /// 仅当差异内容**不是**我们最近一次同步过的文本时才成立。这样区分了两个方向：
        /// - 差异 == 最近同步值 → binding 变了，需要下发（正常路径）
        /// - 差异 != 最近同步值 → 编辑器被写入且 binding 不知情，需要上报
        func shouldPublishEditorTextUp(_ editorText: String) -> Bool {
            if let synced = lastSyncedBindingText {
                // 刚同步过：编辑器和该值不同说明用户/外部又改了，视为编辑器侧变更。
                return editorText != synced
            }
            // 从未同步过：binding 与编辑器的任何差异都来自编辑器侧。
            return true
        }

        /// 把编辑器内容向上发布到 binding。
        ///
        /// - Important: 这里**不**写 `parent.cursorPosition`。本方法只在
        ///   「编辑器已被外部写入、binding 不知情」时调用，此时 binding 的
        ///   `cursorPosition` 仍是上一次同步的值；若把它写回，`updateNSView`
        ///   随后的光标恢复分支会用这个陈旧位置重设选区，把刚输入的末尾字符
        ///   吃掉（实测 `typeText("ZZVERIFY1")` 后只剩 `ZZVERIFY`）。
        ///   编辑器自身的选区已是正确位置，无需干预。
        @MainActor
        func publishEditorTextUp(_ editorText: String, from textView: NSTextView) {
            lastSyncedBindingText = editorText
            parent.text = editorText
            // 补偿性回写同样要带上折叠块区间：粘贴不走 `textViewDidChange`，
            // 只在这里上报，漏掉它就等于粘贴内容永远无法还原成 chip。
            parent.reportCollapsedBlocks(parent.resolvedContent(from: textView).blocks)
            // 只同步「当前光标在文本中的位置」这一事实，不触发选区回写。
            lastSyncedCursorPosition = ChatInputEditorRules.utf16ToSwiftIndex(
                textView.selectedRange().location,
                in: textView.string
            )
            scheduleHeightUpdate(for: textView)
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

        /// 测试入口：走与真实编辑路径完全相同的发布逻辑。
        @MainActor
        func publishCommittedTextForTesting(from textView: NSTextView) {
            publishCommittedText(from: textView)
        }

        @MainActor
        private func publishCommittedText(from textView: NSTextView) {
            let resolved = parent.resolvedContent(from: textView)
            // 记录本次上报：binding 与编辑器就此一致，后续差异才能归因到
            // binding 侧（例如发送后清空草稿）而不是「编辑器有未知内容」。
            lastSyncedBindingText = resolved.text
            parent.text = resolved.text
            // 折叠块区间与文本同源，必须在同一轮里一起上报：只报文本会让
            // 上层拿不到区间，发送后消息就会退化成一大段纯文字。
            parent.reportCollapsedBlocks(resolved.blocks)

            let utf16Location = textView.selectedRange().location
            let swiftLocation = ChatInputEditorRules.utf16ToSwiftIndex(utf16Location, in: textView.string)
            if parent.cursorPosition != swiftLocation {
                parent.cursorPosition = swiftLocation
            }
            lastSyncedCursorPosition = swiftLocation

            scheduleHeightUpdate(for: textView)
        }

        @MainActor
        /// 插入外部递交的折叠块。
        ///
        /// 达到折叠阈值时插入 chip（一行内联按钮），否则按纯文本插入，
        /// 让短内容在发送前仍可直接改写。两条路径都在末尾把光标移到插入点之后。
        func insert(_ block: ConversationInputBlockRequest, in textView: EditorTextView) {
            let insertionRange = textView.selectedRange()

            if block.shouldCollapse {
                let attachment = PastePreviewAttachment(
                    originalText: block.text,
                    title: block.title,
                    systemImage: block.systemImage,
                    font: textView.font,
                    palette: parent.chipPalette
                )
                textView.hasPastePreviewAttachments = true
                textView.insertText(
                    NSAttributedString(attachment: attachment),
                    replacementRange: insertionRange
                )
                // chip 的 hover 依赖 tracking area，立即挂上不等 AppKit 的布局回调。
                textView.syncPasteHoverTracking()
            } else {
                // 已有内容时留一个空行，避免和用户已写的文字黏在一起。
                let separator = insertionRange.location > 0 ? "\n" : ""
                textView.insertText(separator + block.text, replacementRange: insertionRange)
            }

            // insertText 会通过 delegate 发布文本；这里直接同步一次，
            // 让草稿立刻带上新内容，不必等下一轮 SwiftUI 更新。
            publishCommittedText(from: textView)
            scheduleHeightUpdate(for: textView, immediately: true)
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

            let attachment = PastePreviewAttachment(
                originalText: text,
                font: textView.font,
                palette: parent.chipPalette
            )
            let attributed = NSAttributedString(attachment: attachment)
            textView.hasPastePreviewAttachments = true
            textView.insertText(attributed, replacementRange: textView.selectedRange())
            // 折叠按钮的 hover 依赖 tracking area，这里立即挂上，不等 AppKit 的布局回调。
            textView.syncPasteHoverTracking()
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

    /// 当前鼠标悬停的粘贴折叠按钮，供 cell 绘制高亮态时查询。
    private(set) weak var hoveredPasteCell: PasteButtonAttachmentCell?
    private var pasteHoverTrackingArea: NSTrackingArea?

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

    // MARK: - 粘贴折叠按钮 hover

    override func viewDidMoveToWindow() {
        super.viewDidMoveToWindow()
        refreshPasteHoverTracking()
    }

    override func updateTrackingAreas() {
        super.updateTrackingAreas()
        refreshPasteHoverTracking()
    }

    private func refreshPasteHoverTracking() {
        pasteHoverTrackingArea.map(removeTrackingArea)
        guard hasPastePreviewAttachments, window != nil else {
            pasteHoverTrackingArea = nil
            return
        }
        let area = NSTrackingArea(
            rect: .zero,
            options: [.mouseMoved, .mouseEnteredAndExited, .inVisibleRect, .activeInKeyWindow],
            owner: self
        )
        addTrackingArea(area)
        pasteHoverTrackingArea = area
    }

    /// 挂上/摘掉 hover 追踪区。粘贴折叠按钮出现后需要立即生效，
    /// 不依赖 AppKit 的 `updateTrackingAreas` 回调时机。
    func syncPasteHoverTracking() {
        refreshPasteHoverTracking()
    }

    override func mouseMoved(with event: NSEvent) {
        super.mouseMoved(with: event)
        updateHoveredPasteCell(at: convert(event.locationInWindow, from: nil))
    }

    override func mouseExited(with event: NSEvent) {
        super.mouseExited(with: event)
        setHoveredPasteCell(nil)
    }

    override func mouseDown(with event: NSEvent) {
        setHoveredPasteCell(nil)
        let point = convert(event.locationInWindow, from: nil)
        if showPastePreviewIfNeeded(at: point) {
            return
        }
        super.mouseDown(with: event)
    }

    private func updateHoveredPasteCell(at point: NSPoint) {
        guard let cell = pastePreviewCell(at: point) else {
            setHoveredPasteCell(nil)
            return
        }
        setHoveredPasteCell(cell)
    }

    private func setHoveredPasteCell(_ cell: PasteButtonAttachmentCell?) {
        guard hoveredPasteCell !== cell else { return }
        hoveredPasteCell = cell
        // 按钮是内联 attachment，由 textView 统一绘制，状态变化后整段重画即可。
        needsDisplay = true
    }

    /// 命中测试：返回命中点所在的粘贴折叠按钮，没有则返回 nil。
    private func pastePreviewCell(at point: NSPoint) -> PasteButtonAttachmentCell? {
        guard let textStorage, let layoutManager, let textContainer else {
            return nil
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
            return nil
        }

        return attachment.attachmentCell as? PasteButtonAttachmentCell
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
        popover.contentSize = PastePreviewPopoverViewController.contentSize
        popover.contentViewController = PastePreviewPopoverViewController(
            text: attachment.originalText,
            summaryText: attachment.summaryText,
            title: attachment.previewTitle
        )
        popover.show(relativeTo: rect, of: self, preferredEdge: .maxY)
        pastePreviewPopover = popover
    }
}

// MARK: - PastePreviewAttachment

/// 折叠后的大段粘贴内容。
///
/// 通过 ``PasteButtonAttachmentCell`` 在正文里绘制成一行内联的「小按钮」chip，
/// 视觉上只占用一行、随文本一起排版；点击后弹出可滚动的预览 popover。
///
/// 粘贴与大段内容的折叠共用这一种 attachment：区别只在 chip 上显示的标题与图标，
/// 发送时都还原为 `originalText`。
final class PastePreviewAttachment: NSTextAttachment {
    let originalText: String
    let characterCount: Int
    let lineCount: Int
    let byteCountText: String
    /// 预览弹窗标题。粘贴固定为「粘贴的文本」，外部内容用来源标题（如文件名）。
    let previewTitle: String
    /// chip 上的主标题。粘贴是「粘贴的文本」，外部内容是来源（如文件名）。
    ///
    /// 与 ``chipDetail`` 分开存放，是为了在视觉上把「这是什么」与「有多大」
    /// 分成两层：标题与正文同号同色，统计信息小一号、用次级色。
    let chipLabel: String
    /// chip 上紧跟标题的统计信息（如「5,678 字 · 195 行」）。可为空。
    let chipDetail: String
    /// chip 的一行完整文案。随消息落库，消息端据此还原同样的 chip。
    let chipTitle: String
    /// chip 图标（SF Symbol 名）。外部内容由生产方指定，粘贴走默认值。
    let systemImage: String

    /// 粘贴路径：不带来源标题与图标，chip 沿用「粘贴的文本」文案。
    @MainActor
    convenience init(
        originalText: String,
        font: NSFont? = nil,
        palette: PasteChipPalette = .fallback
    ) {
        self.init(
            originalText: originalText,
            title: nil,
            systemImage: nil,
            font: font,
            palette: palette
        )
    }

    @MainActor
    convenience init(
        originalText: String,
        title: String?,
        systemImage: String?,
        palette: PasteChipPalette = .fallback
    ) {
        self.init(
            originalText: originalText,
            title: title,
            systemImage: systemImage,
            font: nil,
            palette: palette
        )
    }

    /// - Parameter font: chip 所在编辑器的正文字体。传入后 chip 高度与该字号对齐；
    ///   为 nil 时退回默认字号，行为与之前一致。
    /// - Parameter palette: chip 配色。由 SwiftUI 层按主题注入，与消息列表共用。
    @MainActor
    init(
        originalText: String,
        title: String?,
        systemImage: String?,
        font: NSFont?,
        palette: PasteChipPalette = .fallback
    ) {
        self.originalText = originalText
        self.characterCount = originalText.count
        self.lineCount = Self.lineCount(for: originalText)
        self.byteCountText = ByteCountFormatter.string(
            fromByteCount: Int64(originalText.utf8.count),
            countStyle: .file
        )
        self.previewTitle = title ?? pluginLocalization.string("Pasted text")
        // 有来源标题时标题就是来源（如文件名），没有时用「粘贴的文本」。
        // 统计信息始终另起一层，视觉上比标题弱一级。
        self.chipLabel = title ?? pluginLocalization.string("Pasted text")
        self.chipDetail = Self.chipDetailText(
            characterCount: characterCount,
            lineCount: lineCount
        )
        self.chipTitle = "\(self.chipLabel) · \(self.chipDetail)"
        self.systemImage = systemImage ?? PasteButtonAttachmentCell.defaultSymbolName
        super.init(data: nil, ofType: nil)
        if let font {
            self.attachmentCell = PasteButtonAttachmentCell(
                title: self.chipLabel,
                detail: self.chipDetail,
                systemImage: self.systemImage,
                font: font,
                palette: palette
            )
        } else {
            self.attachmentCell = PasteButtonAttachmentCell(
                title: self.chipLabel,
                detail: self.chipDetail,
                systemImage: self.systemImage,
                palette: palette
            )
        }
    }

    /// chip 上紧跟标题的统计信息，例如「12,480 字 · 312 行」。
    private static func chipDetailText(
        characterCount: Int,
        lineCount: Int
    ) -> String {
        [
            countText(characterCount),
            lineText(lineCount)
        ].joined(separator: " · ")
    }

    @available(*, unavailable)
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    /// 预览弹窗里展示的完整摘要。
    var summaryText: String {
        "\(Self.countText(characterCount)) · \(Self.lineText(lineCount)) · \(byteCountText)"
    }

    static func countText(_ count: Int) -> String {
        String(
            format: pluginLocalization.string("%@ chars"),
            Self.decimalNumber(count)
        )
    }

    static func lineText(_ count: Int) -> String {
        String(
            format: pluginLocalization.string("%@ lines"),
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

// MARK: - PasteButtonAttachmentCell

/// 把折叠的大段粘贴绘制成一行内联的「小按钮」。
///
/// 外观是一个圆角胶囊：淡色背景 + 细描边 + 图标 + 标题 + 统计信息，
/// hover 时背景与描边加深，让用户知道这是个可点的按钮。
///
/// ## 与消息列表对齐
///
/// 同一段折叠内容在消息列表里也渲染成一个 chip。两处共用圆角、间距与配色；
/// 输入框里的主标题则跟随正文字体，保证与同一行的普通文字对齐。
///
/// ## 与文字行的融合
///
/// chip 要看起来像「长在这行文字里」而不是「浮在文字上」，必须满足两条：
///
/// 1. **基线一致**——chip 的文字基线与正文基线是同一条水平线。
/// 2. **不撑高行**——chip 的行内占位高度与普通文字相同。
///
/// ### 基线必须与 AppKit 的摆放规则同源
///
/// AppKit 摆放 attachment cell 的规则（实测确认）：
///
/// ```
/// 正文基线 = cellFrame.minY + cellBaselineOffset.y + cellHeight
/// ```
///
/// 于是「绘制时的基线 = cellFrame.minY + internalBaseline」要正好等于正文
/// 基线，就必须有 `internalBaseline == cellBaselineOffset.y + cellHeight`。
///
/// - Important: 这个等式**不能靠两处各算一遍**。早期实现里
///   `internalBaseline` 与 `cellHeight` 各自来自字体度量，看着相等，实则
///   只要有一处被改动（cell 高度变了、行高变了……），误差会**原样放大成
///   整块 chip 的下沉/上浮**：差 12pt 就是 chip 整块掉到正文下面 12pt——
///   用户截图里的观感。故现在 `internalBaseline` 直接由那两个量推导。
///
/// - Note: 早期还试过「向文本系统问基线」，但那条路走不通：AppKit 绘制
///   attachment cell 时传的 `controlView` 是 **nil**，cell 拿不到文本视图。
///
/// ## 胶囊贴着内容，而不是撑满行盒
///
/// cell 的行内占位高度必须等于行高（否则会撑高行），但**画出来的胶囊**
/// 不必占满这个高度。早期实现把胶囊画成整个 cell 高度，于是胶囊底边
/// 落到正文基线以下 13pt（实测），胶囊高 27pt——比 18pt 的行盒还高，
/// 视觉上像一块底板压住文字。这正是输入框里的 chip 显得「乱」的主因。
///
/// 现在胶囊按**正文的字形墨迹**计算高度：上沿与正文的字顶齐平、下沿与
/// 正文的字底齐平，上下各留一点内边距，于是胶囊刚好裹住这一行的文字，
/// 看起来是「长在行里」而不是「压在字下」。
///
/// 胶囊高度用 CoreText 的字形墨迹边界计算，紧贴实际字形，
/// 不会因为 CJK 与拉丁的升降部差异而忽高忽低。
///
/// 宽度在初始化时按文本测量并缓存，避免布局阶段反复测量字符串。
final class PasteButtonAttachmentCell: NSTextAttachmentCell {
    /// 胶囊左右内边距。
    private static var horizontalPadding: CGFloat { CollapsedContentChipStyle.horizontalPadding }
    /// 胶囊上下内边距（相对字形墨迹边界）。
    private static var capsulePadding: CGFloat { CollapsedContentChipStyle.inlineVerticalPadding }
    /// 胶囊最大宽度。超出时截断标题而不是无限拉长。
    private static var maximumWidth: CGFloat { CollapsedContentChipStyle.maximumWidth }
    /// 图标尺寸与图标到标题的间距。
    private static var iconSize: CGFloat { CollapsedContentChipStyle.iconSize }
    private static var iconSpacing: CGFloat { CollapsedContentChipStyle.iconSpacing }
    /// 标题与统计信息之间的间距。
    private static var detailSpacing: CGFloat { CollapsedContentChipStyle.detailSpacing }
    /// 未指定图标时使用的默认符号。
    static let defaultSymbolName = "doc.on.clipboard"

    /// 量正文墨迹时使用的代表性中文。
    ///
    /// 中文是输入框正文的主要字符，且它的墨迹相对基线偏上——正是胶囊需要
    /// 对齐的那个偏移。
    private static let bodyInkSample = "国"

    private let titleFont: NSFont
    private let detailFont: NSFont
    private let symbolPointSize: CGFloat
    private let cellHeight: CGFloat
    /// 测试专用的 cell 占位高度覆盖值。生产路径恒为 nil。
    ///
    /// `nonisolated(unsafe)`：`cellSize()` 是 AppKit 的非隔离覆写，读不到
    /// 主 actor 的状态。这个值只在主线程上由测试改一次，故可以安全地
    /// 绕过隔离检查。
    nonisolated(unsafe) private var cellHeightForTesting: CGFloat?
    private let cornerRadius: CGFloat
    private let baselineOffset: CGFloat
    /// chip 文字基线相对 cellFrame.minY 的高度。
    ///
    /// **必须等于 `cellBaselineOffset.y + cellSize().height`**——这正是
    /// AppKit 摆放 attachment cell 的规则（实测确认）：
    ///
    /// ```
    /// 正文基线 = cellFrame.minY + cellBaselineOffset.y + cellHeight
    /// ```
    ///
    /// 于是「绘制时的基线 = cellFrame.minY + internalBaseline」恰好等于正文
    /// 基线。
    ///
    /// - Important: 这个等式**不能靠两处各算一遍**。早期实现里
    ///   `internalBaseline` 与 `cellHeight` 各自来自字体度量，看似相等，
    ///   实则只要有一处被改动（cell 高度变了、行高变了……），误差会**原样
    ///   放大成整块 chip 的下沉/上浮**：差 12pt 就是 chip 整块掉到正文下面
    ///   12pt，正是用户截图里的观感。故此处直接由那两个量推导。
    private var internalBaseline: CGFloat {
        baselineOffset + effectiveCellHeight
    }
    /// cell 的行内占位高度。`cellSize()` 与 ``internalBaseline`` 都用它。
    private var effectiveCellHeight: CGFloat {
        cellHeightForTesting ?? cellHeight
    }
    private let chipTitle: String
    private let chipTitleWidth: CGFloat
    /// chip 副标题（统计信息）。为空时只画标题。
    private let chipDetail: String
    private let chipDetailWidth: CGFloat
    /// chip 占位宽度：图标 + 标题 + 统计信息。初始化时算好。
    private let contentWidth: CGFloat
    /// chip 图标名。粘贴用剪贴板图标，外部内容由生产方指定（如代码文件的括号图标）。
    private let symbolName: String
    /// 正文字体墨迹相对基线的上下边界。
    private let bodyInkAbove: CGFloat
    private let bodyInkBelow: CGFloat
    /// chip 配色。由 SwiftUI 层按主题注入，保证与消息列表一致。
    private let palette: PasteChipPalette

    /// chip 文案使用的字体与颜色。字号随实例的 `titleFont` 变化，这里按需组装。
    ///
    /// 颜色取自 ``PasteChipPalette``，与消息列表的 chip 共用同一套色。
    private static func titleAttributes(
        for font: NSFont,
        color: NSColor
    ) -> [NSAttributedString.Key: Any] {
        [
            .font: font,
            .foregroundColor: color
        ]
    }

    /// 文本墨迹相对基线的上下边界。
    ///
    /// 用 CoreText 的字形路径边界而非字体的 ascent/descent：CJK 与拉丁的
    /// 实际墨迹范围差别很大，按字体度量算会让胶囊忽高忽低。
    private static func inkBounds(of text: String, font: NSFont) -> (above: CGFloat, below: CGFloat) {
        guard !text.isEmpty else { return (0, 0) }
        let attributed = NSAttributedString(string: text, attributes: [.font: font])
        let line = CTLineCreateWithAttributedString(attributed)
        let bounds = CTLineGetBoundsWithOptions(line, .useGlyphPathBounds)
        return (above: bounds.maxY, below: -bounds.minY)
    }

    /// - Parameters:
    ///   - title: chip 主标题（如「粘贴的文本」）。
    ///   - detail: chip 副标题（如「5,678 字 · 195 行」）。可为空。
    ///   - font: chip 所在编辑器的正文字体。主标题、行内占位高度和胶囊高度
    ///     都以它为参照，保证 chip 与两侧正文的字顶、字底和基线一致。
    ///   - palette: chip 配色。由 SwiftUI 层按主题注入，与消息列表共用同一套色。
    init(
        title: String,
        detail: String = "",
        systemImage: String? = nil,
        font: NSFont = .systemFont(ofSize: 15),
        palette: PasteChipPalette = .fallback
    ) {
        self.chipTitle = title
        self.chipDetail = detail
        self.symbolName = systemImage ?? Self.defaultSymbolName
        self.palette = palette
        self.titleFont = font
        self.detailFont = .systemFont(ofSize: CollapsedContentChipStyle.detailSize, weight: .regular)
        self.symbolPointSize = Self.iconSize

        let lineHeight = NSLayoutManager().defaultLineHeight(for: font)
        let descender = -font.descender
        // cell 覆盖整个行盒，行高因此与普通文字一致。
        self.cellHeight = lineHeight
        // cell 帧里，基线离底边的距离。AppKit 摆放 attachment 时用它把
        // chip 的基线对到正文基线上。
        self.baselineOffset = -descender
        // internalBaseline 由上面两个量推导（见其注释），不在这里另算一遍。

        let titleAttributes = Self.titleAttributes(for: self.titleFont, color: palette.title)
        let measuredTitle = ceil((title as NSString).size(withAttributes: titleAttributes).width)
        let measuredDetail = detail.isEmpty
            ? 0
            : ceil((detail as NSString).size(withAttributes: [.font: self.detailFont]).width)

        // 宽度预算：先给统计信息留位置，剩余给标题；仍不够就整体舍弃统计信息。
        let fixed = Self.horizontalPadding * 2 + Self.iconSize + Self.iconSpacing
        let budget = Self.maximumWidth - fixed
        let resolvedTitleWidth: CGFloat
        let resolvedDetailWidth: CGFloat
        if !detail.isEmpty, measuredTitle + Self.detailSpacing + measuredDetail <= budget {
            resolvedTitleWidth = measuredTitle
            resolvedDetailWidth = measuredDetail
        } else {
            resolvedTitleWidth = min(measuredTitle, budget)
            resolvedDetailWidth = 0
        }
        self.chipTitleWidth = resolvedTitleWidth
        self.chipDetailWidth = resolvedDetailWidth
        // 占位宽度在初始化时算好，避免 cellSize() 里访问主线程隔离的属性。
        self.contentWidth = fixed
            + resolvedTitleWidth
            + (resolvedDetailWidth > 0 ? Self.detailSpacing + resolvedDetailWidth : 0)

        // 正文的墨迹边界。取一段代表性中文来量：中文的墨迹相对基线偏上，
        // 且与拉丁差别很大，用字体度量（ascent/descent）会算错。
        let bodyInk = Self.inkBounds(of: Self.bodyInkSample, font: font)
        self.bodyInkAbove = bodyInk.above
        self.bodyInkBelow = bodyInk.below

        // 胶囊圆角：与消息列表一致。
        self.cornerRadius = CollapsedContentChipStyle.cornerRadius
        super.init()
    }

    @available(*, unavailable)
    required init(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    override func cellSize() -> NSSize {
        NSSize(width: contentWidth, height: effectiveCellHeight)
    }

    /// 仅供测试：改掉 cell 的行内占位高度。
    ///
    /// 用来模拟「cell 的占位高度与算基线时用的高度不一致」的情形——早期
    /// 实现里这两处各算一遍，一旦不一致，误差会整块放大成 chip 的下沉。
    /// 这条缝只给测试开，生产路径永远走真实高度。
    @MainActor
    func setCellHeightForTesting(_ height: CGFloat) {
        cellHeightForTesting = height
    }

    override func cellBaselineOffset() -> NSPoint {
        NSPoint(x: 0, y: baselineOffset)
    }

    override func draw(withFrame cellFrame: NSRect, in controlView: NSView?) {
        let isHighlighted = (controlView as? EditorTextView)?.hoveredPasteCell === self
        let isFlipped = NSGraphicsContext.current?.isFlipped == true
        let baselineY = cellFrame.minY + internalBaseline

        let bodyInkHeight = bodyInkAbove + bodyInkBelow
        let bodyInkCenter = (bodyInkAbove - bodyInkBelow) / 2
        let contentCenterY = isFlipped ? baselineY - bodyInkCenter : baselineY + bodyInkCenter
        let chipHeight = min(bodyInkHeight + Self.capsulePadding * 2, cellFrame.height)
        let chipRect = NSRect(
            x: cellFrame.minX,
            y: contentCenterY - chipHeight / 2,
            width: cellFrame.width,
            height: chipHeight
        )

        let path = NSBezierPath(
            roundedRect: chipRect,
            xRadius: cornerRadius,
            yRadius: cornerRadius
        )

        if isHighlighted {
            palette.hoverFill.setFill()
            palette.hoverStroke.setStroke()
        } else {
            // 底色与描边都压得很轻，避免胶囊盖过旁边的正文。
            palette.fill.setFill()
            palette.stroke.setStroke()
        }
        path.fill()

        // - Important: 描边必须真的描出来。只 `setStroke()` 而不 `stroke()`，
        //   胶囊就只剩一层底色、没有边框——而消息列表那侧是 `strokeBorder`，
        //   两边看起来就不是同一个东西（一边有边、一边没边）。
        //
        //   且描边要压在**形状内侧**：SwiftUI 的 `strokeBorder` 把描边画在形状
        //   内部，胶囊的外边界仍等于形状本身；AppKit 的 `stroke()` 默认是
        //   **居中**描边，会向外溢出半个线宽，于是两边的胶囊轮廓差出 0.5pt，
        //   且输入框这侧会撑破正文的字带（chip 会比正文高出一圈）。
        //   故这里先按形状裁剪、再居中描边——可见的描边落在形状内部，
        //   外边界回到 chipRect，与消息列表那侧一致。
        let strokeWidth = CollapsedContentChipStyle.strokeWidth
        NSGraphicsContext.saveGraphicsState()
        path.setClip()
        path.lineWidth = strokeWidth
        path.stroke()
        NSGraphicsContext.restoreGraphicsState()

        // 图标与字形盒视觉居中。
        let iconRect = NSRect(
            x: chipRect.minX + Self.horizontalPadding,
            y: contentCenterY - Self.iconSize / 2,
            width: Self.iconSize,
            height: Self.iconSize
        )
        symbolImage()?.draw(in: iconRect)

        func drawText(
            _ text: String,
            width: CGFloat,
            attributes: [NSAttributedString.Key: Any],
            at x: CGFloat
        ) {
            guard let graphicsContext = NSGraphicsContext.current?.cgContext else { return }
            let line = CTLineCreateWithAttributedString(
                NSAttributedString(string: text, attributes: attributes)
            )
            let drawableLine = CTLineCreateTruncatedLine(line, Double(width), .end, nil) ?? line
            graphicsContext.saveGState()
            if isFlipped {
                graphicsContext.textMatrix = CGAffineTransform(scaleX: 1, y: -1)
            }
            graphicsContext.textPosition = CGPoint(x: x, y: baselineY)
            CTLineDraw(drawableLine, graphicsContext)
            graphicsContext.restoreGState()
        }

        var x = iconRect.maxX + Self.iconSpacing
        drawText(
            chipTitle,
            width: chipTitleWidth,
            attributes: Self.titleAttributes(for: titleFont, color: palette.title),
            at: x
        )
        x += chipTitleWidth

        if chipDetailWidth > 0 {
            x += Self.detailSpacing
            drawText(chipDetail, width: chipDetailWidth, attributes: [
                .font: detailFont,
                .foregroundColor: palette.detail
            ], at: x)
        }
    }

    private func symbolImage() -> NSImage? {
        guard let symbol = NSImage(systemSymbolName: symbolName, accessibilityDescription: nil) else {
            return nil
        }
        let configuration = NSImage.SymbolConfiguration(
            pointSize: symbolPointSize,
            weight: .medium
        )
            .applying(NSImage.SymbolConfiguration(paletteColors: [palette.icon]))
        return symbol.withSymbolConfiguration(configuration)
    }
}

// MARK: - PastePreviewPopoverViewController

final class PastePreviewPopoverViewController: NSViewController {
    private let text: String
    private let summaryText: String
    /// 弹窗标题。粘贴显示「粘贴的文本」，外部内容显示来源（如文件名）。
    private let displayTitle: String
    private weak var copyButton: NSButton?
    private var copyFeedbackResetItem: DispatchWorkItem?

    init(text: String, summaryText: String, title: String = "") {
        self.text = text
        self.summaryText = summaryText
        self.displayTitle = title.isEmpty ? pluginLocalization.string("Pasted text") : title
        super.init(nibName: nil, bundle: nil)
    }

    @available(*, unavailable)
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    /// 弹窗内容四周的内边距，让标题、正文与按钮都不贴在圆角边缘上。
    private static let contentPadding: CGFloat = 16
    /// 头部固定高度，正文区域吃掉剩余空间。
    private static let headerHeight: CGFloat = 44
    /// 弹窗总尺寸。宽度含 contentPadding，正文可用宽度需要再减去两侧内边距。
    static let contentSize = NSSize(width: 620, height: 460)
    /// 传给 scrollView 的文档宽度，只作为排版的初始值，最终由滚动区宽度决定。
    private static var textWidth: CGFloat { contentSize.width - contentPadding * 2 }

    override func loadView() {
        let container = NSView()
        let scrollView = NSScrollView()
        scrollView.drawsBackground = false
        scrollView.hasVerticalScroller = true
        scrollView.hasHorizontalScroller = false
        scrollView.autohidesScrollers = true
        scrollView.translatesAutoresizingMaskIntoConstraints = false

        let textView = NSTextView()
        textView.isEditable = false
        textView.isSelectable = true
        textView.isRichText = false
        textView.drawsBackground = false
        textView.font = .monospacedSystemFont(ofSize: 12, weight: .regular)
        textView.textColor = .labelColor
        // 外层已有 contentPadding，正文内部不再重复内缩，避免双层留白。
        textView.textContainerInset = .zero
        textView.textContainer?.widthTracksTextView = true
        textView.textContainer?.containerSize = NSSize(width: Self.textWidth, height: CGFloat.greatestFiniteMagnitude)
        textView.frame = NSRect(x: 0, y: 0, width: Self.textWidth, height: 320)
        textView.string = text

        scrollView.documentView = textView

        let header = NSStackView()
        header.orientation = .horizontal
        header.alignment = .centerY
        header.distribution = .fill
        header.spacing = 10
        header.translatesAutoresizingMaskIntoConstraints = false

        let titleStack = NSStackView()
        titleStack.orientation = .vertical
        titleStack.alignment = .leading
        titleStack.spacing = 2
        titleStack.translatesAutoresizingMaskIntoConstraints = false

        let titleLabel = NSTextField(
            labelWithString: displayTitle
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

        let copyButton = NSButton(title: pluginLocalization.string("Copy original"), target: self, action: #selector(copyOriginalText))
        copyButton.bezelStyle = .rounded
        copyButton.translatesAutoresizingMaskIntoConstraints = false
        let closeButton = NSButton(title: pluginLocalization.string("Close"), target: self, action: #selector(closePopover))
        closeButton.bezelStyle = .rounded
        closeButton.translatesAutoresizingMaskIntoConstraints = false

        header.addArrangedSubview(titleStack)
        header.addArrangedSubview(spacer)
        header.addArrangedSubview(copyButton)
        header.addArrangedSubview(closeButton)
        self.copyButton = copyButton

        let stack = NSStackView(views: [header, scrollView])
        stack.orientation = .vertical
        // 头部与正文都要横向撑满，否则滚动区宽度会退回文档宽度。
        stack.alignment = .width
        stack.spacing = 12
        stack.translatesAutoresizingMaskIntoConstraints = false

        container.addSubview(stack)
        NSLayoutConstraint.activate([
            stack.leadingAnchor.constraint(equalTo: container.leadingAnchor, constant: Self.contentPadding),
            stack.trailingAnchor.constraint(equalTo: container.trailingAnchor, constant: -Self.contentPadding),
            stack.topAnchor.constraint(equalTo: container.topAnchor, constant: Self.contentPadding),
            stack.bottomAnchor.constraint(equalTo: container.bottomAnchor, constant: -Self.contentPadding),
            header.heightAnchor.constraint(equalToConstant: Self.headerHeight)
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
