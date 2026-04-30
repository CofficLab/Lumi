import Foundation
import CoreGraphics
import SwiftUI
import CodeEditSourceEditor
import CodeEditTextView
import LanguageServerProtocol

@MainActor
final class EditorOverlayController {
    private struct GutterSuggestionLaneKey: Hashable {
        let line: Int
        let lane: Int
    }

    func surfaceHighlights(
        matches: [EditorFindMatch],
        selectedRange: EditorRange?,
        bracketMatch: BracketMatchResult?,
        cursorLine: Int,
        isPrimaryCursorRendered: Bool,
        textView: TextView,
        lineTable: LineOffsetTable,
        theme: EditorTheme?
    ) -> [EditorSurfaceHighlight] {
        let palette = EditorSurfaceOverlayPalette(theme: theme)
        let seeds = currentLineHighlightSeeds(
            cursorLine: cursorLine,
            isPrimaryCursorRendered: isPrimaryCursorRendered,
            textView: textView,
            lineTable: lineTable
        ) + findMatchHighlightSeeds(
            matches: matches,
            selectedRange: selectedRange,
            textView: textView,
            visibleRect: textView.visibleRect
        ) + bracketHighlightSeeds(
            match: bracketMatch,
            textView: textView
        )

        return seeds
            .map { seed in
                EditorSurfaceHighlight(
                    kind: seed.kind,
                    rect: seed.rect,
                    style: palette.style(for: seed.kind)
                )
            }
            .sorted { lhs, rhs in
                lhs.style.zIndex < rhs.style.zIndex
            }
    }

    func currentLineHighlightSeeds(
        cursorLine: Int,
        isPrimaryCursorRendered: Bool,
        textView: TextView,
        lineTable: LineOffsetTable
    ) -> [EditorSurfaceHighlightSeed] {
        guard isPrimaryCursorRendered,
              cursorLine > 0,
              let lineStart = lineTable.lineStart(line: cursorLine - 1),
              let lineRect = textView.layoutManager.rectForOffset(lineStart) else {
            return []
        }

        let visibleRect = textView.visibleRect
        let overlayRect = CGRect(
            x: 0,
            y: lineRect.minY - visibleRect.origin.y,
            width: visibleRect.width,
            height: max(lineRect.height, 2)
        )
        let clippedVisibleRect = CGRect(
            x: 0,
            y: 0,
            width: visibleRect.width,
            height: visibleRect.height
        ).insetBy(dx: 0, dy: -2)
        guard overlayRect.intersects(clippedVisibleRect) else {
            return []
        }

        return [EditorSurfaceHighlightSeed(kind: .currentLine, rect: overlayRect)]
    }

    func findMatchHighlightSeeds(
        matches: [EditorFindMatch],
        selectedRange: EditorRange?,
        textView: TextView,
        visibleRect: CGRect
    ) -> [EditorSurfaceHighlightSeed] {
        matches.compactMap { match in
            guard let rect = findMatchOverlayRect(
                for: match.range,
                in: textView,
                visibleRect: visibleRect
            ) else {
                return nil
            }

            return EditorSurfaceHighlightSeed(
                kind: match.range == selectedRange ? .currentMatch : .findMatch,
                rect: rect
            )
        }
    }

