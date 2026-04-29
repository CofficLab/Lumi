import Foundation
import CodeEditSourceEditor
import CodeEditTextView

@MainActor
final class EditorRuntimeModeController {
    let viewportRenderController = ViewportRenderController()
    let lspViewportScheduler = LSPViewportScheduler()

    private var inlayHintRefreshTask: Task<Void, Never>?

    struct ViewportObservation {
        let visibleLineRange: Range<Int>
        let renderLineRange: Range<Int>
    }

    static func isLongLineProtectionSuppressingSyntaxHighlighting(
        largeFileMode: LargeFileMode,
        longestDetectedLine: LongestDetectedLine?
    ) -> Bool {
        largeFileMode.isLongLineProtectionEnabled && longestDetectedLine != nil
    }

    static func isViewportSyntaxFeatureEnabled(
        viewportRange: Range<Int>,
        maxLine: Int,
        largeFileMode: LargeFileMode,
        longestDetectedLine: LongestDetectedLine?
    ) -> Bool {
        guard !isLongLineProtectionSuppressingSyntaxHighlighting(
            largeFileMode: largeFileMode,
            longestDetectedLine: longestDetectedLine
        ) else {
            return false
        }
        return isViewportFeatureEnabled(
            viewportRange: viewportRange,
            maxLine: maxLine
        )
    }

    static func isViewportFeatureEnabled(viewportRange: Range<Int>, maxLine: Int) -> Bool {
        if maxLine == .max {
            return true
        }
        if viewportRange.isEmpty {
            return true
        }
        return viewportRange.lowerBound < maxLine
    }

    func isRenderedLine(_ line: Int, renderRange: Range<Int>) -> Bool {
        guard !renderRange.isEmpty else { return true }
        return renderRange.contains(max(line, 0))
    }

    func isRenderedOffset(
        _ offset: Int,
        renderRange: Range<Int>,
        lineTable: LineOffsetTable
    ) -> Bool {
        guard let line = lineTable.lineContaining(utf16Offset: max(offset, 0)) else {
            return true
        }
        return isRenderedLine(line, renderRange: renderRange)
    }

    func intersectsRenderedRange(
        _ range: EditorRange,
        renderRange: Range<Int>,
        lineTable: LineOffsetTable
    ) -> Bool {
        guard !renderRange.isEmpty else { return true }

        let startOffset = max(range.location, 0)
        let endOffset = max(range.location + max(range.length - 1, 0), startOffset)

        guard let startLine = lineTable.lineContaining(utf16Offset: startOffset),
              let endLine = lineTable.lineContaining(utf16Offset: endOffset) else {
            return true
        }

        return (startLine..<(endLine + 1)).overlaps(renderRange)
    }

    func renderedFindMatches(
        _ matches: [EditorFindMatch],
        renderRange: Range<Int>,
        lineTable: LineOffsetTable
    ) -> [EditorFindMatch] {
        matches.filter { intersectsRenderedRange($0.range, renderRange: renderRange, lineTable: lineTable) }
    }

    func renderedInlayHints(
        _ hints: [InlayHintItem],
        renderRange: Range<Int>
    ) -> [InlayHintItem] {
        hints.filter { isRenderedLine($0.line, renderRange: renderRange) }
    }

    func applyViewportObservation(
        startLine: Int,
        endLine: Int,
        totalLines: Int,
        areInlayHintsEnabled: Bool,
        requestInlayHints: @escaping @MainActor () -> Void,
        clearInlayHints: @escaping @MainActor () -> Void
    ) -> ViewportObservation {
        let clampedTotalLines = max(0, totalLines)
        let clampedStart = max(0, min(startLine, clampedTotalLines))
        let clampedEnd = max(clampedStart, min(endLine, clampedTotalLines))

        viewportRenderController.updateVisibleRange(
            startLine: clampedStart,
            endLine: clampedEnd,
            totalLines: clampedTotalLines
        )

        lspViewportScheduler.recordViewport(startLine: clampedStart, endLine: clampedEnd)

        if areInlayHintsEnabled {
            lspViewportScheduler.scheduleInlayHints {
                requestInlayHints()
            }
        } else {
            cancelPendingInlayHintsRefresh()
            clearInlayHints()
        }

        return ViewportObservation(
            visibleLineRange: clampedStart..<clampedEnd,
            renderLineRange: viewportRenderController.renderStartLine..<viewportRenderController.renderEndLine
        )
    }

