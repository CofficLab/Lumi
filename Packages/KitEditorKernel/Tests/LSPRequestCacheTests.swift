import Testing
@testable import EditorKernel

@MainActor
@Suite("LSPRequestCache")
struct LSPRequestCacheTests {
    @Test("cache stores and retrieves values")
    func cacheStoreAndRetrieve() {
        let cache = LSPRequestCache()
        let testValue = ["test": "value"]

        cache.set(
            kind: .inlayHints,
            uri: "file:///test.swift",
            line: 10,
            character: 5,
            value: testValue
        )

        let retrieved: [String: String]? = cache.get(
            kind: .inlayHints,
            uri: "file:///test.swift",
            line: 10,
            character: 5
        )

        #expect(retrieved != nil)
        #expect(retrieved?["test"] == "value")
    }

    @Test("cache returns nil for missing keys")
    func cacheMissingKey() {
        let cache = LSPRequestCache()

        let retrieved: [String: String]? = cache.get(
            kind: .inlayHints,
            uri: "file:///test.swift",
            line: 10,
            character: 5
        )

        #expect(retrieved == nil)
    }

    @Test("cache differentiates by kind")
    func cacheDifferentiatesByKind() {
        let cache = LSPRequestCache()

        cache.set(
            kind: .inlayHints,
            uri: "file:///test.swift",
            line: 10,
            character: 5,
            value: "inlay"
        )

        cache.set(
            kind: .diagnostics,
            uri: "file:///test.swift",
            line: 10,
            character: 5,
            value: "diag"
        )

        let inlayValue: String? = cache.get(
            kind: .inlayHints,
            uri: "file:///test.swift",
            line: 10,
            character: 5
        )

        let diagValue: String? = cache.get(
            kind: .diagnostics,
            uri: "file:///test.swift",
            line: 10,
            character: 5
        )

        #expect(inlayValue == "inlay")
        #expect(diagValue == "diag")
    }

    @Test("cache differentiates by position")
    func cacheDifferentiatesByPosition() {
        let cache = LSPRequestCache()

        cache.set(
            kind: .inlayHints,
            uri: "file:///test.swift",
            line: 10,
            character: 5,
            value: "pos1"
        )

        cache.set(
            kind: .inlayHints,
            uri: "file:///test.swift",
            line: 20,
            character: 5,
            value: "pos2"
        )

        let value1: String? = cache.get(
            kind: .inlayHints,
            uri: "file:///test.swift",
            line: 10,
            character: 5
        )

        let value2: String? = cache.get(
            kind: .inlayHints,
            uri: "file:///test.swift",
            line: 20,
            character: 5
        )

        #expect(value1 == "pos1")
        #expect(value2 == "pos2")
    }

    @Test("cache removes specific entry")
    func cacheRemove() {
        let cache = LSPRequestCache()

        cache.set(
            kind: .inlayHints,
            uri: "file:///test.swift",
            line: 10,
            character: 5,
            value: "test"
        )

        cache.remove(
            kind: .inlayHints,
            uri: "file:///test.swift",
            line: 10,
            character: 5
        )

        let retrieved: String? = cache.get(
            kind: .inlayHints,
            uri: "file:///test.swift",
            line: 10,
            character: 5
        )

        #expect(retrieved == nil)
    }

    @Test("cache clears all entries")
    func cacheClear() {
        let cache = LSPRequestCache()

        cache.set(kind: .inlayHints, uri: "file:///test1.swift", line: 10, character: 5, value: "test1")
        cache.set(kind: .diagnostics, uri: "file:///test2.swift", line: 20, character: 5, value: "test2")

        cache.clear()

        let value1: String? = cache.get(kind: .inlayHints, uri: "file:///test1.swift", line: 10, character: 5)
        let value2: String? = cache.get(kind: .diagnostics, uri: "file:///test2.swift", line: 20, character: 5)

        #expect(value1 == nil)
        #expect(value2 == nil)
    }

    @Test("cache invalidates by URI")
    func cacheInvalidateByURI() {
        let cache = LSPRequestCache()

        cache.set(kind: .inlayHints, uri: "file:///test1.swift", line: 10, character: 5, value: "test1")
        cache.set(kind: .inlayHints, uri: "file:///test2.swift", line: 10, character: 5, value: "test2")

        cache.invalidate(uri: "file:///test1.swift")

        let value1: String? = cache.get(kind: .inlayHints, uri: "file:///test1.swift", line: 10, character: 5)
        let value2: String? = cache.get(kind: .inlayHints, uri: "file:///test2.swift", line: 10, character: 5)

        #expect(value1 == nil)
        #expect(value2 == "test2")
    }

    @Test("cache removes all entries of specific kind")
    func cacheRemoveByKind() {
        let cache = LSPRequestCache()

        cache.set(kind: .inlayHints, uri: "file:///test1.swift", line: 10, character: 5, value: "inlay1")
        cache.set(kind: .inlayHints, uri: "file:///test2.swift", line: 20, character: 5, value: "inlay2")
        cache.set(kind: .diagnostics, uri: "file:///test1.swift", line: 10, character: 5, value: "diag1")

        cache.removeAll(kind: .inlayHints)

        let inlay1: String? = cache.get(kind: .inlayHints, uri: "file:///test1.swift", line: 10, character: 5)
        let inlay2: String? = cache.get(kind: .inlayHints, uri: "file:///test2.swift", line: 20, character: 5)
        let diag1: String? = cache.get(kind: .diagnostics, uri: "file:///test1.swift", line: 10, character: 5)

        #expect(inlay1 == nil)
        #expect(inlay2 == nil)
        #expect(diag1 == "diag1")
    }

    @Test("cache respects generation invalidation")
    func cacheGenerationInvalidation() {
        let cache = LSPRequestCache()

        cache.set(
            kind: .inlayHints,
            uri: "file:///test.swift",
            line: 10,
            character: 5,
            value: "test"
        )

        // Clear invalidates generation
        cache.clear()

        let retrieved: String? = cache.get(
            kind: .inlayHints,
            uri: "file:///test.swift",
            line: 10,
            character: 5
        )

        #expect(retrieved == nil)
    }
}
