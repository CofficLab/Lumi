import Foundation
import LumiKernel
import Testing
@testable import ProjectRAGPlugin

private final class RecordingRAGStore: RAGStore, @unchecked Sendable {
    private(set) var requestedLexicalLimit: Int?
    private(set) var requestedFallbackLimit: Int?

    func fetchIndexedFileStates(projectPath: String) throws -> [String: RAGIndexedFileState] { [:] }
    func replaceFileChunks(projectPath: String, filePath: String, modifiedTime: Double, contentHash: String, chunks: [RAGChunk], embeddings: [[Float]], embeddingDimension: Int) throws {}
    func deleteChunks(projectPath: String, filePath: String) throws {}
    func deleteFileState(projectPath: String, filePath: String) throws {}
    func upsertFileStateOnly(projectPath: String, filePath: String, modifiedTime: Double, contentHash: String) throws {}
    func upsertProjectIndexState(projectPath: String, fileCount: Int, chunkCount: Int, embeddingModel: String, embeddingDimension: Int) throws {}
    func loadChunks(projectPath: String?, limit: Int?) throws -> [RAGStoredChunk] { [] }
    func loadCandidateChunks(projectPath: String?, queryTerms: [String], lexicalLimit: Int, fallbackLimit: Int) throws -> [RAGStoredChunk] {
        requestedLexicalLimit = lexicalLimit
        requestedFallbackLimit = fallbackLimit
        return [RAGStoredChunk(id: 1, content: "needle", filePath: "Sources/Test.swift", embedding: [1, 0])]
    }
    func loadChunksByIDs(_ chunkIDs: [Int64], projectPath: String?) throws -> [RAGStoredChunk] { [] }
    func fetchProjectIndexState(projectPath: String) throws -> RAGProjectIndexState? { nil }
    func countProjectFiles(projectPath: String) throws -> Int { 0 }
    func countProjectChunks(projectPath: String) throws -> Int { 0 }
    func searchNearestVectors(queryEmbedding: [Float], limit: Int) throws -> [RAGVectorMatch]? { [] }
}

// MARK: - vec0.dylib 加载测试

@Test func vec0DylibBundledInPackageResources() {
    let url = Bundle.module.url(forResource: "vec0", withExtension: "dylib")
    #expect(url != nil, "vec0.dylib 应存在于 ProjectRAGPlugin 的资源 bundle 中")
}

@Test func sqliteVecBackendLoadsSuccessfully() throws {
    let dbURL = FileManager.default.temporaryDirectory
        .appendingPathComponent("ProjectRAGPluginTests")
        .appendingPathComponent("\(UUID().uuidString).sqlite")
    defer { try? FileManager.default.removeItem(at: dbURL) }

    let store = try RAGSQLiteStore(dbURL: dbURL)
    try store.migrate()
    try store.configureVectorBackend(embeddingDimension: 256)

    #expect(store.runtimeInfo.vectorBackend == .sqliteVec,
           "vec0.dylib 加载应成功，实际: \(store.runtimeInfo.note ?? "")")
}

// MARK: - 原有测试

@Test func packageLoads() async throws {
    #expect(true)
}

@Test @MainActor func pluginExposesCodeSearchAgentTool() {
    let tools = ProjectRAGPlugin().agentTools(kernel: LumiKernel())
    #expect(tools.map(\.name).contains(RAGCodeSearchTool.info.id))
}

@Test func searchCodeSchemaDeclaresBoundedControls() throws {
    let schema = RAGCodeSearchTool().inputSchema

    guard case .object(let keys) = schema,
          case .object(let properties) = keys["properties"] else {
        Issue.record("schema should declare properties object")
        return
    }

    if case .object(let topK) = properties["topK"] {
        if case .string(let type) = topK["type"] {
            #expect(type == "integer")
        } else {
            Issue.record("topK type missing")
        }
        if case .int(let minimum) = topK["minimum"] {
            #expect(minimum == RAGCodeSearchTool.minTopK)
        } else {
            Issue.record("topK minimum missing")
        }
        if case .int(let maximum) = topK["maximum"] {
            #expect(maximum == RAGCodeSearchTool.maxTopK)
        } else {
            Issue.record("topK maximum missing")
        }
    } else {
        Issue.record("topK property missing")
    }

    if case .object(let timeout) = properties["timeout"] {
        if case .string(let type) = timeout["type"] {
            #expect(type == "integer")
        } else {
            Issue.record("timeout type missing")
        }
        if case .int(let minimum) = timeout["minimum"] {
            #expect(minimum == Int(RAGCodeSearchTool.minTimeoutSeconds))
        } else {
            Issue.record("timeout minimum missing")
        }
        if case .int(let maximum) = timeout["maximum"] {
            #expect(maximum == Int(RAGCodeSearchTool.maxTimeoutSeconds))
        } else {
            Issue.record("timeout maximum missing")
        }
    } else {
        Issue.record("timeout property missing")
    }
}

