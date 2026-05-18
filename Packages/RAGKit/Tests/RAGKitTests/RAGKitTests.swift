import Foundation
import Testing
@testable import RAGKit

// MARK: - Models

@Test func testRAGResponseHasResults() {
    let response = RAGResponse(query: "test", results: [
        RAGSearchResult(content: "hello", source: "a.swift", score: 0.9),
    ])
    #expect(response.hasResults)

    let emptyResponse = RAGResponse(query: "test", results: [])
    #expect(!emptyResponse.hasResults)
}

@Test func testRAGIndexStatsDefaults() {
    let stats = RAGIndexStats()
    #expect(stats.scannedFiles == 0)
    #expect(stats.indexedFiles == 0)
    #expect(stats.skippedFiles == 0)
    #expect(stats.chunkCount == 0)
}

@Test func testRAGErrorDescriptions() {
    #expect(RAGError.notInitialized.errorDescription == "RAG 服务未初始化")
    #expect(RAGError.invalidProjectPath.errorDescription == "无效的项目路径")
    #expect(RAGError.internalStateCorrupted.errorDescription == "RAG 内部状态异常")
    #expect(RAGError.dbError("boom").errorDescription == "RAG 数据库错误：boom")
}

// MARK: - Utils

@Test func testFloatDataRoundTrip() {
    let original: [Float] = [1.0, 2.5, -3.14, 0.0, 42.0]
    let data = original.toData()
    let restored = [Float](data: data)
    #expect(original.count == restored.count)
    for (a, b) in zip(original, restored) {
        #expect(a == b)
    }
}

@Test func testFloatDataEmpty() {
    let empty: [Float] = []
    let data = empty.toData()
    #expect(data.isEmpty)
    let restored = [Float](data: data)
    #expect(restored.isEmpty)
}

@Test func testTokenizeChinese() {
    let tokens = RAGTextUtils.tokenize("项目代码怎么实现")
    // NOTE: CharacterSet.alphanumerics includes CJK characters on macOS,
    // so the entire Chinese string is treated as one token.
    // This is a known tokenizer limitation from the original codebase.
    #expect(tokens.count >= 1)
    #expect(tokens[0] == "项目代码怎么实现")
}

@Test func testTokenizeEnglish() {
    let tokens = RAGTextUtils.tokenize("hello world")
    #expect(tokens == ["hello", "world"])
}

@Test func testTokenizeMixed() {
    // CJK chars adjacent to English are treated as alphanumerics → one token
    let tokens = RAGTextUtils.tokenize("Swift代码")
    #expect(tokens.contains("Swift代码"))
}

@Test func testLexicalBoost() {
    let boost = RAGTextUtils.lexicalBoost(query: "代码 file", content: "this is 代码 content with file path")
    #expect(boost > 0)
}

@Test func testLexicalBoostNoMatch() {
    let boost = RAGTextUtils.lexicalBoost(query: "xyz", content: "hello world")
    #expect(boost == 0)
}

@Test func testSourcePathBoost() {
    let boost = RAGTextUtils.sourcePathBoost(queryTerms: ["rag", "service"], filePath: "/src/RAG/RAGService.swift")
    #expect(boost > 0)
}

@Test func testCosineSimilarityIdentical() {
    let vec: [Float] = [1.0, 0.0, 0.0]
    let sim = RAGMathUtils.cosineSimilarity(vec, vec)
    #expect(abs(sim - 1.0) < 0.001)
}

@Test func testCosineSimilarityOrthogonal() {
    let a: [Float] = [1.0, 0.0]
    let b: [Float] = [0.0, 1.0]
    let sim = RAGMathUtils.cosineSimilarity(a, b)
    #expect(abs(sim) < 0.001)
}

@Test func testCosineSimilarityEmpty() {
    let sim = RAGMathUtils.cosineSimilarity([], [])
    #expect(sim == 0)
}

@Test func testCosineSimilarityMismatchedLength() {
    let sim = RAGMathUtils.cosineSimilarity([1.0], [1.0, 2.0])
    #expect(sim == 0)
}

@Test func testNormalizeProjectPath() {
    let path = "/Users/test/../test/./project"
    let normalized = RAGPathUtils.normalizeProjectPath(path)
    #expect(!normalized.contains(".."))
    #expect(!normalized.contains("./"))
}

@Test func testDisplayPathWithProject() {
    let result = RAGPathUtils.displayPath(
        filePath: "/Users/test/project/src/main.swift",
        projectPath: "/Users/test/project"
    )
    #expect(result == "src/main.swift")
}

