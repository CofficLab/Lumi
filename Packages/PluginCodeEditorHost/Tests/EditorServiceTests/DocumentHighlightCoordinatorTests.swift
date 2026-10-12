import AppKit
import EditorLanguageRuntime
import EditorSource
import EditorTextView
import XCTest
@testable import EditorService

@MainActor
final class DocumentHighlightCoordinatorTests: XCTestCase {
    func testActivateRestoresCachedSnapshotToTextStorage() {
        let coordinator = DocumentHighlightCoordinator()
        let content = "ArchivePath: ./my-app\n"
        let fileURL = URL(fileURLWithPath: "/tmp/release.yml")
        let key = DocumentHighlightKey(fileURL: fileURL, content: content, languageId: EditorLanguageContext.plainText.languageId)

        coordinator.cache.store(
            DocumentHighlightSnapshot(
                key: key,
                highlightRevision: coordinator.cache.highlightRevision,
                runs: [HighlightRange(range: NSRange(location: 0, length: 11), capture: .keyword)]
            )
        )

        let textStorage = NSTextStorage(string: content)
        textStorage.setAttributes(
            [.foregroundColor: NSColor.textColor],
            range: NSRange(location: 0, length: textStorage.length)
        )

        let controller = TextViewController(
            string: content,
            language: .plainText,
            configuration: SourceEditorConfiguration(
                appearance: SourceEditorConfiguration.Appearance(
                    theme: makeTheme(),
                    font: .monospacedSystemFont(ofSize: 12, weight: .regular),
                    wrapLines: false
                )
            ),
            cursorPositions: []
        )

        coordinator.configure(
            treeSitterClient: TreeSitterClient(),
            textViewController: controller,
            attributesProvider: { capture in controller.attributesFor(capture) }
        )

        let restored = coordinator.activate(
            fileURL: fileURL,
            content: content,
            language: .plainText,
            textStorage: textStorage
        )

        XCTAssertTrue(restored)
        let restoredColor = textStorage.attribute(.foregroundColor, at: 0, effectiveRange: nil) as? NSColor
        XCTAssertEqual(restoredColor, controller.attributesFor(.keyword)[.foregroundColor] as? NSColor)
    }
}

private func makeTheme() -> EditorTheme {
    let text = EditorTheme.Attribute(color: .textColor)
    return EditorTheme(
        text: text,
        insertionPoint: .textColor,
        invisibles: text,
        background: NSColor(red: 0.1, green: 0.1, blue: 0.12, alpha: 1),
        lineHighlight: NSColor(red: 0.15, green: 0.15, blue: 0.18, alpha: 1),
        selection: NSColor(red: 0.2, green: 0.35, blue: 0.6, alpha: 1),
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
