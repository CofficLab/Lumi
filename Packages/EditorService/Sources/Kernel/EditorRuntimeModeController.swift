import EditorKernel
import Foundation
import EditorSource
import EditorTextView

typealias LSPViewportScheduler = EditorKernel.LSPViewportScheduler

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
        EditorViewportFeaturePolicy.isLongLineProtectionSuppressingSyntaxHighlighting(
            largeFileMode: largeFileMode,
            longestDetectedLine: longestDetectedLine
        )
    }

    static func isViewportSyntaxFeatureEnabled(
        viewportRange: Range<Int>,
        maxLine: Int,
        largeFileMode: LargeFileMode,
        longestDetectedLine: LongestDetectedLine?
    ) -> Bool {
        EditorViewportFeaturePolicy.isViewportSyntaxFeatureEnabled(
            viewportRange: viewportRange,
            maxLine: maxLine,
            largeFileMode: largeFileMode,
            longestDetectedLine: longestDetectedLine
        )
    }

    static func isViewportFeatureEnabled(viewportRange: Range<Int>, maxLine: Int) -> Bool {
        EditorViewportFeaturePolicy.isViewportFeatureEnabled(
            viewportRange: viewportRange,
            maxLine: maxLine
        )
    }

    func isRenderedLine(_ line: Int, renderRange: Range<Int>) -> Bool {
        EditorRenderedRangePolicy.isRenderedLine(line, renderRange: renderRange)
    }

    func isRenderedOffset(
        _ offset: Int,
        renderRange: Range<Int>,
        lineTable: LineOffsetTable
    ) -> Bool {
        EditorRenderedRangePolicy.isRenderedOffset(
            offset,
            renderRange: renderRange,
            lineTable: lineTable
        )
    }

    func intersectsRenderedRange(
        _ range: EditorRange,
        renderRange: Range<Int>,
        lineTable: LineOffsetTable
    ) -> Bool {
        EditorRenderedRangePolicy.intersectsRenderedRange(
            range,
            renderRange: renderRange,
            lineTable: lineTable
        )
    }

    func renderedFindMatches(
        _ matches: [EditorFindMatch],
        renderRange: Range<Int>,
        lineTable: LineOffsetTable
    ) -> [EditorFindMatch] {
        EditorRenderedRangePolicy.renderedFindMatches(
            matches,
            renderRange: renderRange,
            lineTable: lineTable
        )
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
        let visibleRange = EditorRuntimeAvailabilityPolicy.clampedVisibleRange(
            startLine: startLine,
            endLine: endLine,
            totalLines: totalLines
        )
        let clampedTotalLines = max(0, totalLines)
        let clampedStart = visibleRange.lowerBound
        let clampedEnd = visibleRange.upperBound

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
        inlayHintProvider: (any SuperEditorInlayHintProvider)?
    ) {
        cancelPendingInlayHintsRefresh()
        guard lspSupportsInlayHints else { return }
        guard let inlayHintProvider else { return }
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
        inlayHintProvider: (any SuperEditorInlayHintProvider)?
    ) {
        guard lspSupportsInlayHints else { return }
        guard areInlayHintsEnabledInViewport else {
            inlayHintProvider?.clear()
            return
        }
        guard let uri = currentFileURL?.absoluteString else { return }
        guard let focusedTextView else { return }
        guard let range = EditorInlayHintLayout.visibleDocumentLSPRange(in: focusedTextView) else { return }
        Task { @MainActor in
            await inlayHintProvider?.requestHints(
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
        documentHighlightProvider: (any SuperEditorDocumentHighlightProvider)?,
        signatureHelpProvider: (any SuperEditorSignatureHelpProvider)?,
        codeActionProvider: (any SuperEditorCodeActionProvider)?
    ) {
        guard EditorRuntimeAvailabilityPolicy.shouldClearTransientProviders(
            isPrimaryCursorRendered: isPrimaryCursorRendered
        ) else { return }
        documentHighlightProvider?.clear()
        signatureHelpProvider?.clear()
        codeActionProvider?.clear()
    }

    func handleDocumentHighlightRuntimeAvailabilityChange(
        _ isEnabled: Bool,
        documentHighlightProvider: (any SuperEditorDocumentHighlightProvider)?
    ) {
        guard EditorRuntimeAvailabilityPolicy.shouldClearProvider(isEnabled: isEnabled) else { return }
        documentHighlightProvider?.clear()
    }

    func handleSignatureHelpRuntimeAvailabilityChange(
        _ isEnabled: Bool,
        signatureHelpProvider: (any SuperEditorSignatureHelpProvider)?
    ) {
        guard EditorRuntimeAvailabilityPolicy.shouldClearProvider(isEnabled: isEnabled) else { return }
        signatureHelpProvider?.clear()
    }

    func handleCodeActionRuntimeAvailabilityChange(
        _ isEnabled: Bool,
        codeActionProvider: (any SuperEditorCodeActionProvider)?
    ) {
        guard EditorRuntimeAvailabilityPolicy.shouldClearProvider(isEnabled: isEnabled) else { return }
        codeActionProvider?.clear()
    }

    func cancelPendingInlayHintsRefresh() {
        inlayHintRefreshTask?.cancel()
        inlayHintRefreshTask = nil
    }
}
