import AppKit
import CodeEditTextView
import Foundation
import LanguageServerProtocol

@MainActor
enum EditorFoldingController {
    struct FoldCandidate: Equatable {
        let range: FoldingRangeItem
        let depth: Int
        let isCollapsed: Bool
    }

    static func captureState(
        textView: TextView,
        ranges: [FoldingRangeItem],
        lineTable: LineOffsetTable
    ) -> EditorFoldingState {
        let collapsed = ranges.compactMap { range -> EditorFoldingState.CollapsedRange? in
            guard isCollapsed(range: range, textView: textView, lineTable: lineTable) else {
                return nil
            }
            return EditorFoldingState.CollapsedRange(
                startLine: range.startLine,
                endLine: range.endLine,
                kind: range.kind
            )
        }
        return EditorFoldingState(collapsedRanges: Set(collapsed))
    }

    @discardableResult
    static func restore(
        _ state: EditorFoldingState,
        textView: TextView,
        ranges: [FoldingRangeItem],
        lineTable: LineOffsetTable
    ) -> Bool {
        guard !state.collapsedRanges.isEmpty else { return true }

        let targets = ranges.filter { range in
            state.collapsedRanges.contains(
                EditorFoldingState.CollapsedRange(
                    startLine: range.startLine,
                    endLine: range.endLine,
                    kind: range.kind
                )
            )
        }

        var restoredAny = false
        for range in targets where !isCollapsed(range: range, textView: textView, lineTable: lineTable) {
            restoredAny = toggle(range: range, textView: textView)
        }
        return restoredAny || targets.allSatisfy { isCollapsed(range: $0, textView: textView, lineTable: lineTable) }
    }

    static func currentFoldCandidate(
        cursorLine: Int,
        ranges: [FoldingRangeItem],
        textView: TextView,
        lineTable: LineOffsetTable
    ) -> FoldCandidate? {
        let zeroBasedLine = max(cursorLine - 1, 0)
        return annotate(ranges: ranges, textView: textView, lineTable: lineTable)
            .filter { candidate in
                candidate.range.startLine <= zeroBasedLine && zeroBasedLine <= candidate.range.endLine
            }
            .sorted {
                if $0.range.hiddenLineCount != $1.range.hiddenLineCount {
                    return $0.range.hiddenLineCount < $1.range.hiddenLineCount
                }
                return $0.depth > $1.depth
            }
            .first
    }

    @discardableResult
    static func collapseCurrent(
        cursorLine: Int,
        ranges: [FoldingRangeItem],
        textView: TextView,
        lineTable: LineOffsetTable
    ) -> Bool {
        guard let candidate = currentFoldCandidate(
            cursorLine: cursorLine,
            ranges: ranges,
            textView: textView,
            lineTable: lineTable
        ), !candidate.isCollapsed else {
            return false
        }
        return toggle(range: candidate.range, textView: textView)
    }

    @discardableResult
    static func expandCurrent(
        cursorLine: Int,
        ranges: [FoldingRangeItem],
        textView: TextView,
        lineTable: LineOffsetTable
    ) -> Bool {
        guard let candidate = currentFoldCandidate(
            cursorLine: cursorLine,
            ranges: ranges,
            textView: textView,
            lineTable: lineTable
        ), candidate.isCollapsed else {
            return false
        }
        return toggle(range: candidate.range, textView: textView)
    }

    @discardableResult
    static func collapseAll(
        ranges: [FoldingRangeItem],
        textView: TextView,
        lineTable: LineOffsetTable
    ) -> Bool {
        var changed = false
        for candidate in annotate(ranges: ranges, textView: textView, lineTable: lineTable) where !candidate.isCollapsed {
            changed = toggle(range: candidate.range, textView: textView) || changed
        }
        return changed
    }

    @discardableResult
    static func expandAll(
        ranges: [FoldingRangeItem],
        textView: TextView,
        lineTable: LineOffsetTable
    ) -> Bool {
        var changed = false
        for candidate in annotate(ranges: ranges, textView: textView, lineTable: lineTable).reversed() where candidate.isCollapsed {
            changed = toggle(range: candidate.range, textView: textView) || changed
        }
        return changed
    }

