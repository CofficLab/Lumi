import AppKit
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
                    font: textView.font
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
                font: textView.font
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
    /// chip 上显示的一行文案。随消息落库，渲染层据此还原同样的 chip。
    let chipTitle: String
    /// chip 图标（SF Symbol 名）。外部内容由生产方指定，粘贴走默认值。
    let systemImage: String

    /// 粘贴路径：不带来源标题与图标，chip 沿用「粘贴的文本」文案。
    @MainActor
    convenience init(originalText: String, font: NSFont? = nil) {
        self.init(originalText: originalText, title: nil, systemImage: nil, font: font)
    }

    @MainActor
    convenience init(originalText: String, title: String?, systemImage: String?) {
        self.init(originalText: originalText, title: title, systemImage: systemImage, font: nil)
    }

    /// - Parameter font: chip 所在编辑器的正文字体。传入后 chip 高度与该字号对齐；
    ///   为 nil 时退回默认字号，行为与之前一致。
    @MainActor
    init(originalText: String, title: String?, systemImage: String?, font: NSFont?) {
        self.originalText = originalText
        self.characterCount = originalText.count
        self.lineCount = Self.lineCount(for: originalText)
        self.byteCountText = ByteCountFormatter.string(
            fromByteCount: Int64(originalText.utf8.count),
            countStyle: .file
        )
        self.previewTitle = title ?? pluginLocalization.string("Pasted text")
        self.chipTitle = Self.chipTitleText(
            title: title,
            characterCount: characterCount,
            lineCount: lineCount
        )
        self.systemImage = systemImage ?? PasteButtonAttachmentCell.defaultSymbolName
        super.init(data: nil, ofType: nil)
        if let font {
            self.attachmentCell = PasteButtonAttachmentCell(
                title: self.chipTitle,
                systemImage: self.systemImage,
                font: font
            )
        } else {
            self.attachmentCell = PasteButtonAttachmentCell(
                title: self.chipTitle,
                systemImage: self.systemImage
            )
        }
    }

    /// chip 上显示的一行文案。带来源标题时只追加字数，避免 chip 过长。
    private static func chipTitleText(
        title: String?,
        characterCount: Int,
        lineCount: Int
    ) -> String {
        title.map { "\($0) · \(Self.countText(characterCount))" }
            ?? Self.chipTitle(characterCount: characterCount, lineCount: lineCount)
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
            pluginLocalization.string("Pasted text"),
            countText(characterCount),
            lineText(lineCount)
        ].joined(separator: " · ")
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
/// 外观是一个圆角胶囊：淡色背景 + 细描边 + 图标 + 一行摘要文字，
/// 与正文基线对齐且只占一行。hover 时背景与描边加深，让用户知道这是个可点的按钮。
/// 宽度在初始化时按文本测量并缓存，避免布局阶段反复测量字符串。
final class PasteButtonAttachmentCell: NSTextAttachmentCell {
    private static let contentInset: CGFloat = 6
    private static let maximumWidth: CGFloat = 260
    /// 描边宽度的一半，留给描边本身，避免描边被裁掉。
    private static let strokeInset: CGFloat = 1
    /// chip 与正文行高之间的差值，让它与普通文字同高而不是撑满整行。
    private static let lineHeightSlack: CGFloat = 2
    /// 未指定图标时使用的默认符号。
    static let defaultSymbolName = "doc.on.clipboard"

    private let titleFont: NSFont
    private let symbolPointSize: CGFloat
    private let iconSize: CGFloat = 11
    private let iconTitleSpacing: CGFloat = 4
    private let chipHeight: CGFloat
    private let cornerRadius: CGFloat
    private let baselineOffset: CGFloat
    private let chipTitle: String
    private let chipTitleWidth: CGFloat
    /// chip 图标名。粘贴用剪贴板图标，外部内容由生产方指定（如代码文件的括号图标）。
    private let symbolName: String

    /// chip 文案使用的字体与颜色。字号随实例的 `titleFont` 变化，这里按需组装。
    private static func titleAttributes(for font: NSFont) -> [NSAttributedString.Key: Any] {
        [
            .font: font,
            .foregroundColor: NSColor.labelColor
        ]
    }

