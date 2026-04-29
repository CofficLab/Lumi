import Foundation
import CoreGraphics
import CodeEditTextView

@MainActor
final class EditorOverlayController {
    func findMatchHighlights(
        matches: [EditorFindMatch],
        selectedRange: EditorRange?,
        textView: TextView,
        visibleRect: CGRect
    ) -> [FindMatchOverlayHighlight] {
        matches.compactMap { match in
            guard let rect = findMatchOverlayRect(
                for: match.range,
                in: textView,
                visibleRect: visibleRect
            ) else {
                return nil
            }

            return FindMatchOverlayHighlight(
                range: match.range,
                rect: rect,
                isSelected: match.range == selectedRange
            )
        }
    }

    func bracketOverlayRects(
        match: BracketMatchResult?,
        textView: TextView
    ) -> BracketOverlayRects? {
        guard let match,
              let openRect = textView.layoutManager.rectForOffset(match.openOffset),
              let closeRect = textView.layoutManager.rectForOffset(match.closeOffset) else {
            return nil
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
            return nil
        }

        return BracketOverlayRects(open: openOverlayRect, close: closeOverlayRect)
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
        popoverHeight: CGFloat,
        maxWidth: CGFloat = 440,
        verticalGap: CGFloat = 4
    ) -> CGSize {
        let preferredX = symbolRect.minX
        let clampedX = max(4, min(preferredX, containerSize.width - maxWidth - 4))

        let preferredY = symbolRect.minY - popoverHeight - verticalGap
        let fallbackY = symbolRect.maxY + verticalGap
        let clampedY: CGFloat
        if preferredY >= 4 {
            clampedY = preferredY
        } else {
            clampedY = min(fallbackY, max(containerSize.height - popoverHeight - 4, 4))
        }

        return CGSize(width: clampedX, height: clampedY)
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
}
