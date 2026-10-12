import AppKit
import EditorLanguageRuntime
import EditorTextView
import XCTest
@testable import EditorSource

@MainActor
final class LineFoldCalculatorCrashReproTests: XCTestCase {
    func testBuildFoldsIgnoresOutOfBoundsFoldAndDoesNotCrash() async {
        let controller = makeController(
            text: """
            line0
            line1
            """
        )
        let foldProvider = OutOfBoundsStartFoldProvider()
        let (stream, continuation) = AsyncStream<Void>.makeStream()
        let calculator = LineFoldCalculator(
            foldProvider: foldProvider,
            controller: controller,
            textChangedStream: stream
        )

        continuation.yield(())

        guard let storage = await calculator.valueStream.first(where: { _ in true }) else {
            XCTFail("Expected fold storage to be emitted")
            return
        }
        let folds = storage.folds(in: 0..<controller.text.count)
        XCTAssertTrue(folds.allSatisfy { $0.range.lowerBound <= $0.range.upperBound })
    }

    func testBuildFoldsIgnoresReverseRangeWhenClosingFold() async {
        let controller = makeController(
            text: """
            line0
            line1
            line2
            """
        )
        let foldProvider = ReverseRangeCloseFoldProvider()
        let (stream, continuation) = AsyncStream<Void>.makeStream()
        let calculator = LineFoldCalculator(
            foldProvider: foldProvider,
            controller: controller,
            textChangedStream: stream
        )

        continuation.yield(())

        guard let storage = await calculator.valueStream.first(where: { _ in true }) else {
            XCTFail("Expected fold storage to be emitted")
            return
        }
        let folds = storage.folds(in: 0..<controller.text.count)
        XCTAssertTrue(folds.isEmpty, "Invalid reverse fold range should be dropped")
    }
}

@MainActor
private func makeController(text: String) -> TextViewController {
    let theme = EditorTheme(
        text: .init(color: .textColor),
        insertionPoint: .textColor,
        invisibles: .init(color: .secondaryLabelColor),
        background: .textBackgroundColor,
        lineHighlight: .controlBackgroundColor,
        selection: .selectedTextBackgroundColor,
        keywords: .init(color: .systemBlue),
        commands: .init(color: .systemPurple),
        types: .init(color: .systemTeal),
        attributes: .init(color: .systemOrange),
        variables: .init(color: .labelColor),
        values: .init(color: .systemGreen),
        numbers: .init(color: .systemPink),
        strings: .init(color: .systemRed),
        characters: .init(color: .systemRed),
        comments: .init(color: .secondaryLabelColor)
    )
    let config = SourceEditorConfiguration(
        appearance: .init(
            theme: theme,
            themeIdentifier: "test",
            font: .monospacedSystemFont(ofSize: 12, weight: .regular),
            wrapLines: false
        )
    )
    return TextViewController(
        string: text,
        language: .plainText,
        configuration: config,
        cursorPositions: [],
        highlightProviders: [],
        foldProvider: LineIndentationFoldProvider()
    )
}

@MainActor
private final class OutOfBoundsStartFoldProvider: LineFoldProvider {
    func foldLevelAtLine(
        lineNumber: Int,
        lineRange: NSRange,
        previousDepth: Int,
        controller: TextViewController
    ) -> [LineFoldProviderLineInfo] {
        guard lineNumber == 0 else { return [] }
        return [.startFold(rangeStart: 10_000, newDepth: 1)]
    }
}

@MainActor
private final class ReverseRangeCloseFoldProvider: LineFoldProvider {
    func foldLevelAtLine(
        lineNumber: Int,
        lineRange: NSRange,
        previousDepth: Int,
        controller: TextViewController
    ) -> [LineFoldProviderLineInfo] {
        switch lineNumber {
        case 0:
            return [.startFold(rangeStart: 20, newDepth: 1)]
        case 1:
            return [.endFold(rangeEnd: 5, newDepth: 0)]
        default:
            return []
        }
    }
}