    func inlinePresentations(
        diagnostics: [Diagnostic],
        selectedDiagnostic: Diagnostic?,
        inlayHints: [InlayHintItem],
        currentMatch: EditorFindMatch?,
        replacementText: String?,
        cursorLine: Int,
        textView: TextView,
        lineTable: LineOffsetTable,
        containerSize: CGSize,
        style: EditorInlinePresentationStyle = .standard
    ) -> [EditorInlinePresentation] {
        guard cursorLine > 0,
              let lineStart = lineTable.lineStart(line: cursorLine - 1),
              let lineRect = textView.layoutManager.rectForOffset(lineStart) else {
            return []
        }

        let visibleRect = textView.visibleRect
        let lineY = lineRect.minY - visibleRect.origin.y + 2
        let baseX = lineRect.minX - visibleRect.origin.x + 28
        var presentations: [EditorInlinePresentation] = []
        var lineSlot = 0

        if let diagnostic = inlineDiagnostic(
            diagnostics: diagnostics,
            selectedDiagnostic: selectedDiagnostic,
            cursorLine: cursorLine
        ) {
            let level = diagnosticSeverityLevel(diagnostic.severity)
            let title = clampedInlineText(diagnostic.message, limit: 40)
            let detail = diagnostic.source
            presentations.append(
                buildInlinePresentation(
                    kind: .message(level),
                    iconName: inlineDiagnosticIcon(for: level),
                    title: title,
                    detail: detail,
                    badgeText: inlineDiagnosticBadge(for: diagnostic),
                    preferredOrigin: CGPoint(
                        x: baseX,
                        y: lineY + CGFloat(lineSlot) * (inlineCardHeight(detail: detail) + style.lineGap)
                    ),
                    containerSize: containerSize,
                    style: style
                )
            )
            lineSlot += 1
        }

        if let hint = inlayHints.first(where: { $0.line == cursorLine - 1 }) {
            let title = clampedInlineText(hint.text, limit: 36)
            presentations.append(
                buildInlinePresentation(
                    kind: .value,
                    iconName: "text.alignleft",
                    title: title,
                    detail: nil,
                    badgeText: hint.isTypeHint ? "TYPE" : (hint.isParameterHint ? "PARAM" : "VALUE"),
                    preferredOrigin: CGPoint(
                        x: baseX,
                        y: lineY + CGFloat(lineSlot) * (inlineCardHeight(detail: nil) + style.lineGap)
                    ),
                    containerSize: containerSize,
                    style: style
                )
            )
        }

        if let currentMatch,
           let replacementText,
           !replacementText.isEmpty,
           let matchRect = findMatchOverlayRect(
                for: currentMatch.range,
                in: textView,
                visibleRect: visibleRect
           ) {
            let title = clampedInlineText(replacementText, limit: 28)
            presentations.append(
                buildInlinePresentation(
                    kind: .diff,
                    iconName: "arrow.triangle.2.circlepath",
                    title: title,
                    detail: nil,
                    badgeText: "REPLACE",
                    preferredOrigin: CGPoint(x: matchRect.maxX + style.inlineGap, y: matchRect.minY - 2),
                    containerSize: containerSize,
                    style: style
                )
            )
        }

        return presentations
    }

    func gutterDecorations(
        diagnostics: [Diagnostic],
        selectedDiagnostic: Diagnostic?,
        documentSymbols: [EditorDocumentSymbolItem],
        extensionSuggestions: [EditorGutterDecorationSuggestion],
        textView: TextView,
        lineTable: LineOffsetTable,
        renderRange: Range<Int>,
        style: EditorGutterDecorationStyle = .standard
    ) -> [EditorGutterDecoration] {
        let suggestions = builtinDiagnosticGutterSuggestions(
            diagnostics: diagnostics,
            selectedDiagnostic: selectedDiagnostic
        ) + builtinSymbolGutterSuggestions(
            documentSymbols: documentSymbols
        ) + extensionSuggestions

        let visibleRect = textView.visibleRect
        let resolvedSuggestions = coalescedGutterSuggestions(suggestions)

        return resolvedSuggestions.compactMap { suggestion in
            let zeroBasedLine = max(suggestion.line - 1, 0)
            guard renderRange.isEmpty || renderRange.contains(zeroBasedLine),
                  let lineStart = lineTable.lineStart(line: zeroBasedLine),
                  let lineRect = textView.layoutManager.rectForOffset(lineStart) else {
                return nil
            }

            let resolvedStyle = style.resolvedStyle(for: suggestion.kind)
            let rect = CGRect(
                x: style.baseX + CGFloat(suggestion.lane) * style.laneSpacing,
                y: lineRect.midY - visibleRect.origin.y - resolvedStyle.size.height / 2,
                width: resolvedStyle.size.width,
                height: resolvedStyle.size.height
            )

            let clipRect = CGRect(origin: .zero, size: visibleRect.size).insetBy(dx: -style.outerPadding, dy: -style.outerPadding)
            guard rect.intersects(clipRect) else { return nil }

            return EditorGutterDecoration(
                id: "\(suggestion.line):\(suggestion.lane):\(suggestion.id)",
                line: suggestion.line,
                lane: suggestion.lane,
                kind: suggestion.kind,
                rect: rect,
                style: resolvedStyle,
                badgeText: suggestion.badgeText,
                symbolName: gutterSymbolName(for: suggestion.kind)
            )
        }
    }

