import Foundation
import AppKit
import CodeEditSourceEditor
import CodeEditTextView
import LanguageServerProtocol
import os
import MagicKit

/// LSP 悬停协调器
/// 监听鼠标位置，通过 `TextLayoutManager.textOffsetAtPoint` 获取鼠标下的文字偏移，
/// 请求 LSP hover，然后利用 `layoutManager.rectForOffset` 将 LSP Range 转换为精确的
/// 屏幕/视图坐标，供 SwiftUI overlay 在 symbol 上方显示 popover。
@MainActor
final class HoverEditorCoordinator: TextViewCoordinator, SuperLog {
    nonisolated static let emoji = "🖱️"
    private static let defaultHoverDelayNs: UInt64 = 350_000_000
    private static let fastHoverDelayNs: UInt64 = 120_000_000
    private static let fastHoverWindowNs: UInt64 = 1_200_000_000
    private static let hoverCacheMaxEntries = 64
    private static let hoverCacheTTLNs: UInt64 = 15_000_000_000

    private struct HoverCacheKey: Hashable {
        let uri: String
        let line: Int
        let character: Int
        let documentFingerprint: Int
    }

    private struct HoverCacheEntry {
        let content: String
        let range: LSPRange?
        let createdAtNs: UInt64
    }

    private struct ActiveHoverRange {
        let uri: String
        let documentFingerprint: Int
        let range: LSPRange
        let content: String
    }

    private weak var state: EditorState?
    private weak var textViewController: TextViewController?
    private var hoverTask: Task<Void, Never>?
    private var mouseMonitor: Any?
    private var globalMouseMonitor: Any?
    private var keyMonitor: Any?
    private var lastHoverPosition: (line: Int, character: Int)?
    private var lastHoverRequestAtNs: UInt64?
    private var clipBoundsObserver: NSObjectProtocol?
    private var clipFrameObserver: NSObjectProtocol?
    private var hoverCache: [HoverCacheKey: HoverCacheEntry] = [:]
    private var hoverCacheOrder: [HoverCacheKey] = []
    private var activeHoverRange: ActiveHoverRange?
    private var lastDocumentURI: String?

    init(state: EditorState) {
        self.state = state
    }

    // MARK: - TextViewCoordinator

    nonisolated func prepareCoordinator(controller: TextViewController) {
        Task { @MainActor [weak self] in
            guard let self else { return }
            self.textViewController = controller
            installScrollObserversIfNeeded()
            installMouseMonitorIfNeeded()
            installGlobalMouseMonitorIfNeeded()
            installKeyMonitorIfNeeded()
        }
    }

    nonisolated func textViewDidChangeSelection(controller: TextViewController) {
        // Hover 由鼠标驱动，不需要响应光标移动
    }

    nonisolated func destroy() {
        Task { @MainActor [weak self] in
            self?.hoverTask?.cancel()
            self?.removeMouseMonitor()
            self?.removeGlobalMouseMonitor()
            self?.removeKeyMonitor()
            self?.removeScrollObservers()
            self?.lastHoverPosition = nil
            self?.textViewController = nil
            self?.state = nil
        }
    }

    // MARK: - 公共 API