@Test func searchCodeNormalizesUserControlledBounds() {
    #expect(RAGCodeSearchTool.normalizedTopK(nil) == RAGCodeSearchTool.defaultTopK)
    #expect(RAGCodeSearchTool.normalizedTopK(-10) == RAGCodeSearchTool.minTopK)
    #expect(RAGCodeSearchTool.normalizedTopK(12) == 12)
    #expect(RAGCodeSearchTool.normalizedTopK(999) == RAGCodeSearchTool.maxTopK)
    #expect(RAGCodeSearchTool.normalizedTimeout(nil) == RAGCodeSearchTool.defaultTimeoutSeconds)
    #expect(RAGCodeSearchTool.normalizedTimeout(0) == RAGCodeSearchTool.minTimeoutSeconds)
    #expect(RAGCodeSearchTool.normalizedTimeout(30) == 30)
    #expect(RAGCodeSearchTool.normalizedTimeout(999) == RAGCodeSearchTool.maxTimeoutSeconds)
}

@Test func keywordSearchFindsUTF16SourceFiles() async throws {
    let projectURL = FileManager.default.temporaryDirectory
        .appendingPathComponent("ProjectRAGPluginTests")
        .appendingPathComponent(UUID().uuidString)
    defer { try? FileManager.default.removeItem(at: projectURL) }

    let fileURL = projectURL.appendingPathComponent("Sources/UTF16Searchable.swift")
    try FileManager.default.createDirectory(
        at: fileURL.deletingLastPathComponent(),
        withIntermediateDirectories: true
    )
    try """
    @MainActor
    struct UTF16Searchable {
        let marker = "needle utf16 keyword target"
    }
    """.write(to: fileURL, atomically: true, encoding: .utf16)

    let context = LumiToolExecutionContextState(
        conversationID: UUID(),
        toolCallID: "test-search-code",
        toolName: "search_code",
        currentProjectPath: projectURL.path,
        allowedDirectories: [projectURL.path]
    )
    let kernel = await MainActor.run { LumiKernel() }
    let output = try await kernel.withToolExecutionContextState(context) {
        try await RAGCodeSearchTool().execute(
            arguments: [
                "query": .string("needle utf16 keyword target"),
                "mode": .string("keyword"),
                "projectPath": .string(projectURL.path),
            ],
            kernel: kernel
        )
    }

    #expect(output.contains("UTF16Searchable.swift"))
    #expect(output.contains("needle utf16 keyword target"))
}

@Test func keywordSearchClampsOversizedTopK() async throws {
    let projectURL = FileManager.default.temporaryDirectory
        .appendingPathComponent("ProjectRAGPluginTests")
        .appendingPathComponent(UUID().uuidString)
    defer { try? FileManager.default.removeItem(at: projectURL) }

    let sourcesURL = projectURL.appendingPathComponent("Sources", isDirectory: true)
    try FileManager.default.createDirectory(at: sourcesURL, withIntermediateDirectories: true)
    for index in 1...25 {
        let fileURL = sourcesURL.appendingPathComponent("Match\(index).swift")
        try """
        @MainActor
        struct Match\(index) {
            let marker = "bounded topk target"
        }
        """.write(to: fileURL, atomically: true, encoding: .utf8)
    }

    let context = LumiToolExecutionContextState(
        conversationID: UUID(),
        toolCallID: "test-search-code-topk",
        toolName: "search_code",
        currentProjectPath: projectURL.path,
        allowedDirectories: [projectURL.path]
    )
    let kernel = await MainActor.run { LumiKernel() }
    let output = try await kernel.withToolExecutionContextState(context) {
        try await RAGCodeSearchTool().execute(
            arguments: [
                "query": .string("bounded topk target"),
                "mode": .string("keyword"),
                "projectPath": .string(projectURL.path),
                "topK": .int(999),
            ],
            kernel: kernel
        )
    }

    #expect(output.contains("Results: \(RAGCodeSearchTool.maxTopK)"))
    #expect(!output.contains("### \(RAGCodeSearchTool.maxTopK + 1)."))
}

