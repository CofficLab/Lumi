import Foundation

public enum EditorRenderedRangePolicy {
    public static func isRenderedLine(_ line: Int, renderRange: Range<Int>) -> Bool {
        guard !renderRange.isEmpty else { return true }
        return renderRange.contains(max(line, 0))
    }

    public static func isRenderedOffset(
        _ offset: Int,
        renderRange: Range<Int>,
        lineTable: LineOffsetTable
    ) -> Bool {
        guard let line = lineTable.lineContaining(utf16Offset: max(offset, 0)) else {
            return true
        }
        return isRenderedLine(line, renderRange: renderRange)
    }

    public static func intersectsRenderedRange(
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

    public static func renderedFindMatches(
        _ matches: [EditorFindMatch],
        renderRange: Range<Int>,
        lineTable: LineOffsetTable
    ) -> [EditorFindMatch] {
        matches.filter { intersectsRenderedRange($0.range, renderRange: renderRange, lineTable: lineTable) }
    }
}