    /// 当鼠标移动到新位置时调用，触发 hover 请求
    func triggerHover(for line: Int, character: Int, symbolRect: CGRect) {
        if EditorPlugin.verbose {
            EditorPlugin.logger.debug("\(HoverEditorCoordinator.t)⚡ 触发悬停: 行=\(line) 字符=\(character) 矩形=\(String(describing: symbolRect))")
        }
        refreshDocumentContextIfNeeded()
        let delay = hoverDelay(for: line, character: character)
        if EditorPlugin.verbose {
            EditorPlugin.logger.debug("\(HoverEditorCoordinator.t)⏱️ 悬停延迟=\(delay / 1_000_000)ms")
        }
        hoverTask?.cancel()
        lastHoverPosition = (line, character)
        lastHoverRequestAtNs = DispatchTime.now().uptimeNanoseconds
        hoverTask = Task { [weak self] in
            guard let self, let state else { return }

            try? await Task.sleep(nanoseconds: delay)
            guard !Task.isCancelled else {
                if EditorPlugin.verbose {
                    EditorPlugin.logger.debug("\(HoverEditorCoordinator.t)❌ 悬停任务已取消")
                }
                return
            }

            if let cached = cachedHover(line: line, character: character, state: state),
               !cached.content.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                if EditorPlugin.verbose {
                    EditorPlugin.logger.debug("\(HoverEditorCoordinator.t)✅ 缓存命中: 行=\(line) 字符=\(character)")
                }
                if let cachedRange = cached.range {
                    setActiveHoverRange(
                        range: cachedRange,
                        content: cached.content,
                        state: state
                    )
                    // 使用 visibleSymbolRect 减去滚动偏移，得到 overlay 坐标系中的位置
                    let preciseRect = self.visibleSymbolRect(for: cachedRange) ?? symbolRect
                    state.setMouseHover(content: cached.content, symbolRect: preciseRect)
                } else {
                    state.setMouseHover(content: cached.content, symbolRect: symbolRect)
                }
                return
            }

            let hover = await state.lspCoordinator.requestHoverRaw(
                line: line,
                character: character
            )

            if let hover {
                // 详细日志：打印完整的 hover 响应结构
                let contentsType: String
                switch hover.contents {
                case .optionA: contentsType = "optionA(MarkedString)"
                case .optionB(let arr): contentsType = "optionB([MarkedString]) count=\(arr.count)"
                case .optionC(let markup): contentsType = "optionC(MarkupContent) kind=\(markup.kind)"
                }
                if EditorPlugin.verbose {
                EditorPlugin.logger.debug("\(HoverEditorCoordinator.t)LSP 悬停响应: 内容类型=\(contentsType), 范围=\(String(describing: hover.range))")
                }

                // 打印原始内容以便调试
                if EditorPlugin.verbose {
                    switch hover.contents {
                    case .optionA(let marked):
                        switch marked {
                        case .optionA(let str):
                            EditorPlugin.logger.debug("\(HoverEditorCoordinator.t)选项A 内容: \(str)")
                        case .optionB(let lsp):
                            EditorPlugin.logger.debug("\(HoverEditorCoordinator.t)选项A 内容: 语言=\(lsp.language.rawValue), 值=\(lsp.value)")
                        }
                    case .optionB(let array):
                        for (index, marked) in array.enumerated() {
                            switch marked {
                            case .optionA(let str):
                                EditorPlugin.logger.debug("\(HoverEditorCoordinator.t)选项B[\(index)] 内容: \(str)")
                            case .optionB(let lsp):
                                EditorPlugin.logger.debug("\(HoverEditorCoordinator.t)选项B[\(index)] 内容: 语言=\(lsp.language.rawValue), 值=\(lsp.value.prefix(100))")
                            }
                        }
                    case .optionC(let markup):
                        EditorPlugin.logger.debug("\(HoverEditorCoordinator.t)选项C 内容 (种类=\(markup.kind.rawValue)): \(markup.value.prefix(300))")
                    }

                    if let content = self.extractMarkdown(from: hover) {
                        EditorPlugin.logger.debug("\(HoverEditorCoordinator.t)提取的 Markdown (\(content.count) 字符): \(content.prefix(200))")
                    } else {
                        EditorPlugin.logger.debug("\(HoverEditorCoordinator.t)悬停内容提取返回 nil")
                    }
                }
            } else {
                if EditorPlugin.verbose {
                EditorPlugin.logger.debug("\(HoverEditorCoordinator.t)LSP 悬停返回 nil，行=\(line) 字符=\(character)")
                }
            }

            guard let hover, let content = self.extractMarkdown(from: hover), !content.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else {
                if EditorPlugin.verbose {
                EditorPlugin.logger.debug("\(HoverEditorCoordinator.t)悬停守卫失败: LSP 返回空，保留已有悬停")
                }
                // 不清空已有 hover：鼠标可能正在从单词移向 popover 的途中
                // 已有 hover 会在鼠标真正离开 popover 区域时被 handleMouseEvent 中的 cancelHoverIfNeeded 清除
                return
            }

            cacheHoverContent(content, range: hover.range, line: line, character: character, state: state)

            // 优先使用 LSP 返回的 Range 计算精确矩形
            let finalRect: CGRect
            if let lspRange = hover.range {
                setActiveHoverRange(range: lspRange, content: content, state: state)
                finalRect = self.visibleSymbolRect(for: lspRange) ?? symbolRect
            } else {
                finalRect = symbolRect
            }

            state.setMouseHover(content: content, symbolRect: finalRect)
        }
    }

    func cancelHover() {
        if EditorPlugin.verbose {
            EditorPlugin.logger.debug("\(HoverEditorCoordinator.t)🔴 取消悬停被调用")
        }
        hoverTask?.cancel()
        hoverTask = nil
        lastHoverPosition = nil
        activeHoverRange = nil
        state?.clearMouseHover()
    }

    // MARK: - LSP Range → TextView Rect

    /// 将 LSP Range 转换为 textView 坐标系中的矩形（原点在左上角，Y 向下增长）
    /// 返回矩形覆盖整个 range 的第一行（用于 popover 锚定）
    private func rectForLSPRange(_ lspRange: LSPRange) -> CGRect? {
        guard let textView = textViewController?.textView,
              let text = state?.content?.string else { return nil }

        // LSP Range (line, character 是 UTF-16 偏移) → NSTextStorage UTF-16 offset
        guard let startOffset = utf16OffsetForLSPPosition(lspRange.start, in: text),
              let endOffset = utf16OffsetForLSPPosition(lspRange.end, in: text) else {
            return nil
        }

        let nsRange = NSRange(location: startOffset, length: max(endOffset - startOffset, 0))

        // 使用 layoutManager 获取 start offset 处的行位置矩形
        guard let startRect = textView.layoutManager.rectForOffset(nsRange.location) else {
            return nil
        }

        // 如果 range 跨多行或有 end offset，获取 end 位置来计算宽度
        if nsRange.length > 0, let endRect = textView.layoutManager.rectForOffset(max(nsRange.max - 1, nsRange.location)) {
            // 如果在同一行
            if abs(startRect.minY - endRect.minY) < 1.0 {
                return CGRect(
                    x: startRect.minX,
                    y: startRect.minY,
                    width: endRect.maxX - startRect.minX,
                    height: startRect.height
                )
            } else {
                // 跨行：只取第一行的矩形
                return startRect
            }
        }

        return startRect
    }

    /// 获取相对于可见区域的 symbol 矩形（减去滚动偏移）
    /// 这是 overlay 坐标系所需的格式
    private func visibleSymbolRect(for lspRange: LSPRange) -> CGRect? {
        guard let contentRect = rectForLSPRange(lspRange),
              let textView = textViewController?.textView else {
            return nil
        }

        // 减去滚动偏移，得到相对于可见区域原点的坐标
        let scrollOffset = textView.visibleRect.origin
        return CGRect(
            x: contentRect.origin.x - scrollOffset.x,
            y: contentRect.origin.y - scrollOffset.y,
            width: contentRect.width,
            height: contentRect.height
        )
    }

    /// 将 LSP Position (line, character, UTF-16) 转换为 NSString 中的 UTF-16 offset
    private func utf16OffsetForLSPPosition(_ position: Position, in text: String) -> Int? {
        let utf16 = text.utf16
        var currentLine = 0
        var offset = 0

        for (index, unit) in utf16.enumerated() {
            if currentLine == position.line {
                // 当前行，检查 character 是否在范围内
                if offset == position.character {
                    return index
                }
                if unit == 0x0A {
                    // 到达行尾但 character 还没匹配，返回行末
                    return index
                }
            }
            if unit == 0x0A {
                currentLine += 1
                if currentLine > position.line {
                    // 已经越过目标行，返回目标行的末尾
                    return index
                }
                offset = 0
            } else {
                offset += 1
            }
        }

        // 如果到达字符串末尾
        if currentLine == position.line {
            return utf16.count
        }
        return nil
    }

    // MARK: - Markdown 提取

    private func extractMarkdown(from hover: Hover) -> String? {
        switch hover.contents {
        case .optionC(let markup):
            return markup.value
        case .optionA(let marked):
            return parseMarkedString(marked)
        case .optionB(let array):
            return array.compactMap { parseMarkedString($0) }.joined(separator: "\n\n---\n\n")
        }
    }

    private func parseMarkedString(_ marked: MarkedString) -> String? {
        switch marked {
        case .optionA(let str):
            return str
        case .optionB(let lsp):
            return "```\(lsp.language)\n\(lsp.value)\n```"
        }
    }

    // MARK: - Mouse Hover

    private func installMouseMonitorIfNeeded() {
        guard mouseMonitor == nil else { return }
        mouseMonitor = NSEvent.addLocalMonitorForEvents(
            matching: [.mouseMoved, .leftMouseDragged, .leftMouseDown, .rightMouseDown]
        ) { [weak self] event in
            guard let self else { return event }
            self.handleMouseEvent(event)
            return event
        }
    }

    private func removeMouseMonitor() {
        guard let mouseMonitor else { return }
        NSEvent.removeMonitor(mouseMonitor)
        self.mouseMonitor = nil
    }

    /// 安装全局鼠标监听器
    /// 关键用途：当鼠标进入 SwiftUI popover overlay 时，addLocalMonitorForEvents 无法收到事件。
    /// 全局监听器可以捕获所有鼠标移动事件，即使鼠标在 popover 上方。
    private func installGlobalMouseMonitorIfNeeded() {
        guard globalMouseMonitor == nil else { return }
        globalMouseMonitor = NSEvent.addGlobalMonitorForEvents(
            matching: [.mouseMoved, .leftMouseDragged, .leftMouseDown, .rightMouseDown]
        ) { [weak self] event in
            guard let self else { return }
            self.handleGlobalMouseEvent(event)
        }
    }

    private func removeGlobalMouseMonitor() {
        guard let globalMouseMonitor else { return }
        NSEvent.removeMonitor(globalMouseMonitor)
        self.globalMouseMonitor = nil
    }

    /// 处理全局鼠标事件（当鼠标在窗口内但不在 textView 中时触发）
    /// 主要用于检测鼠标是否在 popover 上方，以保持 hover 状态
    private func handleGlobalMouseEvent(_ event: NSEvent) {
        guard let textView = textViewController?.textView, let state else { return }

        // 只在有活跃 hover 时处理全局事件
        guard state.mouseHoverContent != nil else { return }

        let localPoint = textView.convert(event.locationInWindow, from: nil)

        // 如果鼠标在 popover 范围内，保持 hover
        if isMouseInsideHoverPopover(at: localPoint, state: state) {
            if EditorPlugin.verbose {
                EditorPlugin.logger.debug("\(HoverEditorCoordinator.t)🌐 全局鼠标事件: 鼠标在弹窗内，保持悬停")
            }
            return
        }

        // 鼠标不在 popover 内，检查是否在 textView 内
        let visibleRect = textView.visibleRect
        let tolerance: CGFloat = 2.0
        let expandedRect = visibleRect.insetBy(dx: -tolerance, dy: -tolerance)
        if expandedRect.contains(localPoint) {
            // 鼠标回到了 textView 内，让 local monitor 处理
            return
        }

        // 鼠标既不在 popover 也不在 textView 内，取消 hover
        if EditorPlugin.verbose {
            EditorPlugin.logger.debug("\(HoverEditorCoordinator.t)🌐 全局鼠标事件: 鼠标离开弹窗区域，取消悬停")
        }
        cancelHoverIfNeeded()
    }

    private func installKeyMonitorIfNeeded() {
        guard keyMonitor == nil else { return }
        keyMonitor = NSEvent.addLocalMonitorForEvents(matching: [.keyDown]) { [weak self] event in
            guard let self else { return event }
            // Esc
            if event.keyCode == 53 {
                if EditorPlugin.verbose {
                    EditorPlugin.logger.debug("\(HoverEditorCoordinator.t)⌨️ 检测到 Esc 键，取消悬停")
                }
                self.cancelHover()
            }
            return event
        }
    }

    private func removeKeyMonitor() {
        guard let keyMonitor else { return }
        NSEvent.removeMonitor(keyMonitor)
        self.keyMonitor = nil
    }

    private func installScrollObserversIfNeeded() {
        removeScrollObservers()
        guard let textView = textViewController?.textView,
              let clipView = textView.enclosingScrollView?.contentView else { return }

        clipBoundsObserver = NotificationCenter.default.addObserver(
            forName: NSView.boundsDidChangeNotification,
            object: clipView,
            queue: .main
        ) { [weak self] _ in
            guard let self, let state else { return }
            if EditorPlugin.verbose {
                EditorPlugin.logger.debug("\(HoverEditorCoordinator.t)📜 剪辑视图 bounds 变化，检查是否需要取消悬停")
            }
            // 只有在没有活跃悬停或鼠标不在弹窗范围内时才取消
            guard state.mouseHoverContent == nil || state.mouseHoverSymbolRect == .zero else {
                if EditorPlugin.verbose {
                    EditorPlugin.logger.debug("\(HoverEditorCoordinator.t)📜 有活跃悬停，bounds 变化不取消")
                }
                return
            }
            self.cancelHover()
        }

        clipFrameObserver = NotificationCenter.default.addObserver(
            forName: NSView.frameDidChangeNotification,
            object: clipView,
            queue: .main
        ) { [weak self] _ in
            guard let self, let state else { return }
            if EditorPlugin.verbose {
                EditorPlugin.logger.debug("\(HoverEditorCoordinator.t)📐 剪辑视图 frame 变化，检查是否需要取消悬停")
            }
            // 只有在没有活跃悬停或鼠标不在弹窗范围内时才取消
            guard state.mouseHoverContent == nil || state.mouseHoverSymbolRect == .zero else {
                if EditorPlugin.verbose {
                    EditorPlugin.logger.debug("\(HoverEditorCoordinator.t)📐 有活跃悬停，frame 变化不取消")
                }
                return
            }
            self.cancelHover()
        }
    }

    private func removeScrollObservers() {
        if let clipBoundsObserver {
            NotificationCenter.default.removeObserver(clipBoundsObserver)
            self.clipBoundsObserver = nil
        }
        if let clipFrameObserver {
            NotificationCenter.default.removeObserver(clipFrameObserver)
            self.clipFrameObserver = nil
        }
    }

    // MARK: - 取消防抖

    /// 上次取消悬停的时间戳，用于防止边界抖动导致的反复取消
    private var lastCancelHoverAtNs: UInt64 = 0
    /// 取消防抖间隔（纳秒），低于此间隔的取消请求会被忽略
    private static let cancelDebounceIntervalNs: UInt64 = 100_000_000  // 100ms
    /// Popover 最大宽度（与 SourceEditorView 中一致）
    private static let hoverPopoverMaxWidth: CGFloat = 440
    /// Popover 默认高度估算值
    private static let hoverPopoverDefaultHeight: CGFloat = 280
    /// Popover 与 symbol 之间的间距
    private static let hoverPopoverVerticalGap: CGFloat = 4

    /// 计算 popover 的估算范围（textView 本地坐标系）
    /// 当鼠标在该范围内时，不取消 hover（模拟 VS Code 的 hover 保持行为）
    private func estimatedPopoverRect(symbolRect: CGRect, contentHeight: CGFloat) -> CGRect? {
        guard let textView = textViewController?.textView else { return nil }
        let containerSize = textView.visibleRect.size
        let popoverHeight = max(contentHeight, 60)

        // 复现 SourceEditorView.hoverOffset 的 Y 计算逻辑
        let preferredY = symbolRect.minY - popoverHeight - Self.hoverPopoverVerticalGap
        let fallbackY = symbolRect.maxY + Self.hoverPopoverVerticalGap
        let clampedY: CGFloat
        if preferredY >= 4 {
            clampedY = preferredY
        } else {
            clampedY = min(fallbackY, max(containerSize.height - popoverHeight - 4, 4))
        }

        let rect = CGRect(
            x: symbolRect.minX - 16,
            y: clampedY - 12,
            width: Self.hoverPopoverMaxWidth + 32,
            height: popoverHeight + 24
        )

        if EditorPlugin.verbose {
            EditorPlugin.logger.debug("\(HoverEditorCoordinator.t)📐 估算弹框矩形: symbol=\(String(describing: symbolRect)) 弹框高度=\(popoverHeight) 矩形=\(String(describing: rect))")
        }
        return rect
    }

    /// 检查当前鼠标位置是否在 popover 的估算范围内（有 active hover 时）
    private func isMouseInsideHoverPopover(at localPoint: CGPoint, state: EditorState) -> Bool {
        guard let content = state.mouseHoverContent, !content.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else {
            if EditorPlugin.verbose {
                EditorPlugin.logger.debug("\(HoverEditorCoordinator.t)🚫 弹窗检查: 鼠标悬停内容为空，不保持")
            }
            return false
        }
        let symbolRect = state.mouseHoverSymbolRect
        guard symbolRect != .zero else {
            if EditorPlugin.verbose {
                EditorPlugin.logger.debug("\(HoverEditorCoordinator.t)🚫 弹窗检查: 符号矩形为 .zero，不保持")
            }
            return false
        }

        // 关键修复：将 textView 坐标系的 localPoint 转换为 overlay 坐标系
        // state.mouseHoverSymbolRect 是 overlay 坐标（减去了 scrollOffset），
        // 因此 localPoint 也需要减去 scrollOffset 才能在同一坐标系中比较
        let scrollOffset = textViewController?.textView?.visibleRect.origin ?? .zero
        let overlayPoint = CGPoint(
            x: localPoint.x - scrollOffset.x,
            y: localPoint.y - scrollOffset.y
        )

        let estimatedRect = estimatedPopoverRect(symbolRect: symbolRect, contentHeight: Self.hoverPopoverDefaultHeight)
        guard let rect = estimatedRect else { return false }

        // 额外容差：覆盖 symbol 和 popover 之间的通道区域
        let extendedRect = rect.union(symbolRect.insetBy(dx: -8, dy: -8))
        let isInside = extendedRect.contains(overlayPoint)

        if EditorPlugin.verbose {
            EditorPlugin.logger.debug("\(HoverEditorCoordinator.t)🔍 弹窗检查: 鼠标 textView 坐标=\(String(describing: localPoint)) overlay 坐标=\(String(describing: overlayPoint)) 在范围内=\(isInside)")
            EditorPlugin.logger.debug("\(HoverEditorCoordinator.t)🔍 弹窗检查: 扩展矩形=\(String(describing: extendedRect)) scrollOffset=\(String(describing: scrollOffset))")
        }
        return isInside
    }

    private func handleMouseEvent(_ event: NSEvent) {
        guard let textView = textViewController?.textView, let state else { return }
        refreshDocumentContextIfNeeded()

        // 将鼠标位置转换到 textView 的本地坐标系
        let localPoint = textView.convert(event.locationInWindow, from: nil)

        // 检查鼠标是否在 textView 的可见区域内（增加容差避免边界抖动）
        let visibleRect = textView.visibleRect
        let tolerance: CGFloat = 2.0
        let expandedRect = visibleRect.insetBy(dx: -tolerance, dy: -tolerance)
        guard expandedRect.contains(localPoint) else {
            if EditorPlugin.verbose {
                EditorPlugin.logger.debug("\(HoverEditorCoordinator.t)⚠️ 鼠标事件: 鼠标坐标=\(String(describing: localPoint)) 在扩展矩形=\(String(describing: expandedRect)) 之外 可见矩形=\(String(describing: visibleRect))")
            }
            // 鼠标移出了 textView 可见区域
            // 但如果有 active hover 且鼠标在 popover 范围内，则不取消
            if isMouseInsideHoverPopover(at: localPoint, state: state) {
                if EditorPlugin.verbose {
                    EditorPlugin.logger.debug("\(HoverEditorCoordinator.t)✅ 鼠标事件: 鼠标在弹窗范围内，保持悬停")
                }
                return
            }
            if EditorPlugin.verbose {
                EditorPlugin.logger.debug("\(HoverEditorCoordinator.t)❌ 鼠标事件: 鼠标既不在可见区域也不在弹窗内，取消悬停")
            }
            cancelHoverIfNeeded()
            return
        }

        // 使用 layoutManager 从鼠标位置获取文字偏移量（而不是用光标位置）
        guard let characterOffset = textView.layoutManager.textOffsetAtPoint(localPoint) else {
            if EditorPlugin.verbose {
                EditorPlugin.logger.debug("\(HoverEditorCoordinator.t)⚠️ 鼠标事件: 文本偏移量获取返回 nil，鼠标坐标=\(String(describing: localPoint))")
            }
            // 关键修复：鼠标在空白区域时，先检查是否在 popover 范围内，不要立即取消
            if isMouseInsideHoverPopover(at: localPoint, state: state) {
                if EditorPlugin.verbose {
                    EditorPlugin.logger.debug("\(HoverEditorCoordinator.t)✅ 鼠标在空白区域但处于弹窗内，保持悬停")
                }
                return
            }
            cancelHoverIfNeeded()
            return
        }

        // 转换为 LSP Position
        guard let position = lspPosition(forUTF16Offset: characterOffset, in: textView.string) else {
            // 如果无法转换位置，先检查是否在 popover 范围内
            if isMouseInsideHoverPopover(at: localPoint, state: state) {
                return
            }
            cancelHoverIfNeeded()
            return
        }

        // 获取鼠标下字符的矩形（用于 popover 定位）
        // 需要减去滚动偏移，得到 overlay 坐标系中的位置
        let contentRect = textView.layoutManager.rectForOffset(characterOffset)
            ?? CGRect(x: localPoint.x, y: localPoint.y, width: 0, height: 16)
        let scrollOffset = textView.visibleRect.origin
        let characterRect = CGRect(
            x: contentRect.origin.x - scrollOffset.x,
            y: contentRect.origin.y - scrollOffset.y,
            width: contentRect.width,
            height: contentRect.height
        )

        // 如果鼠标在已有的 hover range 内，保持显示（但更新位置以跟随滚动）
        if let activeHover = activeHoverRange,
           isSameDocument(activeHover, state: state),
           contains(position: position, in: activeHover.range),
           !activeHover.content.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
            // 使用 visibleSymbolRect 减去滚动偏移，得到 overlay 坐标系中的位置
            let preciseRect = visibleSymbolRect(for: activeHover.range) ?? characterRect
            state.setMouseHover(
                content: activeHover.content,
                symbolRect: preciseRect
            )
            lastHoverPosition = (position.line, position.character)
            return
        }

        // 如果位置没变，不重复请求
        if let lastHoverPosition,
           lastHoverPosition.line == position.line,
           lastHoverPosition.character == position.character {
            return
        }

        if EditorPlugin.verbose {
            EditorPlugin.logger.debug("\(HoverEditorCoordinator.t)悬停触发: 行=\(position.line) 字符=\(position.character)")
        }
        triggerHover(for: position.line, character: position.character, symbolRect: characterRect)
    }

    /// 防抖取消：避免边界抖动导致的反复取消
    private func cancelHoverIfNeeded() {
        let now = DispatchTime.now().uptimeNanoseconds
        guard now &- lastCancelHoverAtNs >= Self.cancelDebounceIntervalNs else { return }
        lastCancelHoverAtNs = now
        cancelHover()
        if EditorPlugin.verbose {
            EditorPlugin.logger.debug("\(HoverEditorCoordinator.t)鼠标移出可见区域，取消悬停")
        }
    }

    private func lspPosition(forUTF16Offset offset: Int, in text: String) -> Position? {
        guard offset >= 0, offset <= text.utf16.count else { return nil }
        var line = 0
        var character = 0
        var consumed = 0

        for unit in text.utf16 {
            if consumed >= offset { break }
            if unit == 0x0A {
                line += 1
                character = 0
            } else {
                character += 1
            }
            consumed += 1
        }

        return Position(line: line, character: character)
    }

    private func hoverDelay(for line: Int, character: Int) -> UInt64 {
        guard let state else { return Self.defaultHoverDelayNs }
        guard state.mouseHoverContent?.isEmpty == false else { return Self.defaultHoverDelayNs }
        guard let lastHoverPosition, let lastHoverRequestAtNs else { return Self.defaultHoverDelayNs }

        let now = DispatchTime.now().uptimeNanoseconds
        let withinFastWindow = now &- lastHoverRequestAtNs <= Self.fastHoverWindowNs
        let closeToPrevious = lastHoverPosition.line == line &&
            abs(lastHoverPosition.character - character) <= 2

        return (withinFastWindow && closeToPrevious)
            ? Self.fastHoverDelayNs
            : Self.defaultHoverDelayNs
    }

    private func cachedHover(line: Int, character: Int, state: EditorState) -> HoverCacheEntry? {
        guard let key = hoverCacheKey(line: line, character: character, state: state),
              let entry = hoverCache[key] else {
            return nil
        }
        let now = DispatchTime.now().uptimeNanoseconds
        if now &- entry.createdAtNs > Self.hoverCacheTTLNs {
            removeCacheEntry(for: key)
            return nil
        }
        touchCacheKey(key)
        return entry
    }

    private func cacheHoverContent(_ content: String, range: LSPRange?, line: Int, character: Int, state: EditorState) {
        guard let key = hoverCacheKey(line: line, character: character, state: state) else { return }
        removeExpiredCacheEntries()
        let entry = HoverCacheEntry(
            content: content,
            range: range,
            createdAtNs: DispatchTime.now().uptimeNanoseconds
        )
        hoverCache[key] = entry
        touchCacheKey(key)
        trimHoverCacheIfNeeded()
    }

    private func hoverCacheKey(line: Int, character: Int, state: EditorState) -> HoverCacheKey? {
        guard let uri = state.currentFileURL?.absoluteString else { return nil }
        return HoverCacheKey(
            uri: uri,
            line: line,
            character: character,
            documentFingerprint: documentFingerprint(for: state)
        )
    }

    private func documentFingerprint(for state: EditorState) -> Int {
        guard let string = state.content?.string else { return 0 }
        let length = string.utf16.count
        let prefix = String(string.prefix(128))
        let suffix = String(string.suffix(128))
        var hasher = Hasher()
        hasher.combine(length)
        hasher.combine(prefix)
        hasher.combine(suffix)
        return hasher.finalize()
    }

    private func touchCacheKey(_ key: HoverCacheKey) {
        hoverCacheOrder.removeAll { $0 == key }
        hoverCacheOrder.append(key)
    }

    private func trimHoverCacheIfNeeded() {
        while hoverCacheOrder.count > Self.hoverCacheMaxEntries {
            let oldest = hoverCacheOrder.removeFirst()
            hoverCache.removeValue(forKey: oldest)
        }
    }

    private func removeCacheEntry(for key: HoverCacheKey) {
        hoverCache.removeValue(forKey: key)
        hoverCacheOrder.removeAll { $0 == key }
    }

    private func removeExpiredCacheEntries() {
        let now = DispatchTime.now().uptimeNanoseconds
        let expiredKeys = hoverCache.compactMap { key, entry in
            (now &- entry.createdAtNs > Self.hoverCacheTTLNs) ? key : nil
        }
        guard !expiredKeys.isEmpty else { return }
        expiredKeys.forEach(removeCacheEntry(for:))
    }

    private func clearHoverCache() {
        hoverCache.removeAll()
        hoverCacheOrder.removeAll()
        activeHoverRange = nil
    }

    private func setActiveHoverRange(range: LSPRange, content: String, state: EditorState) {
        guard let uri = state.currentFileURL?.absoluteString else { return }
        activeHoverRange = ActiveHoverRange(
            uri: uri,
            documentFingerprint: documentFingerprint(for: state),
            range: range,
            content: content
        )
    }

    private func isSameDocument(_ activeHover: ActiveHoverRange, state: EditorState?) -> Bool {
        guard let state, let uri = state.currentFileURL?.absoluteString else { return false }
        return activeHover.uri == uri && activeHover.documentFingerprint == documentFingerprint(for: state)
    }

    private func contains(position: Position, in range: LSPRange) -> Bool {
        if position.line < range.start.line || position.line > range.end.line {
            return false
        }
        if position.line == range.start.line && position.character < range.start.character {
            return false
        }
        if position.line == range.end.line && position.character >= range.end.character {
            return false
        }
        return true
    }

    private func refreshDocumentContextIfNeeded() {
        let currentURI = state?.currentFileURL?.absoluteString
        if currentURI != lastDocumentURI {
            lastDocumentURI = currentURI
            clearHoverCache()
        }
    }
}