    func resetViewportObservation(totalLines: Int = 0) -> ViewportObservation {
        viewportRenderController.updateVisibleRange(startLine: 0, endLine: 0, totalLines: max(0, totalLines))
        lspViewportScheduler.cancelAll()
        cancelPendingInlayHintsRefresh()
        return ViewportObservation(
            visibleLineRange: 0..<0,
            renderLineRange: 0..<0
        )
    }

    func scheduleInlayHintsRefreshIfNeeded(
        textView: TextView?,
        lspSupportsInlayHints: Bool,
        isInlayHintsEnabledInViewport: @escaping @MainActor () -> Bool,
        currentFileURL: @escaping @MainActor () -> URL?,
        inlayHintProvider: InlayHintProvider
    ) {
        cancelPendingInlayHintsRefresh()
        guard lspSupportsInlayHints else { return }
        guard isInlayHintsEnabledInViewport() else {
            inlayHintProvider.clear()
            return
        }
        guard currentFileURL() != nil else { return }
        let uriSnapshot = currentFileURL()?.absoluteString
        inlayHintRefreshTask = Task { @MainActor [weak textView] in
            try? await Task.sleep(for: .milliseconds(380))
            guard !Task.isCancelled else { return }
            guard isInlayHintsEnabledInViewport() else {
                inlayHintProvider.clear()
                return
            }
            guard let uri = uriSnapshot ?? currentFileURL()?.absoluteString else { return }
            guard let textView else { return }
            guard let range = EditorInlayHintLayout.visibleDocumentLSPRange(in: textView) else { return }
            await inlayHintProvider.requestHints(
                uri: uri,
                startLine: range.start.line,
                startCharacter: range.start.character,
                endLine: range.end.line,
                endCharacter: range.end.character
            )
        }
    }

    func requestInlayHintsForVisibleRange(
        lspSupportsInlayHints: Bool,
        areInlayHintsEnabledInViewport: Bool,
        currentFileURL: URL?,
        focusedTextView: TextView?,
        inlayHintProvider: InlayHintProvider
    ) {
        guard lspSupportsInlayHints else { return }
        guard areInlayHintsEnabledInViewport else {
            inlayHintProvider.clear()
            return
        }
        guard let uri = currentFileURL?.absoluteString else { return }
        guard let focusedTextView else { return }
        guard let range = EditorInlayHintLayout.visibleDocumentLSPRange(in: focusedTextView) else { return }
        Task { @MainActor in
            await inlayHintProvider.requestHints(
                uri: uri,
                startLine: range.start.line,
                startCharacter: range.start.character,
                endLine: range.end.line,
                endCharacter: range.end.character
            )
        }
    }

    func handleViewportRuntimeTransition(
        isPrimaryCursorRendered: Bool,
        documentHighlightProvider: DocumentHighlightProvider,
        signatureHelpProvider: SignatureHelpProvider,
        codeActionProvider: CodeActionProvider
    ) {
        guard !isPrimaryCursorRendered else { return }
        documentHighlightProvider.clear()
        signatureHelpProvider.clear()
        codeActionProvider.clear()
    }

    func handleDocumentHighlightRuntimeAvailabilityChange(
        _ isEnabled: Bool,
        documentHighlightProvider: DocumentHighlightProvider
    ) {
        guard !isEnabled else { return }
        documentHighlightProvider.clear()
    }

    func handleSignatureHelpRuntimeAvailabilityChange(
        _ isEnabled: Bool,
        signatureHelpProvider: SignatureHelpProvider
    ) {
        guard !isEnabled else { return }
        signatureHelpProvider.clear()
    }

    func handleCodeActionRuntimeAvailabilityChange(
        _ isEnabled: Bool,
        codeActionProvider: CodeActionProvider
    ) {
        guard !isEnabled else { return }
        codeActionProvider.clear()
    }

    func cancelPendingInlayHintsRefresh() {
        inlayHintRefreshTask?.cancel()
        inlayHintRefreshTask = nil
    }
}