    func bracketHighlightSeeds(
        match: BracketMatchResult?,
        textView: TextView
    ) -> [EditorSurfaceHighlightSeed] {
        guard let match,
              let openRect = textView.layoutManager.rectForOffset(match.openOffset),
              let closeRect = textView.layoutManager.rectForOffset(match.closeOffset) else {
            return []
        }

        let visibleRect = textView.visibleRect
        let openOverlayRect = CGRect(
            x: openRect.origin.x - visibleRect.origin.x,
            y: openRect.origin.y - visibleRect.origin.y,
            width: max(openRect.width, 3),
            height: max(openRect.height, 2)
        )
        let closeOverlayRect = CGRect(
            x: closeRect.origin.x - visibleRect.origin.x,
            y: closeRect.origin.y - visibleRect.origin.y,
            width: max(closeRect.width, 3),
            height: max(closeRect.height, 2)
        )

        let expandedVisibleRect = visibleRect.offsetBy(dx: -visibleRect.origin.x, dy: -visibleRect.origin.y)
            .insetBy(dx: -4, dy: -4)
        guard openOverlayRect.intersects(expandedVisibleRect) ||
                closeOverlayRect.intersects(expandedVisibleRect) else {
            return []
        }

        return [
            EditorSurfaceHighlightSeed(kind: .bracketMatch, rect: openOverlayRect),
            EditorSurfaceHighlightSeed(kind: .bracketMatch, rect: closeOverlayRect),
        ]
    }

    func shouldPresentHoverOverlay(
        areHoversEnabled: Bool,
        hasActiveHover: Bool,
        hoverText: String?
    ) -> Bool {
        areHoversEnabled &&
        hasActiveHover &&
        !(hoverText?.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty ?? true)
    }

    func hoverOverlayText(
        shouldPresent: Bool,
        hoverText: String?
    ) -> String? {
        guard shouldPresent else { return nil }
        return hoverText?.trimmingCharacters(in: .whitespacesAndNewlines)
    }

    func hoverOverlayOffset(
        symbolRect: CGRect,
        containerSize: CGSize,
        popoverSize: CGSize,
        style: EditorHoverOverlayStyle = .standard
    ) -> EditorHoverOverlayPlacement {
        let width = min(max(popoverSize.width, min(style.maxWidth, 220)), style.maxWidth)
        let height = min(max(popoverSize.height, style.minHeight), style.maxHeight)
        let outerPadding = style.outerPadding
        let availableAbove = symbolRect.minY - outerPadding
        let availableBelow = containerSize.height - symbolRect.maxY - outerPadding
        let presentAbove = availableAbove >= height + style.verticalGap || availableAbove >= availableBelow

        let anchor: SwiftUI.UnitPoint = presentAbove ? .bottomLeading : .topLeading
        let targetY = presentAbove
            ? max(outerPadding, symbolRect.minY - style.verticalGap)
            : min(containerSize.height - outerPadding, symbolRect.maxY + style.verticalGap)

        let minX = outerPadding
        let maxX = max(outerPadding, containerSize.width - width - outerPadding)
        let preferredX = min(max(symbolRect.minX - 12, minX), maxX)

        let originY = presentAbove
            ? max(outerPadding, targetY - height)
            : targetY

        return EditorHoverOverlayPlacement(
            anchor: anchor,
            origin: CGPoint(x: preferredX, y: originY),
            cardSize: CGSize(width: width, height: height),
            isPresentedAboveSymbol: presentAbove
        )
    }