    @discardableResult
    static func collapseToLevel(
        _ level: Int,
        ranges: [FoldingRangeItem],
        textView: TextView,
        lineTable: LineOffsetTable
    ) -> Bool {
        guard level > 0 else { return false }

        var changed = false
        for candidate in annotate(ranges: ranges, textView: textView, lineTable: lineTable) {
            if candidate.depth <= level, !candidate.isCollapsed {
                changed = toggle(range: candidate.range, textView: textView) || changed
            } else if candidate.depth > level, candidate.isCollapsed {
                changed = toggle(range: candidate.range, textView: textView) || changed
            }
        }
        return changed
    }

    static func annotate(
        ranges: [FoldingRangeItem],
        textView: TextView,
        lineTable: LineOffsetTable
    ) -> [FoldCandidate] {
        let sorted = ranges.sorted {
            if $0.startLine != $1.startLine {
                return $0.startLine < $1.startLine
            }
            return $0.endLine > $1.endLine
        }

        var stack: [FoldingRangeItem] = []
        var result: [FoldCandidate] = []
        for range in sorted {
            while let last = stack.last, range.startLine > last.endLine {
                stack.removeLast()
            }
            let depth = stack.count + 1
            result.append(
                FoldCandidate(
                    range: range,
                    depth: depth,
                    isCollapsed: isCollapsed(range: range, textView: textView, lineTable: lineTable)
                )
            )
            stack.append(range)
        }
        return result
    }

    static func isCollapsed(
        range: FoldingRangeItem,
        textView: TextView,
        lineTable: LineOffsetTable
    ) -> Bool {
        guard let attachmentRange = attachmentProbeRange(for: range, lineTable: lineTable) else {
            return false
        }
        return textView.layoutManager.attachments
            .getAttachmentsStartingIn(attachmentRange)
            .contains(where: isFoldPlaceholder)
    }

    @discardableResult
    static func toggle(
        range: FoldingRangeItem,
        textView: TextView
    ) -> Bool {
        guard let ribbonView = foldingRibbonView(for: textView),
              let linePosition = textView.layoutManager.textLineForIndex(range.startLine),
              let window = ribbonView.window else {
            return false
        }

        let localPoint = NSPoint(x: ribbonView.bounds.midX, y: linePosition.yPos + (linePosition.height / 2))
        let location = ribbonView.convert(localPoint, to: nil)
        guard let mouseDown = NSEvent.mouseEvent(
            with: .leftMouseDown,
            location: location,
            modifierFlags: [],
            timestamp: ProcessInfo.processInfo.systemUptime,
            windowNumber: window.windowNumber,
            context: nil,
            eventNumber: 0,
            clickCount: 1,
            pressure: 1
        ) else {
            return false
        }

        ribbonView.mouseDown(with: mouseDown)
        return true
    }

    private static func attachmentProbeRange(
        for range: FoldingRangeItem,
        lineTable: LineOffsetTable
    ) -> NSRange? {
        guard let start = lineTable.lineStart(line: range.startLine) else { return nil }
        let end = lineTable.lineStart(line: range.endLine + 1) ?? lineTable.totalUTF16Length
        return NSRange(location: start, length: max(end - start, 1))
    }

    private static func isFoldPlaceholder(_ attachment: AnyTextAttachment) -> Bool {
        String(describing: type(of: attachment.attachment)).contains("LineFoldPlaceholder")
    }

    private static func foldingRibbonView(for textView: TextView) -> NSView? {
        guard let scrollView = textView.enclosingScrollView else { return nil }
        return findSubview(
            in: scrollView,
            matching: { String(describing: type(of: $0)).contains("LineFoldRibbonView") }
        )
    }

    private static func findSubview(
        in root: NSView,
        matching: (NSView) -> Bool
    ) -> NSView? {
        if matching(root) {
            return root
        }
        for subview in root.subviews {
            if let match = findSubview(in: subview, matching: matching) {
                return match
            }
        }
        return nil
    }
}