    /// - Parameter font: chip 所在编辑器的正文字体。chip 的字号与高度都从这里派生，
    ///   这样正文字号变化时 chip 会自动跟随，不会再出现「比文字高一圈」的情况。
    init(title: String, systemImage: String? = nil, font: NSFont = .systemFont(ofSize: 15)) {
        self.chipTitle = title
        self.symbolName = systemImage ?? Self.defaultSymbolName
        // chip 文字比正文小 4pt，但不低于 10pt，避免小字号正文下不可读。
        self.titleFont = .systemFont(ofSize: max(10, font.pointSize - 4), weight: .medium)
        self.symbolPointSize = max(8, titleFont.pointSize - 2)
        let lineHeight = NSLayoutManager().defaultLineHeight(for: font)
        // 比行高低 lineHeightSlack，使 chip 底边贴近基线、顶边不越过行高。
        self.chipHeight = max(12, lineHeight - Self.lineHeightSlack)
        self.cornerRadius = self.chipHeight / 3
        self.baselineOffset = -(lineHeight - self.chipHeight) / 2
        let measured = ceil((title as NSString).size(withAttributes: Self.titleAttributes(for: self.titleFont)).width)
        let maximum = Self.maximumWidth
            - Self.contentInset * 2
            - self.iconSize
            - self.iconTitleSpacing
        self.chipTitleWidth = min(measured, maximum)
        super.init()
    }

    @available(*, unavailable)
    required init(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    override func cellSize() -> NSSize {
        NSSize(
            width: Self.contentInset * 2 + iconSize + iconTitleSpacing + chipTitleWidth,
            height: chipHeight
        )
    }

    override func cellBaselineOffset() -> NSPoint {
        NSPoint(x: 0, y: baselineOffset)
    }

    override func draw(withFrame cellFrame: NSRect, in controlView: NSView?) {
        let isHighlighted = (controlView as? EditorTextView)?.hoveredPasteCell === self

        // 描边占1pt，位于 cellFrame 外缘之内，所以左右各留 1pt 的描边空间。
        let chipRect = NSRect(
            x: cellFrame.minX + Self.strokeInset,
            y: cellFrame.minY + 1,
            width: cellFrame.width - Self.strokeInset * 2,
            height: cellFrame.height - 2
        )

        let path = NSBezierPath(
            roundedRect: chipRect,
            xRadius: cornerRadius,
            yRadius: cornerRadius
        )
        path.lineWidth = 1

        if isHighlighted {
            NSColor.controlAccentColor.withAlphaComponent(0.16).setFill()
            path.fill()
            NSColor.controlAccentColor.withAlphaComponent(0.45).setStroke()
        } else {
            NSColor.labelColor.withAlphaComponent(0.07).setFill()
            path.fill()
            NSColor.labelColor.withAlphaComponent(0.16).setStroke()
        }

        let iconRect = NSRect(
            x: chipRect.minX + Self.contentInset,
            y: chipRect.midY - iconSize / 2,
            width: iconSize,
            height: iconSize
        )
        symbolImage()?.draw(in: iconRect)

        let lineHeight = ceil(titleFont.ascender - titleFont.descender)
        let titleMinX = iconRect.maxX + iconTitleSpacing
        let titleRect = NSRect(
            x: titleMinX,
            y: chipRect.midY - lineHeight / 2,
            width: max(0, chipRect.maxX - Self.contentInset - titleMinX),
            height: lineHeight
        )

        let paragraph = NSMutableParagraphStyle()
        paragraph.lineBreakMode = .byTruncatingTail
        var attributes = Self.titleAttributes(for: titleFont)
        attributes[.paragraphStyle] = paragraph
        (chipTitle as NSString).draw(in: titleRect, withAttributes: attributes)
    }

    private func symbolImage() -> NSImage? {
        guard let symbol = NSImage(systemSymbolName: symbolName, accessibilityDescription: nil) else {
            return nil
        }
        let configuration = NSImage.SymbolConfiguration(
            pointSize: symbolPointSize,
            weight: .semibold
        )
            .applying(NSImage.SymbolConfiguration(paletteColors: [.secondaryLabelColor]))
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