    func shouldPresentSignatureHelpOverlay(
        areSignatureHelpEnabled: Bool,
        isPrimaryCursorRendered: Bool,
        currentHelp: SignatureHelpItem?
    ) -> Bool {
        areSignatureHelpEnabled && isPrimaryCursorRendered && currentHelp != nil
    }

    func signatureHelpOverlayItem(
        shouldPresent: Bool,
        currentHelp: SignatureHelpItem?
    ) -> SignatureHelpItem? {
        shouldPresent ? currentHelp : nil
    }

    func shouldPresentCodeActionOverlay(
        areCodeActionsEnabled: Bool,
        isVisible: Bool,
        isPrimaryCursorRendered: Bool
    ) -> Bool {
        areCodeActionsEnabled && isVisible && isPrimaryCursorRendered
    }

    func codeActionOverlayActions(
        shouldPresent: Bool,
        actions: [CodeActionItem]
    ) -> [CodeActionItem] {
        shouldPresent ? actions : []
    }

    func codeActionIndicatorPlacement(
        cursorLine: Int,
        textView: TextView,
        lineTable: LineOffsetTable,
        containerSize: CGSize,
        style: EditorCodeActionOverlayStyle = .standard
    ) -> EditorCodeActionIndicatorPlacement? {
        guard cursorLine > 0,
              let lineStart = lineTable.lineStart(line: cursorLine - 1),
              let lineRect = textView.layoutManager.rectForOffset(lineStart) else {
            return nil
        }

        let visibleRect = textView.visibleRect
        let lineY = lineRect.minY - visibleRect.origin.y
        let rowHeight = max(lineRect.height, style.indicatorSize)
        let indicatorX = max(4, lineRect.minX - visibleRect.origin.x - style.indicatorInsetX)
        let indicatorY = max(4, lineY + (rowHeight - style.indicatorSize) / 2)
        let panelX = min(
            max(8, indicatorX + style.indicatorSize + style.panelGap),
            max(8, containerSize.width - style.panelWidth - 8)
        )
        let estimatedPanelHeight = min(CGFloat(visibleRect.height) * 0.6, style.maxPanelHeight)
        let panelY = min(
            max(8, lineY - 6),
            max(8, containerSize.height - estimatedPanelHeight - 8)
        )

        return EditorCodeActionIndicatorPlacement(
            origin: CGPoint(x: indicatorX, y: indicatorY),
            panelOrigin: CGPoint(x: panelX, y: panelY)
        )
    }

    func secondaryCursorHighlights(
        selections: [MultiCursorSelection],
        textView: TextView,
        visibleRect: CGRect
    ) -> [EditorMultiCursorHighlight] {
        selections.compactMap { selection in
            if selection.length == 0 {
                guard let caretRect = textView.layoutManager.rectForOffset(selection.location) else {
                    return nil
                }
                let overlayRect = CGRect(
                    x: caretRect.minX - visibleRect.origin.x,
                    y: caretRect.minY - visibleRect.origin.y,
                    width: 2,
                    height: max(caretRect.height, 10)
                )
                guard overlayRect.intersects(CGRect(origin: .zero, size: visibleRect.size).insetBy(dx: -2, dy: -2)) else {
                    return nil
                }
                return EditorMultiCursorHighlight(kind: .secondaryCaret, rect: overlayRect)
            }

            guard let selectionRect = findMatchOverlayRect(
                for: EditorRange(location: selection.location, length: selection.length),
                in: textView,
                visibleRect: visibleRect
            ) else {
                return nil
            }
            return EditorMultiCursorHighlight(kind: .secondarySelection, rect: selectionRect)
        }
    }

