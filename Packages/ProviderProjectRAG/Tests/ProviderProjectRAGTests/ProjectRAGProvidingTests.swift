import Foundation
import Testing
@testable import ProviderProjectRAG

@Suite("ProjectRAG Provider Contract")
struct ProjectRAGProvidingTests {
    @Test("response keeps query and result order")
    func responseIsSendableValue() {
        let response = ProjectRAGResponse(
            query: "kernel",
            results: [ProjectRAGSearchResult(content: "registerProvider", source: "Kernel.swift", score: 0.9)]
        )

        #expect(response.query == "kernel")
        #expect(response.results.count == 1)
        #expect(response.results[0].source == "Kernel.swift")
    }

    @Test("line range clamps end to at least start")
    func lineRangeClampsEndBelowStart() {
        let range = ProjectRAGLineRange(startLine: 10, endLine: 3)
        #expect(range.startLine == 10)
        #expect(range.endLine == 10)

        let valid = ProjectRAGLineRange(startLine: 3, endLine: 10)
        #expect(valid.startLine == 3)
        #expect(valid.endLine == 10)
    }

    @Test("search result defaults to semantic kind and no range")
    func searchResultConvenienceDefaults() {
        let result = ProjectRAGSearchResult(
            content: "body",
            source: "File.swift",
            score: 0.5
        )
        #expect(result.matchKind == .semantic)
        #expect(result.lineRange == nil)

        let withKind = ProjectRAGSearchResult(
            content: "body",
            source: "File.swift",
            score: 0.5,
            matchKind: .filesystemPath
        )
        #expect(withKind.matchKind == .filesystemPath)
        #expect(withKind.lineRange == nil)
    }

    // MARK: - ProjectRAGMatchKind

    @Test("match kind exposes all four kinds with expected raw values")
    func matchKindRawValues() {
        #expect(ProjectRAGMatchKind.semantic.rawValue == "semantic")
        #expect(ProjectRAGMatchKind.indexedLexical.rawValue == "indexedLexical")
        #expect(ProjectRAGMatchKind.filesystemLexical.rawValue == "filesystemLexical")
        #expect(ProjectRAGMatchKind.filesystemPath.rawValue == "filesystemPath")
    }

    @Test("match kinds compare by case")
    func matchKindEquality() {
        #expect(ProjectRAGMatchKind.semantic == .semantic)
        #expect(ProjectRAGMatchKind.semantic != .filesystemPath)
    }

    // MARK: - ProjectRAGLineRange

    @Test("line range with equal start and end is valid")
    func lineRangeSingleLine() {
        let range = ProjectRAGLineRange(startLine: 7, endLine: 7)
        #expect(range.startLine == 7)
        #expect(range.endLine == 7)
    }

    @Test("line range equality compares both ends")
    func lineRangeEquality() {
        let a = ProjectRAGLineRange(startLine: 1, endLine: 5)
        let b = ProjectRAGLineRange(startLine: 1, endLine: 5)
        let c = ProjectRAGLineRange(startLine: 1, endLine: 6)
        #expect(a == b)
        #expect(a != c)
    }

    // MARK: - ProjectRAGSearchResult

    @Test("search result carries explicit line range")
    func searchResultWithLineRange() {
        let range = ProjectRAGLineRange(startLine: 10, endLine: 20)
        let result = ProjectRAGSearchResult(
            content: "func foo()",
            source: "Foo.swift",
            score: 0.75,
            matchKind: .indexedLexical,
            lineRange: range
        )
        #expect(result.lineRange == range)
        #expect(result.matchKind == .indexedLexical)
    }

    @Test("search result equality compares all fields")
    func searchResultEquality() {
        let range = ProjectRAGLineRange(startLine: 1, endLine: 2)
        let a = ProjectRAGSearchResult(
            content: "c", source: "s", score: 0.5, matchKind: .semantic, lineRange: range
        )
        let b = ProjectRAGSearchResult(
            content: "c", source: "s", score: 0.5, matchKind: .semantic, lineRange: range
        )
        let c = ProjectRAGSearchResult(
            content: "c", source: "s", score: 0.6, matchKind: .semantic, lineRange: range
        )
        #expect(a == b)
        #expect(a != c)
    }

    // MARK: - ProjectRAGResponse

    @Test("response preserves result order")
    func responsePreservesOrder() {
        let results = [
            ProjectRAGSearchResult(content: "first", source: "A.swift", score: 0.9),
            ProjectRAGSearchResult(content: "second", source: "B.swift", score: 0.5),
        ]
        let response = ProjectRAGResponse(query: "q", results: results)
        #expect(response.results.map(\.source) == ["A.swift", "B.swift"])
    }

    @Test("response accepts empty result list")
    func responseAcceptsEmptyResults() {
        let response = ProjectRAGResponse(query: "nothing", results: [])
        #expect(response.results.isEmpty)
        #expect(response.query == "nothing")
    }

    // MARK: - ProjectRAGIndexStatus

