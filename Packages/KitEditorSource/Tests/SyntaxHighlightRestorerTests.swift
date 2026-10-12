import AppKit
import EditorLanguageRuntime
import EditorTextView
import XCTest
@testable import EditorSource

@MainActor
final class SyntaxHighlightRestorerTests: XCTestCase {
    func testRestoreAppliesCaptureBeforeAsyncHighlight() throws {
        let content = "ArchivePath: ./my-app\n"
        let key = DocumentHighlightKey(
            fileURL: URL(fileURLWithPath: "/tmp/release.yml"),
            content: content,
            languageId: "yaml"
        )
        let snapshot = DocumentHighlightSnapshot(
            key: key,
            highlightRevision: 0,
            runs: [
                HighlightRange(range: NSRange(location: 0, length: 11), capture: .keyword),
                HighlightRange(range: NSRange(location: 13, length: 8), capture: .string),
            ]
        )

        let textView = EditorHighlightTestSupport.makeTextViewInScrollView(text: content)
        let textStorage = try XCTUnwrap(textView.textStorage)
        textStorage.setAttributes(defaultTypingAttributes(), range: NSRange(location: 0, length: textStorage.length))

        let theme = Self.testTheme()
        let restored = SyntaxHighlightRestorer.apply(
            snapshot: snapshot,
            to: textStorage,
            content: content,
            highlightRevision: 0,
            attributesFor: { capture in
                [
                    .foregroundColor: theme.colorFor(capture),
                    .font: NSFont.monospacedSystemFont(ofSize: 12, weight: .regular),
                ]
            }
        )

        XCTAssertTrue(restored)
        let keywordColor = textStorage.attribute(.foregroundColor, at: 0, effectiveRange: nil) as? NSColor
        let defaultColor = theme.colorFor(CaptureName?.none)
        XCTAssertNotEqual(keywordColor, defaultColor)
    }

    private static func testTheme() -> EditorTheme {
        let text = EditorTheme.Attribute(color: .textColor)
        return EditorTheme(
            text: text,
            insertionPoint: .textColor,
            invisibles: text,
            background: .textBackgroundColor,
            lineHighlight: .quaternaryLabelColor,
            selection: .selectedTextBackgroundColor,
            keywords: EditorTheme.Attribute(color: .systemBlue),
            commands: EditorTheme.Attribute(color: .systemTeal),
            types: EditorTheme.Attribute(color: .systemPurple),
            attributes: EditorTheme.Attribute(color: .systemOrange),
            variables: text,
            values: text,
            numbers: EditorTheme.Attribute(color: .systemYellow),
            strings: EditorTheme.Attribute(color: .systemRed),
            characters: text,
            comments: EditorTheme.Attribute(color: .systemGreen)
        )
    }

    private func defaultTypingAttributes() -> [NSAttributedString.Key: Any] {
        [
            .foregroundColor: Self.testTheme().colorFor(CaptureName?.none),
            .font: NSFont.monospacedSystemFont(ofSize: 12, weight: .regular),
        ]
    }
}