    private func findMatchOverlayRect(
        for range: EditorRange,
        in textView: TextView,
        visibleRect: CGRect
    ) -> CGRect? {
        guard let startRect = textView.layoutManager.rectForOffset(range.location) else {
            return nil
        }

        let contentRect: CGRect
        if range.length > 0,
           let endRect = textView.layoutManager.rectForOffset(max(range.location + range.length - 1, range.location)) {
            if abs(startRect.minY - endRect.minY) < 1.0 {
                contentRect = CGRect(
                    x: startRect.minX,
                    y: startRect.minY,
                    width: max(endRect.maxX - startRect.minX, startRect.width),
                    height: max(startRect.height, endRect.height)
                )
            } else {
                contentRect = startRect
            }
        } else {
            contentRect = startRect
        }

        guard contentRect.intersects(visibleRect) else { return nil }

        return CGRect(
            x: contentRect.origin.x - visibleRect.origin.x,
            y: contentRect.origin.y - visibleRect.origin.y,
            width: contentRect.width,
            height: contentRect.height
        )
    }

    private func buildInlinePresentation(
        kind: EditorInlinePresentationKind,
        iconName: String,
        title: String,
        detail: String?,
        badgeText: String?,
        preferredOrigin: CGPoint,
        containerSize: CGSize,
        style: EditorInlinePresentationStyle
    ) -> EditorInlinePresentation {
        let cardWidth = inlineCardWidth(
            title: title,
            detail: detail,
            badgeText: badgeText,
            maxWidth: style.maxWidth
        )
        let cardHeight = inlineCardHeight(detail: detail)
        let origin = clampInlineOrigin(
            preferredOrigin,
            size: CGSize(width: cardWidth, height: cardHeight),
            containerSize: containerSize,
            outerPadding: style.outerPadding
        )
        return EditorInlinePresentation(
            id: "\(iconName)-\(title)-\(badgeText ?? "")-\(Int(origin.x))-\(Int(origin.y))",
            kind: kind,
            origin: origin,
            size: CGSize(width: cardWidth, height: cardHeight),
            iconName: iconName,
            title: title,
            detail: detail,
            badgeText: badgeText,
            style: style.resolvedStyle(for: kind)
        )
    }

    private func inlineDiagnostic(
        diagnostics: [Diagnostic],
        selectedDiagnostic: Diagnostic?,
        cursorLine: Int
    ) -> Diagnostic? {
        if let selectedDiagnostic,
           diagnostic(selectedDiagnostic, covers: cursorLine) {
            return selectedDiagnostic
        }
        return diagnostics.first { diagnostic($0, covers: cursorLine) }
    }

    private func diagnostic(_ diagnostic: Diagnostic, covers line: Int) -> Bool {
        let zeroBasedLine = max(line - 1, 0)
        return Int(diagnostic.range.start.line) <= zeroBasedLine &&
        zeroBasedLine <= Int(diagnostic.range.end.line)
    }

    private func diagnosticSeverityLevel(_ severity: DiagnosticSeverity?) -> EditorStatusLevel {
        switch severity {
        case .error:
            return .error
        case .warning:
            return .warning
        default:
            return .info
        }
    }

    private func inlineDiagnosticIcon(for level: EditorStatusLevel) -> String {
        switch level {
        case .error:
            return "exclamationmark.octagon.fill"
        case .warning:
            return "exclamationmark.triangle.fill"
        case .success:
            return "checkmark.circle.fill"
        case .info:
            return "info.circle.fill"
        }
    }

    private func inlineDiagnosticBadge(for diagnostic: Diagnostic) -> String {
        switch diagnostic.severity {
        case .error:
            return "ERROR"
        case .warning:
            return "WARN"
        case .information:
            return "INFO"
        case .hint:
            return "HINT"
        default:
            return "LSP"
        }
    }

    private func inlineCardWidth(
        title: String,
        detail: String?,
        badgeText: String?,
        maxWidth: CGFloat
    ) -> CGFloat {
        let titleWidth = CGFloat(title.count) * 6.2
        let detailWidth = CGFloat(detail?.count ?? 0) * 5.2
        let badgeWidth = CGFloat((badgeText?.count ?? 0) * 6 + 22)
        return min(max(110, max(titleWidth, detailWidth) + badgeWidth + 40), maxWidth)
    }