@Test func testDisplayPathWithoutProject() {
    let result = RAGPathUtils.displayPath(
        filePath: "/Users/test/project/src/main.swift",
        projectPath: nil
    )
    #expect(result == "/Users/test/project/src/main.swift")
}

@Test func testFormatDurationMilliseconds() {
    let result = RAGUtils.formatDuration(500)
    #expect(result.hasSuffix("ms"))
}

@Test func testFormatDurationSeconds() {
    let result = RAGUtils.formatDuration(2500)
    #expect(result.hasSuffix("s"))
    #expect(!result.hasSuffix("ms"))
}

@Test func testUnicodeScalarCJK() {
    #expect(Character("中").unicodeScalars.first!.isCJK)
    #expect(Character("国").unicodeScalars.first!.isCJK)
    #expect(!Character("A").unicodeScalars.first!.isCJK)
    #expect(!Character("1").unicodeScalars.first!.isCJK)
}

// MARK: - RAGChunker

@Test func testChunkBasicContent() {
    let chunker = RAGChunker(maxLines: 3, overlapLines: 0, maxCharsPerChunk: 1000)
    let content = "line1\nline2\nline3\nline4\nline5"
    let chunks = chunker.chunk(content)
    #expect(chunks.count >= 2)
    #expect(chunks[0].content.contains("line1"))
}

@Test func testChunkEmptyContent() {
    let chunker = RAGChunker()
    let chunks = chunker.chunk("")
    #expect(chunks.isEmpty)
}

@Test func testChunkSingleLine() {
    let chunker = RAGChunker()
    let chunks = chunker.chunk("single line")
    #expect(chunks.count == 1)
    #expect(chunks[0].content == "single line")
}

// MARK: - RAGIndexingRegistry

@Test func testIndexingRegistryLifecycle() {
    let registry = RAGIndexingRegistry()
    #expect(!registry.contains(projectPath: "/test"))
    #expect(!registry.hasAnyIndexing())

    registry.start(projectPath: "/test")
    #expect(registry.contains(projectPath: "/test"))
    #expect(registry.hasAnyIndexing())

    registry.finish(projectPath: "/test")
    #expect(!registry.contains(projectPath: "/test"))
    #expect(!registry.hasAnyIndexing())
}

// MARK: - RAGContextBuilder

@Test func testBuildChinesePrompt() {
    let results = [
        RAGSearchResult(content: "这是内容", source: "a.swift", score: 0.9),
    ]
    let prompt = RAGContextBuilder.buildPrompt(
        query: "测试",
        results: results,
        projectPath: "/test/project",
        languagePreference: .chinese
    )
    #expect(prompt.contains("项目路径"))
    #expect(prompt.contains("相关片段"))
}

@Test func testBuildEnglishPrompt() {
    let results = [
        RAGSearchResult(content: "some content", source: "a.swift", score: 0.9),
    ]
    let prompt = RAGContextBuilder.buildPrompt(
        query: "test",
        results: results,
        projectPath: "/test/project",
        languagePreference: .english
    )
    #expect(prompt.contains("Project path"))
    #expect(prompt.contains("Relevant snippets"))
}

@Test func testBuildPromptEmptyResults() {
    let prompt = RAGContextBuilder.buildPrompt(
        query: "test",
        results: [],
        projectPath: nil,
        languagePreference: .chinese
    )
    #expect(prompt.contains("相关片段"))
}

// MARK: - RAGIntentAnalyzer

@Test func testIntentAnalyzerCodeTriggers() {
    #expect(RAGIntentAnalyzer.shouldUseRAG(for: "这个项目的代码怎么实现"))
    #expect(RAGIntentAnalyzer.shouldUseRAG(for: "where is the main function"))
    #expect(RAGIntentAnalyzer.shouldUseRAG(for: "fix the error in RAGService.swift"))
}

@Test func testIntentAnalyzerQuestionMarkers() {
    #expect(RAGIntentAnalyzer.shouldUseRAG(for: "如何实现这个功能？"))
    #expect(RAGIntentAnalyzer.shouldUseRAG(for: "how to fix the bug?"))
}

@Test func testIntentAnalyzerCodeIntentMarkers() {
    #expect(RAGIntentAnalyzer.shouldUseRAG(for: "class MyClass {"))
    #expect(RAGIntentAnalyzer.shouldUseRAG(for: "func myMethod() {"))
}