    @Test("index status preserves all metadata")
    func indexStatusPreservesFields() {
        let date = Date(timeIntervalSince1970: 1_000)
        let status = ProjectRAGIndexStatus(
            projectPath: "/tmp/proj",
            lastIndexedAt: date,
            fileCount: 42,
            chunkCount: 512,
            isStale: true
        )
        #expect(status.projectPath == "/tmp/proj")
        #expect(status.lastIndexedAt == date)
        #expect(status.fileCount == 42)
        #expect(status.chunkCount == 512)
        #expect(status.isStale)
    }

    @Test("index status equality compares all fields")
    func indexStatusEquality() {
        let date = Date(timeIntervalSince1970: 1_000)
        let a = ProjectRAGIndexStatus(
            projectPath: "/p", lastIndexedAt: date, fileCount: 1, chunkCount: 2, isStale: false
        )
        let b = ProjectRAGIndexStatus(
            projectPath: "/p", lastIndexedAt: date, fileCount: 1, chunkCount: 2, isStale: false
        )
        let c = ProjectRAGIndexStatus(
            projectPath: "/p", lastIndexedAt: date, fileCount: 1, chunkCount: 2, isStale: true
        )
        #expect(a == b)
        #expect(a != c)
    }

    // MARK: - ProjectRAGEvent

    @Test("events with associated values compare by content")
    @MainActor
    func eventEquality() {
        #expect(ProjectRAGEvent.initialized == .initialized)
        #expect(ProjectRAGEvent.projectChanged("/a") == .projectChanged("/a"))
        #expect(ProjectRAGEvent.projectChanged("/a") != .projectChanged("/b"))
        #expect(ProjectRAGEvent.projectChanged(nil) == .projectChanged(nil))
        #expect(ProjectRAGEvent.indexingStarted("/p") == .indexingStarted("/p"))
        #expect(ProjectRAGEvent.indexingStarted("/p") != .indexingFinished("/p"))
        #expect(ProjectRAGEvent.indexingFinished("/p") == .indexingFinished("/p"))
    }
}

// MARK: - Default extension contract

/// A stub that records which default-extension arguments it received so we can
/// verify the convenience overloads forward correctly.
@MainActor
private final class StubProjectRAGProvider: ProjectRAGProviding {
    var isInitialized = false
    var currentProjectPath: String?
    private(set) var lastSearchQuery: String?
    private(set) var lastSearchProjectPath: String?
    private(set) var lastSearchTopK: Int?
    private(set) var lastEnsureProjectPath: String?
    private(set) var lastEnsureForce: Bool?
    private(set) var lastEnsureBackground: Bool?

    func search(query: String, projectPath: String?, topK: Int) async throws -> ProjectRAGResponse {
        lastSearchQuery = query
        lastSearchProjectPath = projectPath
        lastSearchTopK = topK
        return ProjectRAGResponse(query: query, results: [])
    }

    func ensureIndexed(projectPath: String, force: Bool, background: Bool) async throws {
        lastEnsureProjectPath = projectPath
        lastEnsureForce = force
        lastEnsureBackground = background
    }

    func indexStatus(projectPath: String) async throws -> ProjectRAGIndexStatus? {
        nil
    }
}

@Suite("ProjectRAG default extensions")
struct ProjectRAGDefaultExtensionsTests {
    @Test("default isIndexing returns false")
    @MainActor
    func defaultIsIndexingIsFalse() {
        let provider = StubProjectRAGProvider()
        #expect(provider.isIndexing(projectPath: "/any/path") == false)
        #expect(provider.isIndexing(projectPath: "") == false)
    }

    @Test("default observer handle cancel is a safe no-op")
    @MainActor
    func defaultObserverHandleCancelIsSafe() {
        let provider = StubProjectRAGProvider()
        let handle = provider.addProjectRAGObserver { _ in }
        handle.cancel()
        handle.cancel()
    }

    @Test("search convenience overload forwards nil projectPath and topK 8")
    @MainActor
    func searchConvenienceForwardsDefaults() async throws {
        let provider = StubProjectRAGProvider()
        _ = try await provider.search(query: "hello")
        #expect(provider.lastSearchQuery == "hello")
        #expect(provider.lastSearchProjectPath == nil)
        #expect(provider.lastSearchTopK == 8)
    }

    @Test("search explicit overload forwards supplied values")
    @MainActor
    func searchExplicitForwardsValues() async throws {
        let provider = StubProjectRAGProvider()
        _ = try await provider.search(query: "q", projectPath: "/proj", topK: 5)
        #expect(provider.lastSearchQuery == "q")
        #expect(provider.lastSearchProjectPath == "/proj")
        #expect(provider.lastSearchTopK == 5)
    }

    @Test("ensureIndexed convenience overload forwards force=false background=false")
    @MainActor
    func ensureIndexedConvenienceForwardsDefaults() async throws {
        let provider = StubProjectRAGProvider()
        try await provider.ensureIndexed(projectPath: "/proj")
        #expect(provider.lastEnsureProjectPath == "/proj")
        #expect(provider.lastEnsureForce == false)
        #expect(provider.lastEnsureBackground == false)
    }

    @Test("NoopProjectRAGObserverHandle cancels without side effects")
    @MainActor
    func noopHandleCancelIsSafe() {
        let handle = NoopProjectRAGObserverHandle()
        handle.cancel()
        handle.cancel()
    }
}
