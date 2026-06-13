import EditorLanguageRuntime
import EditorTextView
import XCTest
@testable import EditorSource

final class DocumentHighlightCacheTests: XCTestCase {
    func testSameContentProducesSameKey() {
        let url = URL(fileURLWithPath: "/tmp/example.yml")
        let keyA = DocumentHighlightKey(fileURL: url, content: "key: value\n", languageId: "yaml")
        let keyB = DocumentHighlightKey(fileURL: url, content: "key: value\n", languageId: "yaml")
        XCTAssertEqual(keyA, keyB)
    }

    func testEditedContentChangesDigest() {
        let url = URL(fileURLWithPath: "/tmp/example.yml")
        let before = DocumentHighlightKey(fileURL: url, content: "key: value\n", languageId: "yaml")
        let after = DocumentHighlightKey(fileURL: url, content: "key: changed\n", languageId: "yaml")
        XCTAssertNotEqual(before.contentDigest, after.contentDigest)
    }

    func testCacheHitMissAndLRU() {
        let cache = DocumentHighlightCache(capacity: 2)
        let urlA = URL(fileURLWithPath: "/tmp/a.swift")
        let urlB = URL(fileURLWithPath: "/tmp/b.swift")
        let urlC = URL(fileURLWithPath: "/tmp/c.swift")

        let keyA = DocumentHighlightKey(fileURL: urlA, content: "a\n", languageId: "swift")
        let keyB = DocumentHighlightKey(fileURL: urlB, content: "b\n", languageId: "swift")
        let keyC = DocumentHighlightKey(fileURL: urlC, content: "c\n", languageId: "swift")

        cache.store(DocumentHighlightSnapshot(key: keyA, highlightRevision: 0, runs: [
            HighlightRange(range: NSRange(location: 0, length: 1), capture: .property),
        ]))
        cache.store(DocumentHighlightSnapshot(key: keyB, highlightRevision: 0, runs: [
            HighlightRange(range: NSRange(location: 0, length: 1), capture: .keyword),
        ]))

        XCTAssertNotNil(cache.snapshot(for: keyA))
        _ = cache.snapshot(for: keyA)

        cache.store(DocumentHighlightSnapshot(key: keyC, highlightRevision: 0, runs: [
            HighlightRange(range: NSRange(location: 0, length: 1), capture: .string),
        ]))

        XCTAssertNil(cache.snapshot(for: keyB), "Least recently used entry should be evicted")
        XCTAssertNotNil(cache.snapshot(for: keyA))
        XCTAssertNotNil(cache.snapshot(for: keyC))
    }

    func testHighlightRevisionBumpInvalidatesEntries() {
        let cache = DocumentHighlightCache()
        let key = DocumentHighlightKey(
            fileURL: URL(fileURLWithPath: "/tmp/a.swift"),
            content: "a\n",
            languageId: "swift"
        )
        cache.store(DocumentHighlightSnapshot(key: key, highlightRevision: 0, runs: [
            HighlightRange(range: NSRange(location: 0, length: 1), capture: .property),
        ]))
        cache.bumpHighlightRevision()
        XCTAssertNil(cache.snapshot(for: key))
    }
}