@Test func testIntentAnalyzerNonTrigger() {
    #expect(!RAGIntentAnalyzer.shouldUseRAG(for: "你好"))
    #expect(!RAGIntentAnalyzer.shouldUseRAG(for: "hello"))
    #expect(!RAGIntentAnalyzer.shouldUseRAG(for: ""))
}

// MARK: - HashEmbeddingProvider

@Test func testHashEmbeddingBasic() throws {
    let provider = HashEmbeddingProvider(dimension: 128)
    #expect(provider.modelID == "local-hash")
    #expect(provider.modelVersion == "v1")
    #expect(provider.dimension == 128)

    let embedding = try provider.embed("hello world")
    #expect(embedding.count == 128)

    // 归一化检查
    let norm = sqrt(embedding.reduce(Float(0)) { $0 + $1 * $1 })
    #expect(abs(norm - 1.0) < 0.01)
}

@Test func testHashEmbeddingConsistency() throws {
    let provider = HashEmbeddingProvider(dimension: 64)
    let a = try provider.embed("test string")
    let b = try provider.embed("test string")
    #expect(a == b)
}

@Test func testHashEmbeddingEmpty() throws {
    let provider = HashEmbeddingProvider(dimension: 64)
    let embedding = try provider.embed("")
    #expect(embedding.allSatisfy { $0 == 0 })
}

@Test func testHashEmbeddingBatch() throws {
    let provider = HashEmbeddingProvider(dimension: 64)
    let embeddings = try provider.embedBatch(["hello", "world"])
    #expect(embeddings.count == 2)
    #expect(embeddings[0] != embeddings[1])
}

// MARK: - RAGEmbeddingFactory

@Test func testEmbeddingFactoryMakeProvider() {
    let provider = RAGEmbeddingFactory.makeProvider()
    #expect(provider is AppleNativeEmbeddingProvider)
    #expect(provider.dimension == 384)
}

@Test func testEmbeddingFactoryMakeHashProvider() {
    let provider = RAGEmbeddingFactory.makeHashProvider(dimension: 128)
    #expect(provider is HashEmbeddingProvider)
    #expect(provider.dimension == 128)
}

@Test func testModelIdentifierWithVersion() {
    let provider = HashEmbeddingProvider()
    #expect(provider.modelIdentifierWithVersion == "local-hash@v1")
}

// MARK: - RAGFileScanner

@Test func testShouldSkipPath() {
    #expect(RAGFileScanner.shouldSkipPath("/project/.git/config"))
    #expect(RAGFileScanner.shouldSkipPath("/project/node_modules/pkg"))
    #expect(RAGFileScanner.shouldSkipPath("/project/build/output.o"))
    #expect(!RAGFileScanner.shouldSkipPath("/project/src/main.swift"))
}

@Test func testAllowedExtensions() {
    #expect(RAGFileScanner.allowedExtensions.contains("swift"))
    #expect(RAGFileScanner.allowedExtensions.contains("py"))
    #expect(RAGFileScanner.allowedExtensions.contains("ts"))
    #expect(!RAGFileScanner.allowedExtensions.contains("exe"))
}

// MARK: - RAGLogger

@Test func testNullRAGLogger() {
    let logger = NullRAGLogger()
    // Should not crash
    logger.info("test")
    logger.error("test")
    logger.warning("test")
}

// MARK: - RAGLanguagePreference

@Test func testLanguagePreferenceEquality() {
    #expect(RAGLanguagePreference.chinese == RAGLanguagePreference.chinese)
    #expect(RAGLanguagePreference.chinese != RAGLanguagePreference.english)
}

// MARK: - RAGSQLiteStore (Integration)

@Test func testSQLiteStoreContentHash() {
    let hash1 = RAGSQLiteStore.contentHash("hello")
    let hash2 = RAGSQLiteStore.contentHash("hello")
    let hash3 = RAGSQLiteStore.contentHash("world")
    #expect(hash1 == hash2)
    #expect(hash1 != hash3)
    #expect(hash1.count == 64) // SHA256 hex
}

