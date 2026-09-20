import EditorLanguageRuntime
import EditorTextView
import XCTest
@testable import EditorSource

@MainActor
final class TreeSitterDocumentStoreTests: XCTestCase {
    func testReattachSameDocumentKeyReusesStateWithoutCancelledQuery() {
        let client = TreeSitterClient()
        client.forceSyncOperation = true
        let store = TreeSitterDocumentStore()
        client.documentStore = store

        let content = "key: value\n"
        let key = DocumentHighlightKey(
            fileURL: URL(fileURLWithPath: "/tmp/example.yml"),
            content: content,
            languageId: "yaml"
        )
        let textView = EditorHighlightTestSupport.makeTextViewInScrollView(text: content)

        client.attach(documentKey: key, textView: textView, codeLanguage: .plainText)
        client.detach()

        let expectation = expectation(description: "query succeeds on reattach")
        client.attach(documentKey: key, textView: textView, codeLanguage: .plainText)
        client.queryHighlightsFor(textView: textView, range: NSRange(location: 0, length: textView.length)) { result in
            guard case .success = result else {
                XCTFail("Expected success after reattach, got \(result)")
                return
            }
            expectation.fulfill()
        }

        wait(for: [expectation], timeout: 1.0)
    }
}
