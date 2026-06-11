import EditorCodeEditTextView
import Foundation
import LanguageServerProtocol

// MARK: - Visible range for LSP `textDocument/inlayHint`

public enum EditorInlayHintLayout {
    /// 将可见区域映射为 LSP 行范围（0-based），供 `textDocument/inlayHint` 使用
    @MainActor
    public static func visibleDocumentLSPRange(in textView: TextView) -> LSPRange? {
        let str = textView.string
        guard !str.isEmpty, let lm = textView.layoutManager else { return nil }

        let vis = textView.visibleRect
        let hInset = textView.edgeInsets + textView.textInsets
        let top = CGPoint(x: vis.minX + hInset.left + 4, y: vis.minY + 4)
        let bottom = CGPoint(x: vis.midX, y: max(vis.minY + 4, vis.maxY - 4))

        guard let startOffset = lm.textOffsetAtPoint(top),
              let endOffset = lm.textOffsetAtPoint(bottom) else { return nil }

        let pad = 400
        let len = str.utf16.count
        let lo = max(0, min(startOffset, endOffset) - pad)
        let hi = min(len, max(startOffset, endOffset) + pad)

        let startPos = lspPosition(utf16Offset: lo, in: str)
        let endPos = lspPosition(utf16Offset: hi, in: str)
        return LSPRange(
            start: Position(line: startPos.line, character: startPos.character),
            end: Position(line: endPos.line, character: endPos.character)
        )
    }

    private static func lspPosition(utf16Offset: Int, in content: String) -> (line: Int, character: Int) {
        var line = 0
        var column = 0
        var offset = 0
        for scalar in content.unicodeScalars {
            let len = scalar.utf16.count
            if offset + len > utf16Offset {
                return (line, column)
            }
            if scalar == "\n" {
                line += 1
                column = 0
            } else {
                column += len
            }
            offset += len
        }
        return (line, column)
    }
}