@Test func testSQLiteStoreCRUD() throws {
    let dbURL = FileManager.default.temporaryDirectory
        .appendingPathComponent("RAGKitTests/\(UUID().uuidString)/test.sqlite")

    let store = try RAGSQLiteStore(dbURL: dbURL)
    try store.migrate()

    // Configure with hash embedding dimension (no sqlite-vec needed)
    try store.configureVectorBackend(embeddingDimension: 64)

    // Verify runtime info
    #expect(store.runtimeInfo.vectorBackend == .swiftCosine)

    let projectPath = "/test/project"

    // Insert chunks
    let chunks = [
        RAGChunk(index: 0, content: "hello world"),
        RAGChunk(index: 1, content: "foo bar"),
    ]
    let embeddings: [[Float]] = [
        [1.0, 0.0, 0.0] + [Float](repeating: 0, count: 61),
        [0.0, 1.0, 0.0] + [Float](repeating: 0, count: 61),
    ]

    try store.replaceFileChunks(
        projectPath: projectPath,
        filePath: "src/main.swift",
        modifiedTime: Date().timeIntervalSince1970,
        contentHash: RAGSQLiteStore.contentHash("content"),
        chunks: chunks,
        embeddings: embeddings,
        embeddingDimension: 64
    )

    // Verify file states
    let fileStates = try store.fetchIndexedFileStates(projectPath: projectPath)
    #expect(fileStates.count == 1)
    #expect(fileStates["src/main.swift"] != nil)

    // Verify chunks loaded
    let loadedChunks = try store.loadChunks(projectPath: projectPath)
    #expect(loadedChunks.count == 2)

    // Verify counts
    #expect(try store.countProjectFiles(projectPath: projectPath) == 1)
    #expect(try store.countProjectChunks(projectPath: projectPath) == 2)

    // Verify index state
    try store.upsertProjectIndexState(
        projectPath: projectPath,
        fileCount: 1,
        chunkCount: 2,
        embeddingModel: "local-hash@v1",
        embeddingDimension: 64
    )
    let indexState = try store.fetchProjectIndexState(projectPath: projectPath)
    #expect(indexState != nil)
    #expect(indexState!.fileCount == 1)
    #expect(indexState!.chunkCount == 2)

    // Delete chunks
    try store.deleteChunks(projectPath: projectPath, filePath: "src/main.swift")
    let afterDelete = try store.loadChunks(projectPath: projectPath)
    #expect(afterDelete.isEmpty)

    // Cleanup
    try? FileManager.default.removeItem(at: dbURL.deletingLastPathComponent())
}

@Test func testSQLiteStoreLoadCandidateChunks() throws {
    let dbURL = FileManager.default.temporaryDirectory
        .appendingPathComponent("RAGKitTests/\(UUID().uuidString)/candidate.sqlite")

    let store = try RAGSQLiteStore(dbURL: dbURL)
    try store.migrate()

    let projectPath = "/test/project"
    let embedding: [Float] = [1.0, 0.0] + [Float](repeating: 0, count: 62)

    // Insert a chunk with known content
    try store.replaceFileChunks(
        projectPath: projectPath,
        filePath: "src/RAGService.swift",
        modifiedTime: Date().timeIntervalSince1970,
        contentHash: "abc",
        chunks: [RAGChunk(index: 0, content: "RAGService handles indexing and retrieval")],
        embeddings: [embedding],
        embeddingDimension: 64
    )

    // Search by terms
    let candidates = try store.loadCandidateChunks(
        projectPath: projectPath,
        queryTerms: ["ragservice", "indexing"],
        lexicalLimit: 100,
        fallbackLimit: 1000
    )
    #expect(candidates.count == 1)
    #expect(candidates[0].content.contains("RAGService"))

    // Cleanup
    try? FileManager.default.removeItem(at: dbURL.deletingLastPathComponent())
}

// MARK: - RAGService Integration

@Test func testRAGServiceInitialize() async throws {
    let service = RAGService(
        databaseDirectoryProvider: {
            FileManager.default.temporaryDirectory
                .appendingPathComponent("RAGKitTests/\(UUID().uuidString)")
        }
    )
    #expect(!service.isInitialized)

    try await service.initialize()
    #expect(service.isInitialized)

    // Double initialize should be idempotent
    try await service.initialize()
    #expect(service.isInitialized)
}

@Test func testRAGServiceRetrieveEmptyQuery() async throws {
    let service = RAGService(
        databaseDirectoryProvider: {
            FileManager.default.temporaryDirectory
                .appendingPathComponent("RAGKitTests/\(UUID().uuidString)")
        }
    )
    try await service.initialize()

    let response = try await service.retrieve(query: "  ", projectPath: "/test")
    #expect(!response.hasResults)
    #expect(response.results.isEmpty)
}
