import Foundation
import AppKit
import CodeEditSourceEditor
import CodeEditTextView
import LanguageServerProtocol

/// LSP 悬停协调器（轻量版）
/// 不创建任何 NSView（避免 AppKit + SwiftUI 混合的 Layout 循环崩溃）
/// 仅作为 hover 请求的集中管理器
@MainActor
final class HoverEditorCoordinator: TextViewCoordinator {
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
            installKeyMonitorIfNeeded()
        }
    }

    nonisolated func textViewDidChangeSelection(controller: TextViewController) {
        Task { @MainActor [weak self] in
            guard let self else { return }
            let cursor = controller.cursorPositions.first?.start
            let line = cursor.map { max($0.line - 1, 0) } ?? 0
            let character = cursor.map { max($0.column - 1, 0) } ?? 0
            triggerHover(for: line, character: character, point: state?.mouseHoverPoint ?? .zero)
        }
    }

    nonisolated func destroy() {
        Task { @MainActor [weak self] in
            self?.hoverTask?.cancel()
            self?.removeMouseMonitor()
            self?.removeKeyMonitor()
            self?.removeScrollObservers()
            self?.lastHoverPosition = nil
            self?.textViewController = nil
            self?.state = nil
        }
    }

    // MARK: - 公共 API

    /// 当光标移动时调用，触发 hover 请求
    func triggerHover(for line: Int, character: Int, point: CGPoint) {
        refreshDocumentContextIfNeeded()
        let delay = hoverDelay(for: line, character: character)
        hoverTask?.cancel()
        lastHoverPosition = (line, character)
        lastHoverRequestAtNs = DispatchTime.now().uptimeNanoseconds
        hoverTask = Task { [weak self] in
            guard let self, let state else { return }

            try? await Task.sleep(nanoseconds: delay)
            guard !Task.isCancelled else { return }

            if let cached = cachedHover(line: line, character: character, state: state),
               !cached.content.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                if let cachedRange = cached.range {
                    setActiveHoverRange(
                        range: cachedRange,
                        content: cached.content,
                        state: state
                    )
                }
                state.setMouseHover(content: cached.content, point: point, line: line, character: character)
                return
            }

            let hover = await state.lspCoordinator.requestHoverRaw(
                line: line,
                character: character
            )

            guard let hover, let content = self.extractMarkdown(from: hover), !content.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else {
                state.clearMouseHover()
                return
            }

            cacheHoverContent(content, range: hover.range, line: line, character: character, state: state)
            if let range = hover.range {
                setActiveHoverRange(range: range, content: content, state: state)
            }
            state.setMouseHover(content: content, point: point, line: line, character: character)
        }
    }

    func cancelHover() {
        hoverTask?.cancel()
        hoverTask = nil
        lastHoverPosition = nil
        activeHoverRange = nil
        state?.clearMouseHover()
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

    private func installKeyMonitorIfNeeded() {
        guard keyMonitor == nil else { return }
        keyMonitor = NSEvent.addLocalMonitorForEvents(matching: [.keyDown]) { [weak self] event in
            guard let self else { return event }
            // Esc
            if event.keyCode == 53 {
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
            self?.cancelHover()
        }

        clipFrameObserver = NotificationCenter.default.addObserver(
            forName: NSView.frameDidChangeNotification,
            object: clipView,
            queue: .main
        ) { [weak self] _ in
            self?.cancelHover()
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

    private func handleMouseEvent(_ event: NSEvent) {
        guard let textView = textViewController?.textView else { return }
        refreshDocumentContextIfNeeded()
        let localPoint = textView.convert(event.locationInWindow, from: nil)
        guard textView.bounds.contains(localPoint) else {
            cancelHover()
            lastHoverPosition = nil
            return
        }

        let insertionIndex = textView.selectionManager.textSelections.first?.range.location ?? NSNotFound
        guard insertionIndex != NSNotFound else {
            cancelHover()
            lastHoverPosition = nil
            return
        }

        guard let position = lspPosition(forUTF16Offset: insertionIndex, in: textView.string) else {
            cancelHover()
            lastHoverPosition = nil
            return
        }

        let pointFromTop = CGPoint(
            x: max(localPoint.x, 0),
            y: max(localPoint.y, 0)
        )

        if let activeHover = activeHoverRange,
           isSameDocument(activeHover, state: state),
           contains(position: position, in: activeHover.range),
           !activeHover.content.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
            state?.setMouseHover(
                content: activeHover.content,
                point: pointFromTop,
                line: position.line,
                character: position.character
            )
            lastHoverPosition = (position.line, position.character)
            return
        }

        if let lastHoverPosition,
           lastHoverPosition.line == position.line,
           lastHoverPosition.character == position.character {
            return
        }

        triggerHover(for: position.line, character: position.character, point: pointFromTop)
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
