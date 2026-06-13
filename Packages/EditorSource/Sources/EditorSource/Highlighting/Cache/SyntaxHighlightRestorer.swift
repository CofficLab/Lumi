import AppKit
import Foundation

public enum SyntaxHighlightRestorer {
    @discardableResult
    public static func apply(
        snapshot: DocumentHighlightSnapshot,
        to textStorage: NSTextStorage,
        content: String,
        highlightRevision: Int,
        attributesFor: (CaptureName?) -> [NSAttributedString.Key: Any]
    ) -> Bool {
        guard snapshot.highlightRevision == highlightRevision else { return false }
        guard snapshot.key.matches(content: content) else { return false }
        guard !snapshot.runs.isEmpty else { return false }

        textStorage.beginEditing()
        for run in snapshot.runs {
            guard run.range.location != NSNotFound,
                  run.range.length > 0,
                  run.range.upperBound <= textStorage.length else {
                continue
            }
            textStorage.setAttributes(attributesFor(run.capture), range: run.range)
        }
        textStorage.endEditing()
        return true
    }

    public static func reapplyTheme(
        snapshot: DocumentHighlightSnapshot,
        to textStorage: NSTextStorage,
        content: String,
        highlightRevision: Int,
        attributesFor: (CaptureName?) -> [NSAttributedString.Key: Any]
    ) -> Bool {
        apply(
            snapshot: snapshot,
            to: textStorage,
            content: content,
            highlightRevision: highlightRevision,
            attributesFor: attributesFor
        )
    }
}