@Test func processCaptureHandlesLargeStdoutWithoutPipeBackpressure() async throws {
    let result = try RAGCodeSearchTool.runProcessCapturingStdout(
        executableURL: URL(fileURLWithPath: "/bin/sh"),
        arguments: [
            "-c",
            """
            i=1
            while [ "$i" -le 300 ]; do
              printf 'rag-grep-%03d-%0512d\\n' "$i" 0
              i=$((i + 1))
            done
            """
        ],
        timeout: 5
    )

    let output = String(data: result?.stdout ?? Data(), encoding: .utf8) ?? ""
    #expect(result?.terminationStatus == 0)
    #expect(output.contains("rag-grep-300-"))
    #expect((result?.stdout.count ?? 0) > 150_000)
}

@Test func cacheRemainsBounded() throws {
    let cache = RAGCache(ttlSeconds: 60, maxSize: 2)
    cache.set(key: "a", results: [RAGSearchResult(content: "a", source: "a", score: 1)])
    cache.set(key: "b", results: [RAGSearchResult(content: "b", source: "b", score: 1)])
    cache.set(key: "c", results: [RAGSearchResult(content: "c", source: "c", score: 1)])

    #expect(cache.get(key: "a") == nil)
    #expect(cache.get(key: "b") != nil)
    #expect(cache.get(key: "c") != nil)
}

@Test func timeoutCancelsCooperativeOperation() async throws {
    actor CancellationState {
        var cancelled = false
        func markCancelled() { cancelled = true }
        func value() -> Bool { cancelled }
    }

    let state = CancellationState()
    let result = await RAGTimeout.withTimeout(seconds: 0.01) {
        do {
            try await Task.sleep(for: .seconds(1))
        } catch {
            await state.markCancelled()
        }
        return 1
    }

    if case .timedOut = result {
        // expected
    } else {
        Issue.record("operation should time out")
    }
    try await Task.sleep(for: .milliseconds(20))
    #expect(await state.value())
}

@Test func retrieverUsesBoundedCandidateLimits() throws {
    let store = RecordingRAGStore()
    let retriever = RAGRetriever(store: store, cache: RAGCache(maxSize: 1))
    _ = try retriever.retrieve(
        queryEmbedding: [1, 0],
        query: "needle",
        projectPath: "/project",
        topK: 8
    )

    #expect(store.requestedLexicalLimit == RAGRetriever.lexicalCandidateLimit)
    #expect(store.requestedFallbackLimit == 1_000)
    #expect(store.requestedFallbackLimit ?? .max <= RAGRetriever.fallbackCandidateLimit)
}

@Test func sqliteCandidateLoadingDoesNotExceedTotalFallbackLimit() throws {
    let dbURL = FileManager.default.temporaryDirectory
        .appendingPathComponent("ProjectRAGPluginTests")
        .appendingPathComponent("(UUID().uuidString).sqlite")
    defer { try? FileManager.default.removeItem(at: dbURL) }

    let store = try RAGSQLiteStore(dbURL: dbURL)
    try store.migrate()
    let chunks = (0..<6).map { index in
        RAGChunk(index: index, content: index == 0 ? "needle (index)" : "ordinary (index)")
    }
    try store.replaceFileChunks(
        projectPath: "/project",
        filePath: "/project/Sources/Test.swift",
        modifiedTime: 1,
        contentHash: "hash",
        chunks: chunks,
        embeddings: chunks.map { _ in [Float](repeating: 0, count: 2) },
        embeddingDimension: 2
    )

    let results = try store.loadCandidateChunks(
        projectPath: "/project",
        queryTerms: ["needle"],
        lexicalLimit: 3,
        fallbackLimit: 5
    )
    #expect(results.count <= 5)
}