    private func inlineCardHeight(detail: String?) -> CGFloat {
        detail == nil ? 24 : 38
    }

    private func clampInlineOrigin(
        _ preferredOrigin: CGPoint,
        size: CGSize,
        containerSize: CGSize,
        outerPadding: CGFloat
    ) -> CGPoint {
        CGPoint(
            x: min(
                max(outerPadding, preferredOrigin.x),
                max(outerPadding, containerSize.width - size.width - outerPadding)
            ),
            y: min(
                max(outerPadding, preferredOrigin.y),
                max(outerPadding, containerSize.height - size.height - outerPadding)
            )
        )
    }

    private func clampedInlineText(_ text: String, limit: Int) -> String {
        let trimmed = text.trimmingCharacters(in: .whitespacesAndNewlines)
        guard trimmed.count > limit else { return trimmed }
        return String(trimmed.prefix(limit)) + "..."
    }

    private func builtinDiagnosticGutterSuggestions(
        diagnostics: [Diagnostic],
        selectedDiagnostic: Diagnostic?
    ) -> [EditorGutterDecorationSuggestion] {
        let grouped = Dictionary(grouping: diagnostics) { Int($0.range.start.line) + 1 }
        return grouped.compactMap { line, diagnosticsOnLine in
            guard let diagnostic = diagnosticsOnLine.max(by: { diagnosticSeverityRank($0.severity) < diagnosticSeverityRank($1.severity) }) else {
                return nil
            }
            let isSelected = selectedDiagnostic.map { Int($0.range.start.line) + 1 == line } ?? false
            return EditorGutterDecorationSuggestion(
                id: "diagnostic-\(line)",
                line: line,
                lane: 0,
                kind: .diagnostic(diagnosticSeverityLevel(diagnostic.severity)),
                priority: isSelected ? 200 : 160,
                badgeText: diagnosticsOnLine.count > 1 ? "\(diagnosticsOnLine.count)" : nil
            )
        }
    }

    private func builtinSymbolGutterSuggestions(documentSymbols: [EditorDocumentSymbolItem]) -> [EditorGutterDecorationSuggestion] {
        flattenedDocumentSymbols(documentSymbols).map { symbol in
            EditorGutterDecorationSuggestion(
                id: "symbol-\(symbol.id)",
                line: symbol.line,
                lane: 1,
                kind: .symbol(symbol.kind),
                priority: 80
            )
        }
    }

    private func flattenedDocumentSymbols(_ symbols: [EditorDocumentSymbolItem]) -> [EditorDocumentSymbolItem] {
        symbols.flatMap { symbol in
            [symbol] + flattenedDocumentSymbols(symbol.children)
        }
    }

    private func coalescedGutterSuggestions(
        _ suggestions: [EditorGutterDecorationSuggestion]
    ) -> [EditorGutterDecorationSuggestion] {
        let grouped = Dictionary(grouping: suggestions) {
            GutterSuggestionLaneKey(line: $0.line, lane: $0.lane)
        }
        return grouped.values.compactMap { suggestionsOnLane in
            suggestionsOnLane.max { lhs, rhs in
                if lhs.priority != rhs.priority {
                    return lhs.priority < rhs.priority
                }
                return lhs.id.localizedCaseInsensitiveCompare(rhs.id) == .orderedDescending
            }
        }
    }

    private func gutterSymbolName(for kind: EditorGutterDecorationKind) -> String? {
        switch kind {
        case .symbol(let symbolKind):
            switch symbolKind {
            case .class, .struct, .interface, .enum, .module, .namespace:
                return "diamond.fill"
            case .function, .method, .constructor:
                return "circle.fill"
            default:
                return "square.fill"
            }
        case .custom(_, _, let symbolName):
            return symbolName
        default:
            return nil
        }
    }

    private func diagnosticSeverityRank(_ severity: DiagnosticSeverity?) -> Int {
        switch severity {
        case .error:
            return 4
        case .warning:
            return 3
        case .information:
            return 2
        case .hint:
            return 1
        default:
            return 0
        }
    }
}
