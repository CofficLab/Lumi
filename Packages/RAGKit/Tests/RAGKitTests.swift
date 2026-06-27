import Foundation
import NaturalLanguage
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

@Test func testAdditionalModelInitializers() {
    let match = RAGVectorMatch(chunkId: 42, distance: 0.25)
    #expect(match.chunkId == 42)
    #expect(match.distance == 0.25)

    let decision = RAGIntentDecision(
        shouldUseRAG: true,
        score: 0.8,
        threshold: 0.5,
        reasons: ["path"]
    )
    #expect(decision.shouldUseRAG)
    #expect(decision.score == 0.8)
    #expect(decision.threshold == 0.5)
    #expect(decision.reasons == ["path"])
}

@Test func testAppleNativeEmbeddingSkipsUnsupportedDetectedLanguage() {
    let candidates = AppleNativeEmbeddingProvider.nativeEmbeddingCandidates(detected: .dutch)

    #expect(!candidates.contains(.dutch))
    #expect(candidates == [.english, .simplifiedChinese, .traditionalChinese])
}

@Test func testAppleNativeEmbeddingKeepsSupportedDetectedLanguageFirst() {
    let candidates = AppleNativeEmbeddingProvider.nativeEmbeddingCandidates(detected: .simplifiedChinese)

    #expect(candidates == [.simplifiedChinese, .english, .traditionalChinese])
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

@Test func testNormalizeProjectPathTrimsCopiedWhitespace() {
    let normalized = RAGPathUtils.normalizeProjectPath(" \n/Users/test/project/\t")
    #expect(normalized == "/Users/test/project")
}

@Test func testNormalizeProjectPathKeepsBlankInputBlank() {
    #expect(RAGPathUtils.normalizeProjectPath(" \n\t ") == "")
}

@Test func testDisplayPathWithProject() {
    let result = RAGPathUtils.displayPath(
        filePath: "/Users/test/project/src/main.swift",
        projectPath: "/Users/test/project"
    )
    #expect(result == "src/main.swift")
}

@Test func testDisplayPathRejectsSiblingProjectWithSharedPrefix() {
    let result = RAGPathUtils.displayPath(
        filePath: "/Users/test/project2/src/main.swift",
        projectPath: "/Users/test/project"
    )
    #expect(result == "/Users/test/project2/src/main.swift")
}

@Test func testDisplayPathTrimsCopiedProjectAndFilePaths() {
    let result = RAGPathUtils.displayPath(
        filePath: " \n/Users/test/project/src/main.swift\t",
        projectPath: " /Users/test/project/ \n"
    )
    #expect(result == "src/main.swift")
}

@Test func testDisplayPathForProjectRootUsesFolderName() {
    let result = RAGPathUtils.displayPath(
        filePath: "/Users/test/project",
        projectPath: "/Users/test/project"
    )
    #expect(result == "project")
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

@Test func testChunkSplitsOversizedBlockByCharacters() {
    let chunker = RAGChunker(maxLines: 10, overlapLines: 0, maxCharsPerChunk: 5)
    let chunks = chunker.chunk("abcdefghijkl")
    #expect(chunks.map(\.content) == ["abcde", "fghij", "kl"])
    #expect(chunks.map(\.index) == [0, 1, 2])
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

@Test func testIntentAnalyzerPathAndFencedCodeTriggers() {
    #expect(RAGIntentAnalyzer.shouldUseRAG(for: "look at src/main"))
    #expect(RAGIntentAnalyzer.shouldUseRAG(for: "```let value = 1```"))
}

@Test func testIntentAnalyzerNonTrigger() {
    #expect(!RAGIntentAnalyzer.shouldUseRAG(for: "你好"))
    #expect(!RAGIntentAnalyzer.shouldUseRAG(for: "hello"))
    #expect(!RAGIntentAnalyzer.shouldUseRAG(for: ""))
}

// MARK: - MockEmbeddingProvider

@Test func testHashEmbeddingBasic() throws {
    let provider = MockEmbeddingProvider(dimension: 128)
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
    let provider = MockEmbeddingProvider(dimension: 64)
    let a = try provider.embed("test string")
    let b = try provider.embed("test string")
    #expect(a == b)
}

@Test func testHashEmbeddingEmpty() throws {
    let provider = MockEmbeddingProvider(dimension: 64)
    let embedding = try provider.embed("")
    #expect(embedding.allSatisfy { $0 == 0 })
}

@Test func testHashEmbeddingBatch() throws {
    let provider = MockEmbeddingProvider(dimension: 64)
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
    #expect(provider is MockEmbeddingProvider)
    #expect(provider.dimension == 128)
}

@Test func testEmbeddingFactoryMakeAppleNativeProvider() {
    let provider = RAGEmbeddingFactory.makeAppleNativeProvider(dimension: 96)
    #expect(provider is AppleNativeEmbeddingProvider)
    #expect(provider.dimension == 96)
}

@Test func testModelIdentifierWithVersion() {
    let provider = MockEmbeddingProvider()
    #expect(provider.modelIdentifierWithVersion == "local-hash@v1")
}

// MARK: - RAGFileScanner

@Test func testShouldSkipPath() {
    #expect(RAGFileScanner.shouldSkipPath("/project/.git/config"))
    #expect(RAGFileScanner.shouldSkipPath("/project/node_modules/pkg"))
    #expect(RAGFileScanner.shouldSkipPath("/project/build/output.o"))
    // temp/ 与 SourcePackages/ 必须被跳过，避免扫描大量无关生成物
    #expect(RAGFileScanner.shouldSkipPath("/project/temp/foo.swift"))
    #expect(RAGFileScanner.shouldSkipPath("/project/SourcePackages/checkouts/Bar/Bar.swift"))
    // DerivedData 变体目录（Xcode 按 scheme 命名）必须被前缀匹配跳过
    #expect(RAGFileScanner.shouldSkipPath("/project/DerivedData-Lumi-Multilang/Build/Products/x.swift"))
    #expect(RAGFileScanner.shouldSkipPath("/project/DerivedData/Build/Products/x.swift"))
    #expect(!RAGFileScanner.shouldSkipPath("/project/src/main.swift"))
    // 不要误伤恰好以 DerivedData 开头的普通源码目录名（这里要求至少是目录名前缀）
    #expect(!RAGFileScanner.shouldSkipPath("/project/Sources/DerivedDataHelper.swift"))
}

@Test func testGrepExcludeDirPatternsCoverPrefixVariants() {
    let patterns = Set(RAGFileScanner.grepExcludeDirPatterns)
    // 精确名透传
    #expect(patterns.contains("temp"))
    #expect(patterns.contains("SourcePackages"))
    #expect(patterns.contains("build"))
    // 前缀模式以 glob 形式给出，覆盖 DerivedData-* 变体
    #expect(patterns.contains("DerivedData*"))
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

// MARK: - RAGConfiguration

@Test func testDefaultRAGConfiguration() {
    let defaultConfig = DefaultRAGConfiguration()
    #expect(!defaultConfig.verboseLogging)
    #expect(defaultConfig.pluginDatabaseDirectory().lastPathComponent == "RAGKit")

    let verboseConfig = DefaultRAGConfiguration(verboseLogging: true)
    #expect(verboseConfig.verboseLogging)
}

// MARK: - RAGFileScanner Integration

@Test func testDiscoverFilesFiltersDirectoriesExtensionsAndSizes() throws {
    let projectURL = try makeTemporaryDirectory()
    defer { try? FileManager.default.removeItem(at: projectURL) }

    try writeFile(projectURL.appendingPathComponent("Sources/Main.swift"), "print(\"hello\")")
    try writeFile(projectURL.appendingPathComponent("README.MD"), "# Title")
    try writeFile(projectURL.appendingPathComponent("build/generated.swift"), "ignored")
    try writeFile(projectURL.appendingPathComponent("node_modules/pkg/index.ts"), "ignored")
    try writeFile(projectURL.appendingPathComponent("image.png"), "ignored")
    try writeFile(projectURL.appendingPathComponent("large.swift"), String(repeating: "x", count: 64))

    let projectPath = projectURL.standardizedFileURL.path
    let files = RAGFileScanner.discoverFiles(in: projectPath, maxFileSizeBytes: 32)
    let relative = Set(files.map {
        RAGPathUtils.displayPath(
            filePath: URL(fileURLWithPath: $0).standardizedFileURL.path,
            projectPath: projectPath
        )
    })

    #expect(relative.contains("Sources/Main.swift"))
    #expect(relative.contains("README.MD"))
    #expect(!relative.contains("build/generated.swift"))
    #expect(!relative.contains("node_modules/pkg/index.ts"))
    #expect(!relative.contains("image.png"))
    #expect(!relative.contains("large.swift"))
}

@Test func testDiscoverFilesSkipsTempDerivedDataVariantsAndSourcePackages() throws {
    let projectURL = try makeTemporaryDirectory()
    defer { try? FileManager.default.removeItem(at: projectURL) }

    // 真实源码应被发现
    try writeFile(projectURL.appendingPathComponent("Sources/Main.swift"), "print(\"hello\")")
    // 这些生成/派生目录下的大量文件必须被跳过
    try writeFile(projectURL.appendingPathComponent("temp/generated.swift"), "ignored")
    try writeFile(projectURL.appendingPathComponent("SourcePackages/checkouts/Foo/Foo.swift"), "ignored")
    try writeFile(projectURL.appendingPathComponent("DerivedData-Lumi-Multilang/Build/x.swift"), "ignored")
    try writeFile(projectURL.appendingPathComponent("DerivedData/Build/y.swift"), "ignored")

    let projectPath = projectURL.standardizedFileURL.path
    let files = RAGFileScanner.discoverFiles(in: projectPath)
    let relative = Set(files.map {
        RAGPathUtils.displayPath(
            filePath: URL(fileURLWithPath: $0).standardizedFileURL.path,
            projectPath: projectPath
        )
    })

    #expect(relative.contains("Sources/Main.swift"))
    #expect(!relative.contains("temp/generated.swift"))
    #expect(!relative.contains("SourcePackages/checkouts/Foo/Foo.swift"))
    #expect(!relative.contains("DerivedData-Lumi-Multilang/Build/x.swift"))
    #expect(!relative.contains("DerivedData/Build/y.swift"))
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

@Test func testSQLiteStoreRejectsMismatchedEmbeddings() throws {
    let dbURL = FileManager.default.temporaryDirectory
        .appendingPathComponent("RAGKitTests/\(UUID().uuidString)/mismatch.sqlite")
    defer { try? FileManager.default.removeItem(at: dbURL.deletingLastPathComponent()) }

    let store = try RAGSQLiteStore(dbURL: dbURL)
    try store.migrate()

    #expect(throws: RAGError.self) {
        try store.replaceFileChunks(
            projectPath: "/test/project",
            filePath: "src/main.swift",
            modifiedTime: Date().timeIntervalSince1970,
            contentHash: "abc",
            chunks: [RAGChunk(index: 0, content: "hello")],
            embeddings: [],
            embeddingDimension: 64
        )
    }

    #expect(throws: RAGError.self) {
        try store.replaceFileChunks(
            projectPath: "/test/project",
            filePath: "src/main.swift",
            modifiedTime: Date().timeIntervalSince1970,
            contentHash: "abc",
            chunks: [RAGChunk(index: 0, content: "hello")],
            embeddings: [[1.0, 2.0]],
            embeddingDimension: 64
        )
    }
}

@Test func testSQLiteStoreLoadChunksByIDsAndFallbackCandidates() throws {
    let dbURL = FileManager.default.temporaryDirectory
        .appendingPathComponent("RAGKitTests/\(UUID().uuidString)/ids.sqlite")
    defer { try? FileManager.default.removeItem(at: dbURL.deletingLastPathComponent()) }

    let store = try RAGSQLiteStore(dbURL: dbURL)
    try store.migrate()

    try store.replaceFileChunks(
        projectPath: "/project/a",
        filePath: "/project/a/Sources/A.swift",
        modifiedTime: Date().timeIntervalSince1970,
        contentHash: "a",
        chunks: [
            RAGChunk(index: 0, content: "alpha one"),
            RAGChunk(index: 1, content: "alpha two"),
        ],
        embeddings: [[1, 0], [0, 1]],
        embeddingDimension: 2
    )
    try store.replaceFileChunks(
        projectPath: "/project/b",
        filePath: "/project/b/Sources/B.swift",
        modifiedTime: Date().timeIntervalSince1970,
        contentHash: "b",
        chunks: [RAGChunk(index: 0, content: "beta one")],
        embeddings: [[1, 1]],
        embeddingDimension: 2
    )

    let projectAChunks = try store.loadChunks(projectPath: "/project/a")
    let ids = projectAChunks.map(\.id)
    #expect(try store.loadChunksByIDs([], projectPath: "/project/a").isEmpty)
    #expect(try store.loadChunksByIDs(ids.reversed(), projectPath: "/project/a").map(\.id) == ids.reversed())
    #expect(try store.loadChunksByIDs(ids, projectPath: "/project/b").isEmpty)

    let fallback = try store.loadCandidateChunks(
        projectPath: "/project/a",
        queryTerms: ["", "   "],
        lexicalLimit: 1,
        fallbackLimit: 1
    )
    #expect(fallback.count == 1)

    let lexicalOnly = try store.loadCandidateChunks(
        projectPath: "/project/a",
        queryTerms: ["alpha"],
        lexicalLimit: 1,
        fallbackLimit: 10
    )
    #expect(lexicalOnly.count == 1)
}

@Test func testSQLiteStoreUpsertFileStateOnlyAndProjectStateUpdate() throws {
    let dbURL = FileManager.default.temporaryDirectory
        .appendingPathComponent("RAGKitTests/\(UUID().uuidString)/state.sqlite")
    defer { try? FileManager.default.removeItem(at: dbURL.deletingLastPathComponent()) }

    let store = try RAGSQLiteStore(dbURL: dbURL)
    try store.migrate()

    try store.upsertFileStateOnly(
        projectPath: "/project",
        filePath: "/project/Sources/File.swift",
        modifiedTime: 1,
        contentHash: "old"
    )
    var states = try store.fetchIndexedFileStates(projectPath: "/project")
    #expect(states["/project/Sources/File.swift"]?.contentHash == "old")

    try store.upsertFileStateOnly(
        projectPath: "/project",
        filePath: "/project/Sources/File.swift",
        modifiedTime: 2,
        contentHash: "new"
    )
    states = try store.fetchIndexedFileStates(projectPath: "/project")
    #expect(states["/project/Sources/File.swift"]?.contentHash == "new")
    #expect(states["/project/Sources/File.swift"]?.modifiedTime == 2)

    try store.upsertProjectIndexState(
        projectPath: "/project",
        fileCount: 1,
        chunkCount: 2,
        embeddingModel: "model-a",
        embeddingDimension: 8
    )
    try store.upsertProjectIndexState(
        projectPath: "/project",
        fileCount: 3,
        chunkCount: 4,
        embeddingModel: "model-b",
        embeddingDimension: 16
    )
    let state = try store.fetchProjectIndexState(projectPath: "/project")
    #expect(state?.fileCount == 3)
    #expect(state?.chunkCount == 4)
    #expect(state?.embeddingModel == "model-b")
    #expect(state?.embeddingDimension == 16)
}

// MARK: - RAGRetriever Integration

@Test func testRetrieverFallbackScoresAndDiversifiesResults() throws {
    let dbURL = FileManager.default.temporaryDirectory
        .appendingPathComponent("RAGKitTests/\(UUID().uuidString)/retriever.sqlite")
    defer { try? FileManager.default.removeItem(at: dbURL.deletingLastPathComponent()) }

    let store = try RAGSQLiteStore(dbURL: dbURL)
    try store.migrate()
    try store.configureVectorBackend(embeddingDimension: 4)

    let projectPath = "/tmp/rag-project"
    try store.replaceFileChunks(
        projectPath: projectPath,
        filePath: "\(projectPath)/Sources/Primary.swift",
        modifiedTime: Date().timeIntervalSince1970,
        contentHash: "primary",
        chunks: [
            RAGChunk(index: 0, content: "apple service entry point"),
            RAGChunk(index: 1, content: "apple service helper"),
            RAGChunk(index: 2, content: "apple service internal detail"),
        ],
        embeddings: [
            [1, 0, 0, 0],
            [1, 0, 0, 0],
            [1, 0, 0, 0],
        ],
        embeddingDimension: 4
    )
    try store.replaceFileChunks(
        projectPath: projectPath,
        filePath: "\(projectPath)/Sources/Secondary.swift",
        modifiedTime: Date().timeIntervalSince1970,
        contentHash: "secondary",
        chunks: [RAGChunk(index: 0, content: "apple service backup")],
        embeddings: [[1, 0, 0, 0]],
        embeddingDimension: 4
    )

    let retriever = RAGRetriever(store: store)
    let results = try retriever.retrieve(
        queryEmbedding: [1, 0, 0, 0],
        query: "apple service",
        projectPath: projectPath,
        topK: 3
    )

    #expect(results.count == 3)
    #expect(results.contains { $0.source == "Sources/Secondary.swift" })
    #expect(results.filter { $0.source == "Sources/Primary.swift" }.count == 2)
    #expect(results.allSatisfy { $0.score > 0 })
}

@Test func testRetrieverSkipsCandidatesWithMismatchedEmbeddingDimensions() throws {
    let dbURL = FileManager.default.temporaryDirectory
        .appendingPathComponent("RAGKitTests/\(UUID().uuidString)/retriever-dim.sqlite")
    defer { try? FileManager.default.removeItem(at: dbURL.deletingLastPathComponent()) }

    let store = try RAGSQLiteStore(dbURL: dbURL)
    try store.migrate()

    try store.replaceFileChunks(
        projectPath: "/test/project",
        filePath: "src/main.swift",
        modifiedTime: Date().timeIntervalSince1970,
        contentHash: "abc",
        chunks: [RAGChunk(index: 0, content: "matching query terms")],
        embeddings: [[1.0, 0.0]],
        embeddingDimension: 2
    )

    let retriever = RAGRetriever(store: store)
    let results = try retriever.retrieve(
        queryEmbedding: [1.0, 0.0, 0.0],
        query: "matching",
        projectPath: "/test/project",
        topK: 3
    )
    #expect(results.isEmpty)
}

// MARK: - RAGRetriever Cache Hit

@Test func testRetrieverCacheHitReturnsSameResults() throws {
    let dbURL = FileManager.default.temporaryDirectory
        .appendingPathComponent("RAGKitTests/\(UUID().uuidString)/cache-hit.sqlite")
    defer { try? FileManager.default.removeItem(at: dbURL.deletingLastPathComponent()) }

    let store = try RAGSQLiteStore(dbURL: dbURL)
    try store.migrate()
    try store.configureVectorBackend(embeddingDimension: 4)

    let projectPath = "/tmp/cache-project"
    try store.replaceFileChunks(
        projectPath: projectPath,
        filePath: "\(projectPath)/Sources/A.swift",
        modifiedTime: Date().timeIntervalSince1970,
        contentHash: "a",
        chunks: [
            RAGChunk(index: 0, content: "cached content alpha"),
            RAGChunk(index: 1, content: "cached content beta"),
        ],
        embeddings: [
            [1, 0, 0, 0],
            [0, 1, 0, 0],
        ],
        embeddingDimension: 4
    )

    // 共享 cache 实例
    let sharedCache = RAGCache(ttlSeconds: 60)
    let retriever = RAGRetriever(store: store, cache: sharedCache)

    let queryEmbedding: [Float] = [1, 0, 0, 0]
    let query = "cached content"

    // 第一次：缓存 miss，走正常检索
    let firstResults = try retriever.retrieve(
        queryEmbedding: queryEmbedding,
        query: query,
        projectPath: projectPath,
        topK: 2
    )
    #expect(firstResults.count == 2)

    // 删掉所有 chunks，如果 retriever 不走缓存就会返回空
    try store.deleteChunks(projectPath: projectPath, filePath: "\(projectPath)/Sources/A.swift")
    #expect(try store.loadChunks(projectPath: projectPath).isEmpty)

    // 第二次：应该命中缓存，返回与第一次完全相同的结果
    let secondResults = try retriever.retrieve(
        queryEmbedding: queryEmbedding,
        query: query,
        projectPath: projectPath,
        topK: 2
    )
    #expect(secondResults.count == firstResults.count)
    #expect(secondResults.map(\.content) == firstResults.map(\.content))
    #expect(secondResults.map(\.score) == firstResults.map(\.score))

    // 不同 query 应该 miss
    let missResults = try retriever.retrieve(
        queryEmbedding: queryEmbedding,
        query: "different query",
        projectPath: projectPath,
        topK: 2
    )
    #expect(missResults.isEmpty)
}

@Test func testRetrieverCacheInvalidatedOnDifferentTopK() throws {
    let dbURL = FileManager.default.temporaryDirectory
        .appendingPathComponent("RAGKitTests/\(UUID().uuidString)/cache-topk.sqlite")
    defer { try? FileManager.default.removeItem(at: dbURL.deletingLastPathComponent()) }

    let store = try RAGSQLiteStore(dbURL: dbURL)
    try store.migrate()
    try store.configureVectorBackend(embeddingDimension: 4)

    let projectPath = "/tmp/cache-topk"
    try store.replaceFileChunks(
        projectPath: projectPath,
        filePath: "\(projectPath)/Sources/A.swift",
        modifiedTime: Date().timeIntervalSince1970,
        contentHash: "a",
        chunks: [RAGChunk(index: 0, content: "hello world")],
        embeddings: [[1, 0, 0, 0]],
        embeddingDimension: 4
    )

    let sharedCache = RAGCache(ttlSeconds: 60)
    let retriever = RAGRetriever(store: store, cache: sharedCache)

    let queryEmbedding: [Float] = [1, 0, 0, 0]

    // topK=1
    let r1 = try retriever.retrieve(queryEmbedding: queryEmbedding, query: "hello", projectPath: projectPath, topK: 1)
    #expect(r1.count == 1)

    // 删掉 chunks
    try store.deleteChunks(projectPath: projectPath, filePath: "\(projectPath)/Sources/A.swift")

    // 相同 query 不同 topK → 缓存 miss（key 包含 topK）
    let r2 = try retriever.retrieve(queryEmbedding: queryEmbedding, query: "hello", projectPath: projectPath, topK: 5)
    #expect(r2.isEmpty)

    // 原始 topK=1 → 缓存命中
    let r3 = try retriever.retrieve(queryEmbedding: queryEmbedding, query: "hello", projectPath: projectPath, topK: 1)
    #expect(r3.count == 1)
}

// MARK: - RAGIndexer Integration

@Test func testIndexerRebuildAndIncrementalCleanup() throws {
    let projectURL = try makeTemporaryDirectory()
    let dbURL = FileManager.default.temporaryDirectory
        .appendingPathComponent("RAGKitTests/\(UUID().uuidString)/indexer.sqlite")
    defer {
        try? FileManager.default.removeItem(at: projectURL)
        try? FileManager.default.removeItem(at: dbURL.deletingLastPathComponent())
    }

    let indexedFile = projectURL.appendingPathComponent("Sources/Indexed.swift")
    let emptyFile = projectURL.appendingPathComponent("Sources/Empty.swift")
    let skippedFile = projectURL.appendingPathComponent("node_modules/pkg/Ignored.swift")
    try writeFile(indexedFile, "func indexed() {\n    print(\"hello\")\n}\n")
    try writeFile(emptyFile, " \n\t\n")
    try writeFile(skippedFile, "func ignored() {}")

    let store = try RAGSQLiteStore(dbURL: dbURL)
    try store.migrate()
    let indexer = RAGIndexer(store: store, embeddingProvider: MockEmbeddingProvider(dimension: 16))

    let rebuildStats = try indexer.rebuildProjectIndex(at: projectURL.path)
    #expect(rebuildStats.scannedFiles == 2)
    #expect(rebuildStats.indexedFiles == 1)
    #expect(rebuildStats.skippedFiles == 1)
    #expect(try store.countProjectFiles(projectPath: projectURL.path) == 1)
    #expect(try store.countProjectChunks(projectPath: projectURL.path) > 0)

    let status = try store.fetchProjectIndexState(projectPath: projectURL.path)
    #expect(status?.fileCount == 1)
    #expect(status?.embeddingDimension == 16)

    let unchangedStats = try indexer.indexProjectIncrementally(at: projectURL.path)
    #expect(unchangedStats.indexedFiles == 0)
    #expect(unchangedStats.skippedFiles == 2)

    try FileManager.default.removeItem(at: indexedFile)
    let cleanupStats = try indexer.indexProjectIncrementally(at: projectURL.path)
    #expect(cleanupStats.indexedFiles == 0)
    #expect(try store.countProjectFiles(projectPath: projectURL.path) == 0)
    #expect(try store.countProjectChunks(projectPath: projectURL.path) == 0)
}

@Test func testIndexerReadsUTF16SourceFiles() throws {
    let projectURL = try makeTemporaryDirectory()
    let dbURL = FileManager.default.temporaryDirectory
        .appendingPathComponent("RAGKitTests/\(UUID().uuidString)/utf16-indexer.sqlite")
    defer {
        try? FileManager.default.removeItem(at: projectURL)
        try? FileManager.default.removeItem(at: dbURL.deletingLastPathComponent())
    }

    let indexedFile = projectURL.appendingPathComponent("Sources/UTF16Searchable.swift")
    try writeFile(
        indexedFile,
        """
        struct UTF16Searchable {
            let marker = "needle utf16 retrieval target"
        }
        """,
        encoding: .utf16
    )

    let store = try RAGSQLiteStore(dbURL: dbURL)
    try store.migrate()
    let indexer = RAGIndexer(store: store, embeddingProvider: MockEmbeddingProvider(dimension: 16))

    let stats = try indexer.rebuildProjectIndex(at: projectURL.path)
    #expect(stats.scannedFiles == 1)
    #expect(stats.indexedFiles == 1)
    #expect(stats.skippedFiles == 0)
    #expect(try store.countProjectFiles(projectPath: projectURL.path) == 1)
    #expect(try store.countProjectChunks(projectPath: projectURL.path) > 0)
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

@Test func testRAGServiceThrowsBeforeInitialize() async {
    let service = RAGService(
        databaseDirectoryProvider: {
            FileManager.default.temporaryDirectory
                .appendingPathComponent("RAGKitTests/\(UUID().uuidString)")
        }
    )

    await #expect(throws: RAGError.self) {
        try await service.checkNeedsIndex(projectPath: "/test")
    }
    await #expect(throws: RAGError.self) {
        try await service.retrieve(query: "hello")
    }
}

@Test func testRAGServiceIndexStatusAndNeedsIndex() async throws {
    let projectURL = try makeTemporaryDirectory()
    let dbDirectory = FileManager.default.temporaryDirectory
        .appendingPathComponent("RAGKitTests/\(UUID().uuidString)")
    defer {
        try? FileManager.default.removeItem(at: projectURL)
        try? FileManager.default.removeItem(at: dbDirectory)
    }

    try writeFile(projectURL.appendingPathComponent("Sources/Main.swift"), "func main() { print(\"rag\") }\n")

    let service = RAGService(databaseDirectoryProvider: { dbDirectory })
    try await service.initialize()

    #expect(try await service.checkNeedsIndex(projectPath: projectURL.path))
    try await service.indexProject(at: projectURL.path)
    #expect(!(try await service.checkNeedsIndex(projectPath: projectURL.path)))

    let status = try await service.getIndexStatus(projectPath: projectURL.path)
    #expect(status?.fileCount == 1)
    #expect((status?.chunkCount ?? 0) > 0)
    #expect(status?.projectPath == projectURL.standardizedFileURL.path)

    let runtimeInfo = try await service.getRuntimeInfo()
    #expect(runtimeInfo.vectorBackend == .swiftCosine || runtimeInfo.vectorBackend == .sqliteVec)
}

@Test func testRAGServiceEnsureIndexedRetrieveAndModelMismatch() async throws {
    let projectURL = try makeTemporaryDirectory()
    let dbDirectory = FileManager.default.temporaryDirectory
        .appendingPathComponent("RAGKitTests/\(UUID().uuidString)")
    defer {
        try? FileManager.default.removeItem(at: projectURL)
        try? FileManager.default.removeItem(at: dbDirectory)
    }

    try writeFile(
        projectURL.appendingPathComponent("Sources/Searchable.swift"),
        """
        struct SearchableService {
            func answer() -> String {
                "needle retrieval target"
            }
        }
        """
    )

    let service = RAGService(databaseDirectoryProvider: { dbDirectory })
    try await service.initialize()

    try await service.ensureIndexed(projectPath: projectURL.path, force: true)
    #expect(!RAGService.isIndexing(projectPath: projectURL.path))

    try await service.ensureIndexed(projectPath: projectURL.path)
    try await service.ensureIndexed(projectPath: projectURL.path)

    let response = try await service.retrieve(query: "needle retrieval", projectPath: projectURL.path, topK: 2)
    #expect(response.hasResults)
    #expect(response.results.contains { $0.content.contains("needle retrieval target") })

    let dbURL = dbDirectory.appendingPathComponent("rag.sqlite")
    let store = try RAGSQLiteStore(dbURL: dbURL)
    try store.migrate()
    try store.upsertProjectIndexState(
        projectPath: projectURL.standardizedFileURL.path,
        fileCount: 1,
        chunkCount: 1,
        embeddingModel: "wrong-model@v0",
        embeddingDimension: 1
    )
    #expect(try await service.checkNeedsIndex(projectPath: projectURL.path))

    try await service.ensureIndexed(projectPath: projectURL.path)
    #expect(!(try await service.checkNeedsIndex(projectPath: projectURL.path)))
}

@Test func testRAGServiceBackgroundEnsureInvalidAndValidProject() async throws {
    let projectURL = try makeTemporaryDirectory()
    let dbDirectory = FileManager.default.temporaryDirectory
        .appendingPathComponent("RAGKitTests/\(UUID().uuidString)")
    defer {
        try? FileManager.default.removeItem(at: projectURL)
        try? FileManager.default.removeItem(at: dbDirectory)
    }

    try writeFile(projectURL.appendingPathComponent("Sources/Background.swift"), "let backgroundNeedle = true\n")

    let service = RAGService(databaseDirectoryProvider: { dbDirectory })
    await service.ensureIndexedBackground(projectPath: "")
    try await service.initialize()
    await service.ensureIndexedBackground(projectPath: projectURL.path, force: true)
    await service.ensureIndexedBackground(projectPath: projectURL.path, force: true)

    let status = try await waitForIndexStatus(service: service, projectPath: projectURL.path)
    #expect(status?.fileCount == 1)
    #expect(!RAGService.isIndexing(projectPath: ""))
}

// MARK: - RAGCache

@Test func testCacheSetAndGet() {
    let cache = RAGCache(ttlSeconds: 60, maxSize: 10)
    let key = cache.buildKey(query: "test", projectPath: "/project", topK: 5)
    let results = [RAGSearchResult(content: "hello", source: "a.swift", score: 0.9)]

    #expect(cache.get(key: key) == nil)
    cache.set(key: key, results: results)
    #expect(cache.get(key: key)?.count == 1)
    #expect(cache.get(key: key)?.first?.content == "hello")
}

@Test func testCacheBuildKeyDeterministic() {
    let cache = RAGCache()
    let a = cache.buildKey(query: "test", projectPath: "/p", topK: 5)
    let b = cache.buildKey(query: "test", projectPath: "/p", topK: 5)
    let c = cache.buildKey(query: "other", projectPath: "/p", topK: 5)
    #expect(a == b)
    #expect(a != c)
}

@Test func testCacheClear() {
    let cache = RAGCache(ttlSeconds: 60)
    let key = cache.buildKey(query: "test", projectPath: nil, topK: 3)
    cache.set(key: key, results: [RAGSearchResult(content: "x", source: "a", score: 1)])
    #expect(cache.get(key: key) != nil)
    cache.clear()
    #expect(cache.get(key: key) == nil)
}

@Test func testCacheExpiration() {
    let cache = RAGCache(ttlSeconds: 0.01, maxSize: 10)
    let key = "test-key"
    cache.set(key: key, results: [RAGSearchResult(content: "x", source: "a", score: 1)])
    #expect(cache.get(key: key) != nil)
    Thread.sleep(forTimeInterval: 0.05)
    #expect(cache.get(key: key) == nil)
}

@Test func testCacheMaxSizeEviction() {
    let cache = RAGCache(ttlSeconds: 60, maxSize: 2)
    cache.set(key: "a", results: [RAGSearchResult(content: "a", source: "a", score: 1)])
    cache.set(key: "b", results: [RAGSearchResult(content: "b", source: "b", score: 1)])
    cache.set(key: "c", results: [RAGSearchResult(content: "c", source: "c", score: 1)])
    // maxSize = 2, so at least one should be evicted
    let remaining = ["a", "b", "c"].filter { cache.get(key: $0) != nil }
    #expect(remaining.count <= 2)
}

// MARK: - RAGTimeout

@Test func testTimeoutSuccess() async {
    let result = await RAGTimeout.withTimeout(seconds: 5) {
        return 42
    }
    if case .success(let value) = result {
        #expect(value == 42)
    } else {
        Issue.record("Expected success, got timedOut")
    }
}

@Test func testTimeoutZeroSeconds() async {
    let result = await RAGTimeout.withTimeout(seconds: 0) {
        return "never"
    }
    if case .timedOut = result {
        // expected
    } else {
        Issue.record("Expected timedOut for seconds=0")
    }
}

@Test func testTimeoutReturnsTimedOutBeforeCancelledOperationCompletes() async {
    let start = CFAbsoluteTimeGetCurrent()
    let result = await RAGTimeout.withTimeout(seconds: 0.02) {
        try? await Task.sleep(nanoseconds: 500_000_000)
        return "late"
    }
    let elapsed = CFAbsoluteTimeGetCurrent() - start

    if case .timedOut = result {
        #expect(elapsed < 0.25)
    } else {
        Issue.record("Expected timedOut before operation completed")
    }
}

// MARK: - Test Helpers

private func makeTemporaryDirectory() throws -> URL {
    let url = FileManager.default.temporaryDirectory
        .appendingPathComponent("RAGKitTests")
        .appendingPathComponent(UUID().uuidString)
    try FileManager.default.createDirectory(at: url, withIntermediateDirectories: true)
    return url
}

private func writeFile(
    _ url: URL,
    _ content: String,
    encoding: String.Encoding = .utf8
) throws {
    try FileManager.default.createDirectory(
        at: url.deletingLastPathComponent(),
        withIntermediateDirectories: true
    )
    try content.write(to: url, atomically: true, encoding: encoding)
}

private func waitForIndexStatus(
    service: RAGService,
    projectPath: String,
    attempts: Int = 100
) async throws -> RAGIndexStatus? {
    for _ in 0..<attempts {
        if let status = try await service.getIndexStatus(projectPath: projectPath) {
            return status
        }
        try await Task.sleep(nanoseconds: 10_000_000)
    }
    return nil
}
