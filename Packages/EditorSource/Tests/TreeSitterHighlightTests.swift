import AppKit
import EditorLanguageRuntime
import EditorTextView
import XCTest
@testable import EditorSource

@MainActor
final class TreeSitterHighlightTests: XCTestCase {
    func testQueryHighlightsWithoutStateReturnsCancelled() {
        let client = TreeSitterClient()
        client.forceSyncOperation = true
        let textView = TextView(string: "ArchivePath: ./my-app\n")

        let expectation = expectation(description: "query completes")
        client.queryHighlightsFor(textView: textView, range: NSRange(location: 0, length: textView.length)) { result in
            guard case .failure(HighlightProvidingError.operationCancelled) = result else {
                XCTFail("Expected operationCancelled before tree-sitter state is ready, got \(result)")
                return
            }
            expectation.fulfill()
        }

        wait(for: [expectation], timeout: 1.0)
    }

    func testSetUpPostsStateDidUpdateNotification() {
        let client = TreeSitterClient()
        client.forceSyncOperation = true
        let textView = TextView(string: "key: value\n")

        let expectation = expectation(
            forNotification: TreeSitterClient.Constants.stateDidUpdate,
            object: client,
            handler: nil
        )

        client.setUp(textView: textView, codeLanguage: .plainText)

        wait(for: [expectation], timeout: 1.0)
    }

    func testQueryHighlightsAfterSyncSetUpReturnsSuccess() {
        let client = TreeSitterClient()
        client.forceSyncOperation = true
        let textView = TextView(string: "key: value\n")
        client.setUp(textView: textView, codeLanguage: .plainText)

        let expectation = expectation(description: "query completes")
        client.queryHighlightsFor(textView: textView, range: NSRange(location: 0, length: textView.length)) { result in
            guard case .success = result else {
                XCTFail("Expected success after setUp, got \(result)")
                return
            }
            expectation.fulfill()
        }

        wait(for: [expectation], timeout: 1.0)
    }
}

@MainActor
final class HighlightProviderStateTests: XCTestCase {
    func testCancelledQueryDoesNotApplyHighlightsUntilRetrySucceeds() {
        let textView = makeTextViewInScrollView(text: "ArchivePath: ./my-app\n")
        let delegate = MockHighlightDelegate()
        let provider = MockHighlightProvider()
        provider.queryResults = [
            .failure(HighlightProvidingError.operationCancelled),
            .success([HighlightRange(range: NSRange(location: 0, length: 11), capture: .property)]),
        ]

        let visibleRangeProvider = VisibleRangeProvider(textView: textView, minimapView: nil)
        let state = HighlightProviderState(
            id: 0,
            delegate: delegate,
            highlightProvider: provider,
            textView: textView,
            visibleRangeProvider: visibleRangeProvider,
            language: .plainText
        )

        state.invalidate()

        let expectation = expectation(description: "highlight retry completes")
        DispatchQueue.main.async {
            XCTAssertEqual(delegate.applyCount, 1, "Highlights should apply only after a successful retry")
            XCTAssertEqual(provider.queryCallCount, 2, "Cancelled query should trigger a retry")
            expectation.fulfill()
        }

        wait(for: [expectation], timeout: 2.0)
    }

    func testCancelledQueryDoesNotApplyHighlightsImmediately() {
        let textView = makeTextViewInScrollView(text: "hello\n")
        let delegate = MockHighlightDelegate()
        let provider = MockHighlightProvider()
        provider.queryResults = [.failure(HighlightProvidingError.operationCancelled)]
        provider.stallAfterScheduledResults = true

        let visibleRangeProvider = VisibleRangeProvider(textView: textView, minimapView: nil)
        let state = HighlightProviderState(
            id: 0,
            delegate: delegate,
            highlightProvider: provider,
            textView: textView,
            visibleRangeProvider: visibleRangeProvider,
            language: .plainText
        )

        state.invalidate()

        let expectation = expectation(description: "first query wave completes")
        DispatchQueue.main.async {
            XCTAssertEqual(delegate.applyCount, 0, "Cancelled query must not apply empty highlights")
            expectation.fulfill()
        }

        wait(for: [expectation], timeout: 2.0)
    }
}

@MainActor
private func makeTextViewInScrollView(text: String) -> TextView {
    let textView = TextView(
        string: text,
        font: .monospacedSystemFont(ofSize: 12, weight: .regular),
        wrapLines: false
    )
    let scrollView = NSScrollView(frame: NSRect(x: 0, y: 0, width: 480, height: 320))
    scrollView.drawsBackground = false
    scrollView.hasVerticalScroller = true
    scrollView.documentView = textView
    textView.frame = NSRect(x: 0, y: 0, width: 480, height: 320)
    textView.layoutManager.layoutLines()
    return textView
}

@MainActor
private final class MockHighlightProvider: HighlightProviding {
    var queryResults: [Result<[HighlightRange], Error>] = []
    var defaultResult: Result<[HighlightRange], Error> = .success([])
    var stallAfterScheduledResults = false
    private(set) var queryCallCount = 0

    func setUp(textView: TextView, codeLanguage: EditorLanguageContext) {}

    func applyEdit(
        textView: TextView,
        range: NSRange,
        delta: Int,
        completion: @escaping @MainActor (Result<IndexSet, Error>) -> Void
    ) {
        completion(.success(IndexSet()))
    }

    func queryHighlightsFor(
        textView: TextView,
        range: NSRange,
        completion: @escaping @MainActor (Result<[HighlightRange], Error>) -> Void
    ) {
        queryCallCount += 1
        let index = queryCallCount - 1
        if stallAfterScheduledResults && index >= queryResults.count {
            return
        }
        let result = index < queryResults.count ? queryResults[index] : defaultResult
        completion(result)
    }
}

@MainActor
private final class MockHighlightDelegate: HighlightProviderStateDelegate {
    private(set) var applyCount = 0

    func applyHighlightResult(
        provider: Int,
        highlights: [HighlightRange],
        rangeToHighlight: NSRange
    ) {
        applyCount += 1
    }
}
