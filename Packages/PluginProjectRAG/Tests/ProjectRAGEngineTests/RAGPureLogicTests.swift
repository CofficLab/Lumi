import Testing
import Foundation
@testable import ProjectRAGEngine

/// Unit tests for the pure-logic RAG helpers: chunker, math, text, path, and
/// intent analysis. None of these touch the filesystem, embedding providers,
/// or SQLite.
@Suite struct RAGChunkerTests {

    @Test func chunkEmptyInputReturnsEmpty() {
        let chunks = RAGChunker().chunk("")
        #expect(chunks.isEmpty)
    }

    @Test func chunkSingleBlockProducesOneChunk() {
        let content = (0..<10).map { "line \($0)" }.joined(separator: "\n")
        let chunks = RAGChunker(maxLines: 80, overlapLines: 20).chunk(content)
        #expect(chunks.count == 1)
        #expect(chunks[0].index == 0)
        #expect(chunks[0].content.contains("line 0"))
        #expect(chunks[0].content.contains("line 9"))
        #expect(chunks[0].lineRange == RAGLineRange(startLine: 1, endLine: 10))
    }

    @Test func chunkProducesOverlapAcrossBlocks() {
        // 10 lines, maxLines 4, overlap 2 → windows: [0-3], [2-5], [4-7], [6-9]
        let content = (0..<10).map { "line \($0)" }.joined(separator: "\n")
        let chunks = RAGChunker(maxLines: 4, overlapLines: 2).chunk(content)
        #expect(chunks.count >= 3)
        // Overlap means "line 2"/"line 3" must appear in more than one chunk.
        let mentionsOfLine2 = chunks.filter { $0.content.contains("line 2") }.count
        #expect(mentionsOfLine2 >= 2)
        #expect(chunks[0].lineRange == RAGLineRange(startLine: 1, endLine: 4))
        #expect(chunks[1].lineRange == RAGLineRange(startLine: 3, endLine: 6))
    }

    @Test func chunkSkipsWhitespaceOnlyBlocks() {
        let content = "   \n\n   \nreal content"
        let chunks = RAGChunker(maxLines: 80, overlapLines: 0).chunk(content)
        // Only the non-empty trimmed block should remain.
        #expect(chunks.count == 1)
        #expect(chunks[0].content == "real content")
    }

    @Test func chunkSplitsOversizedBlockByCharWindow() {
        // A single long line exceeding maxCharsPerChunk must be split.
        let longLine = String(repeating: "a", count: 500)
        let chunks = RAGChunker(maxLines: 80, overlapLines: 0, maxCharsPerChunk: 100).chunk(longLine)
        #expect(chunks.count > 1)
        // Each chunk's content must not exceed the window (after trim).
        for c in chunks {
            #expect(c.content.count <= 100)
            #expect(c.lineRange == RAGLineRange(startLine: 1, endLine: 1))
        }
    }

    @Test func chunkAssignsSequentialIndices() {
        let content = (0..<30).map { "line \($0)" }.joined(separator: "\n")
        let chunks = RAGChunker(maxLines: 5, overlapLines: 1).chunk(content)
        #expect(chunks.map(\.index) == Array(0..<chunks.count))
    }
}

@Suite struct RAGMathUtilsTests {

    @Test func cosineSimilarityIdenticalVectors() {
        let v: [Float] = [1, 2, 3]
        #expect(abs(RAGMathUtils.cosineSimilarity(v, v) - 1) < 1e-5)
    }

    @Test func cosineSimilarityOrthogonalVectors() {
        let a: [Float] = [1, 0]
        let b: [Float] = [0, 1]
        #expect(RAGMathUtils.cosineSimilarity(a, b) == 0)
    }

    @Test func cosineSimilarityOppositeVectors() {
        let a: [Float] = [1, 1]
        let b: [Float] = [-1, -1]
        #expect(abs(RAGMathUtils.cosineSimilarity(a, b) - (-1)) < 1e-5)
    }

    @Test func cosineSimilarityMismatchedLengths() {
        #expect(RAGMathUtils.cosineSimilarity([1, 2], [1]) == 0)
    }

    @Test func cosineSimilarityEmptyVectors() {
        #expect(RAGMathUtils.cosineSimilarity([], []) == 0)
    }

    @Test func cosineSimilarityZeroMagnitude() {
        #expect(RAGMathUtils.cosineSimilarity([0, 0], [1, 1]) == 0)
    }

    @Test func cosineSimilarityKnownValue() {
        // cos(60°) between [1,0] and [1, √3] ≈ 0.5
        let a: [Float] = [1, 0]
        let b: [Float] = [1, Float(3).squareRoot()]
        #expect(abs(RAGMathUtils.cosineSimilarity(a, b) - 0.5) < 1e-5)
    }
}

@Suite struct RAGTextUtilsTests {

    @Test func tokenizeSplitsAsciiWords() {
        let tokens = RAGTextUtils.tokenize("hello world swift")
        #expect(tokens == ["hello", "world", "swift"])
    }

    @Test func tokenizeSplitsCjkIntoScalars() {
        // Each CJK character becomes its own token; Latin words stay grouped.
        let tokens = RAGTextUtils.tokenize("swift代码 review")
        #expect(tokens.contains("swift"))
        #expect(tokens.contains("代"))
        #expect(tokens.contains("码"))
        #expect(tokens.contains("review"))
    }

    @Test func tokenizeHandlesPunctuation() {
        let tokens = RAGTextUtils.tokenize("foo, bar; baz()")
        #expect(tokens == ["foo", "bar", "baz"])
    }

    @Test func tokenizeEmptyString() {
        #expect(RAGTextUtils.tokenize("").isEmpty)
    }

    @Test func lexicalBoostFullHit() {
        let score = RAGTextUtils.lexicalBoost(query: "auth login", content: "auth and login logic")
        #expect(score == 1.0)
    }

    @Test func lexicalBoostPartialHit() {
        let score = RAGTextUtils.lexicalBoost(query: "auth login token", content: "auth logic only")
        // 1 of 3 query tokens hit.
        #expect(abs(score - (1.0 / 3.0)) < 1e-5)
    }

    @Test func lexicalBoostNoHit() {
        let score = RAGTextUtils.lexicalBoost(query: "auth", content: "completely unrelated")
        #expect(score == 0)
    }

    @Test func lexicalBoostEmptyQuery() {
        #expect(RAGTextUtils.lexicalBoost(query: "!!!", content: "anything") == 0)
    }

    @Test func sourcePathBoostScoresHits() {
        let score = RAGTextUtils.sourcePathBoost(queryTerms: ["auth", "login"], filePath: "/src/Auth/login.swift")
        #expect(score == 1.0)
    }

    @Test func sourcePathBoostEmptyTerms() {
        #expect(RAGTextUtils.sourcePathBoost(queryTerms: [], filePath: "/x") == 0)
    }

    @Test func sourcePathBoostDoesNotMatchPartialPathToken() {
        let score = RAGTextUtils.sourcePathBoost(queryTerms: ["auth"], filePath: "/src/author.swift")
        #expect(score == 0)
    }
}

@Suite struct RAGPathUtilsTests {

    @Test func normalizeProjectPathStripsTrailingSlash() {
        #expect(RAGPathUtils.normalizeProjectPath("/foo/bar/") == "/foo/bar")
    }

    @Test func normalizeProjectPathEmptyReturnsEmpty() {
        #expect(RAGPathUtils.normalizeProjectPath("   ") == "")
    }

    @Test func normalizeProjectPathResolvesRelative() {
        #expect(RAGPathUtils.normalizeProjectPath("/foo/./bar") == "/foo/bar")
    }

    @Test func displayPathStripsProjectPrefix() {
        let result = RAGPathUtils.displayPath(
            filePath: "/proj/src/main.swift", projectPath: "/proj"
        )
        #expect(result == "src/main.swift")
    }

    @Test func displayPathReturnsLastComponentWhenEqualsProject() {
        let result = RAGPathUtils.displayPath(filePath: "/proj", projectPath: "/proj")
        #expect(result == "proj")
    }

    @Test func displayPathWithoutProjectReturnsNormalizedPath() {
        let result = RAGPathUtils.displayPath(filePath: "/proj/file.swift", projectPath: nil)
        #expect(result == "/proj/file.swift")
    }

    @Test func displayPathReturnsFullPathWhenOutsideProject() {
        let result = RAGPathUtils.displayPath(filePath: "/other/x.swift", projectPath: "/proj")
        #expect(result == "/other/x.swift")
    }
}

@Suite struct RAGIntentAnalyzerTests {

    @Test func shouldUseRAGEmptyMessageReturnsFalse() {
        #expect(RAGIntentAnalyzer.shouldUseRAG(for: "   ") == false)
    }

    @Test func shouldUseRAGChineseTrigger() {
        #expect(RAGIntentAnalyzer.shouldUseRAG(for: "这个项目的代码怎么实现的") == true)
    }

    @Test func shouldUseRAGEnglishTrigger() {
        #expect(RAGIntentAnalyzer.shouldUseRAG(for: "where is the auth function") == true)
    }

    @Test func shouldUseRAGFilePathReference() {
        #expect(RAGIntentAnalyzer.shouldUseRAG(for: "look at src/auth/login.swift") == true)
    }

    @Test func shouldUseRAGCodeMarker() {
        #expect(RAGIntentAnalyzer.shouldUseRAG(for: "we have `func main()` here") == true)
    }

    @Test func shouldUseRAGQuestionWithCodeWord() {
        #expect(RAGIntentAnalyzer.shouldUseRAG(for: "can you explain the module?") == true)
    }

    @Test func shouldNotUseRAGForCasualQuestion() {
        #expect(RAGIntentAnalyzer.shouldUseRAG(for: "hello, how are you today") == false)
    }

    @Test func shouldNotUseRAGForEnglishSubstring() {
        #expect(RAGIntentAnalyzer.shouldUseRAG(for: "the prefix is valid") == false)
    }

    @Test func shouldUseRAGRejectsPlainStatement() {
        #expect(RAGIntentAnalyzer.shouldUseRAG(for: "thanks that sounds great") == false)
    }
}

@Suite struct UnicodeScalarCJKTests {

    @Test func commonCJKIsDetected() {
        #expect("代".unicodeScalars.first?.isCJK == true)
        #expect("码".unicodeScalars.first?.isCJK == true)
        #expect("文".unicodeScalars.first?.isCJK == true)
    }

    @Test func asciiIsNotCJK() {
        #expect("a".unicodeScalars.first?.isCJK == false)
        #expect("Z".unicodeScalars.first?.isCJK == false)
        #expect("0".unicodeScalars.first?.isCJK == false)
    }

    @Test func extensionAFromCJKIsDetected() {
        // U+3400 is in the CJK Extension A range.
        #expect(UnicodeScalar(0x3400)!.isCJK)
    }
}

@Suite struct RAGFileScannerTests {

    @Test func shouldSkipKnownBuildAndVcsDirs() {
        #expect(RAGFileScanner.shouldSkipPath("/project/.git/config"))
        #expect(RAGFileScanner.shouldSkipPath("/project/node_modules/pkg"))
        #expect(RAGFileScanner.shouldSkipPath("/project/build/output.o"))
        #expect(RAGFileScanner.shouldSkipPath("/project/.build/foo.swift"))
        #expect(!RAGFileScanner.shouldSkipPath("/project/Sources/main.swift"))
    }

    @Test func shouldSkipTempAndSourcePackages() {
        // 这两个目录在大项目里常含数万个无关文件，必须被跳过，否则 search_code 会卡死。
        #expect(RAGFileScanner.shouldSkipPath("/project/temp/generated.swift"))
        #expect(RAGFileScanner.shouldSkipPath("/project/SourcePackages/checkouts/Foo.swift"))
    }

    @Test func shouldSkipDerivedDataVariantsByPrefix() {
        // Xcode 按 scheme 生成 DerivedData-Lumi-* 变体目录，无法精确匹配，靠前缀跳过。
        #expect(RAGFileScanner.shouldSkipPath("/project/DerivedData-Lumi-Multilang/Build/x.swift"))
        #expect(RAGFileScanner.shouldSkipPath("/project/DerivedData-Lumi-PluginDescriptionLocalization/Build/y.swift"))
        #expect(RAGFileScanner.shouldSkipPath("/project/DerivedData/Build/z.swift"))
        // 不要误伤恰好包含该前缀的普通源码文件名
        #expect(!RAGFileScanner.shouldSkipPath("/project/Sources/DerivedDataHelper.swift"))
    }

    @Test func grepExcludeDirPatternsCoverExactNamesAndPrefixGlobs() {
        let patterns = Set(RAGFileScanner.grepExcludeDirPatterns)
        #expect(patterns.contains("temp"))
        #expect(patterns.contains("SourcePackages"))
        #expect(patterns.contains("build"))
        // 前缀模式以 glob 形式给出，让 grep 一次性排除 DerivedData-* 全部变体
        #expect(patterns.contains("DerivedData*"))
    }

    @Test func discoverFilesCachedReturnsSameResultsAsUncached() throws {
        // 缓存路径应与直接扫描返回一致的结果集
        let projectURL = FileManager.default.temporaryDirectory
            .appendingPathComponent("rag-cache-test-\(UUID().uuidString)", isDirectory: true)
        try FileManager.default.createDirectory(at: projectURL, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: projectURL) }

        try "print(1)".write(toFile: projectURL.appendingPathComponent("A.swift").path, atomically: true, encoding: .utf8)
        try "print(2)".write(toFile: projectURL.appendingPathComponent("B.swift").path, atomically: true, encoding: .utf8)

        let direct = Set(RAGFileScanner.discoverFiles(in: projectURL.path))
        let cached = Set(RAGFileScanner.discoverFilesCached(in: projectURL.path))

        #expect(!direct.isEmpty)
        #expect(direct == cached)
    }
}

@Suite struct RAGLexicalFileSearcherTests {

    @Test func findsMatchingSourceWithoutAnIndex() throws {
        let projectURL = FileManager.default.temporaryDirectory
            .appendingPathComponent("rag-lexical-search-\(UUID().uuidString)", isDirectory: true)
        try FileManager.default.createDirectory(at: projectURL, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: projectURL) }

        let sourceURL = projectURL.appendingPathComponent("Sources/RequestHandler.swift")
        try FileManager.default.createDirectory(at: sourceURL.deletingLastPathComponent(), withIntermediateDirectories: true)
        try "func handleRequest() {}".write(to: sourceURL, atomically: true, encoding: .utf8)

        let results = try RAGLexicalFileSearcher.search(
            query: "handleRequest",
            projectPath: projectURL.path,
            topK: 3
        )

        #expect(results.count == 1)
        #expect(results[0].source == "Sources/RequestHandler.swift")
        #expect(results[0].content.contains("handleRequest"))
        #expect(results[0].matchKind == .filesystemLexical)
        #expect(results[0].lineRange == RAGLineRange(startLine: 1, endLine: 1))
    }

    @Test func respectsSearchFileFilters() throws {
        let projectURL = FileManager.default.temporaryDirectory
            .appendingPathComponent("rag-lexical-filters-\(UUID().uuidString)", isDirectory: true)
        try FileManager.default.createDirectory(at: projectURL, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: projectURL) }

        let query = "filterBoundaryToken"
        let visibleURL = projectURL.appendingPathComponent("Sources/Visible.swift")
        let generatedURL = projectURL.appendingPathComponent("build/Generated.swift")
        let notesURL = projectURL.appendingPathComponent("Notes.log")
        try FileManager.default.createDirectory(at: visibleURL.deletingLastPathComponent(), withIntermediateDirectories: true)
        try FileManager.default.createDirectory(at: generatedURL.deletingLastPathComponent(), withIntermediateDirectories: true)
        try "let value = \(query)".write(to: visibleURL, atomically: true, encoding: .utf8)
        try "let value = \(query)".write(to: generatedURL, atomically: true, encoding: .utf8)
        try query.write(to: notesURL, atomically: true, encoding: .utf8)

        let results = try RAGLexicalFileSearcher.search(
            query: query,
            projectPath: projectURL.path,
            topK: 10
        )

        #expect(results.map(\.source) == ["Sources/Visible.swift"])
    }

    @Test func includesContextAroundRipgrepMatch() throws {
        let projectURL = FileManager.default.temporaryDirectory
            .appendingPathComponent("rag-lexical-context-\(UUID().uuidString)", isDirectory: true)
        try FileManager.default.createDirectory(at: projectURL, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: projectURL) }

        let sourceURL = projectURL.appendingPathComponent("Sources/Context.swift")
        try FileManager.default.createDirectory(at: sourceURL.deletingLastPathComponent(), withIntermediateDirectories: true)
        try """
        line one
        line two
        line three
        let contextToken = true
        line five
        line six
        line seven
        """.write(to: sourceURL, atomically: true, encoding: .utf8)

        let results = try RAGLexicalFileSearcher.search(
            query: "contextToken",
            projectPath: projectURL.path,
            topK: 3
        )

        #expect(results.count == 1)
        #expect(results[0].lineRange == RAGLineRange(startLine: 1, endLine: 7))
        #expect(results[0].content.contains("1\tline one"))
        #expect(results[0].content.contains("7\tline seven"))
    }

    @Test func returnsNoResultsForMissingProject() throws {
        let missingProjectPath = FileManager.default.temporaryDirectory
            .appendingPathComponent("rag-missing-\(UUID().uuidString)", isDirectory: true)
            .path

        let results = try RAGLexicalFileSearcher.search(
            query: "missingProjectToken",
            projectPath: missingProjectPath,
            topK: 3
        )

        #expect(results.isEmpty)
    }
}

@Suite struct RAGFilePathSearcherTests {

    @Test func findsExplicitFilePathWithoutReadingContent() throws {
        let projectURL = FileManager.default.temporaryDirectory
            .appendingPathComponent("rag-path-search-\(UUID().uuidString)", isDirectory: true)
        try FileManager.default.createDirectory(at: projectURL, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: projectURL) }

        let sourceURL = projectURL.appendingPathComponent("Sources/RequestHandler.swift")
        try FileManager.default.createDirectory(at: sourceURL.deletingLastPathComponent(), withIntermediateDirectories: true)
        try "let unrelatedValue = true".write(to: sourceURL, atomically: true, encoding: .utf8)

        let results = try RAGFilePathSearcher.search(
            query: "Sources/RequestHandler.swift",
            projectPath: projectURL.path,
            topK: 3
        )

        #expect(results.count == 1)
        #expect(results[0].source == "Sources/RequestHandler.swift")
        #expect(results[0].content == "Sources/RequestHandler.swift")
        #expect(results[0].matchKind == .filesystemPath)
        #expect(results[0].lineRange == nil)
    }

    @Test func extractsExplicitPathFromNaturalLanguage() throws {
        let projectURL = FileManager.default.temporaryDirectory
            .appendingPathComponent("rag-path-extraction-\(UUID().uuidString)", isDirectory: true)
        try FileManager.default.createDirectory(at: projectURL, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: projectURL) }

        let sourceURL = projectURL.appendingPathComponent("Sources/RequestHandler.swift")
        try FileManager.default.createDirectory(at: sourceURL.deletingLastPathComponent(), withIntermediateDirectories: true)
        try "let unrelatedValue = true".write(to: sourceURL, atomically: true, encoding: .utf8)

        let results = try RAGFilePathSearcher.search(
            query: "请查看 Sources/RequestHandler.swift 的实现",
            projectPath: projectURL.path,
            topK: 3
        )

        #expect(results.map(\.source) == ["Sources/RequestHandler.swift"])
    }

    @Test func doesNotScanPathsForOrdinaryQueries() throws {
        let projectURL = FileManager.default.temporaryDirectory
            .appendingPathComponent("rag-path-gate-\(UUID().uuidString)", isDirectory: true)
        try FileManager.default.createDirectory(at: projectURL, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: projectURL) }

        let sourceURL = projectURL.appendingPathComponent("Sources/RequestHandler.swift")
        try FileManager.default.createDirectory(at: sourceURL.deletingLastPathComponent(), withIntermediateDirectories: true)
        try "let unrelatedValue = true".write(to: sourceURL, atomically: true, encoding: .utf8)

        let results = try RAGFilePathSearcher.search(
            query: "RequestHandler",
            projectPath: projectURL.path,
            topK: 3
        )

        #expect(results.isEmpty)
    }
}

@Suite struct RAGSQLiteStoreTests {

    @Test func persistsChunkLineRange() throws {
        let dbURL = FileManager.default.temporaryDirectory
            .appendingPathComponent("rag-line-range-\(UUID().uuidString).sqlite")
        defer { try? FileManager.default.removeItem(at: dbURL) }

        let store = try RAGSQLiteStore(dbURL: dbURL)
        try store.migrate()
        store.runtimeInfo = RAGRuntimeInfo(vectorBackend: .swiftCosine)

        try store.replaceFileChunks(
            projectPath: "/project",
            filePath: "/project/Feature.swift",
            modifiedTime: 1,
            contentHash: "hash",
            chunks: [
                RAGChunk(
                    index: 0,
                    content: "func feature() {}",
                    lineRange: RAGLineRange(startLine: 4, endLine: 7)
                ),
            ],
            embeddings: [[1, 0]],
            embeddingDimension: 2
        )

        let stored = try store.loadChunks(projectPath: "/project")
        #expect(stored.count == 1)
        #expect(stored[0].lineRange == RAGLineRange(startLine: 4, endLine: 7))
    }
}

@Suite struct RAGResultDeduplicatorTests {

    @Test func removesOnlyIdenticalEvidence() {
        let results = [
            RAGSearchResult(
                content: "func load() {}",
                source: "Feature.swift",
                score: 0.9,
                matchKind: .semantic,
                lineRange: RAGLineRange(startLine: 4, endLine: 6)
            ),
            RAGSearchResult(
                content: "func load() {}",
                source: "Feature.swift",
                score: 0.8,
                matchKind: .indexedLexical,
                lineRange: RAGLineRange(startLine: 4, endLine: 6)
            ),
            RAGSearchResult(
                content: "func save() {}",
                source: "Feature.swift",
                score: 0.7,
                matchKind: .semantic,
                lineRange: RAGLineRange(startLine: 8, endLine: 10)
            ),
        ]

        let unique = RAGResultDeduplicator.deduplicate(results)

        #expect(unique.count == 2)
        #expect(unique[0].score == 0.9)
        #expect(unique[1].content == "func save() {}")
    }

    @Test func appliesResultLimitAfterDeduplication() {
        let results = [
            RAGSearchResult(content: "same", source: "A.swift", score: 1),
            RAGSearchResult(content: "same", source: "A.swift", score: 0.9),
            RAGSearchResult(content: "other", source: "B.swift", score: 0.8),
        ]

        let unique = RAGResultDeduplicator.deduplicate(results, limit: 2)

        #expect(unique.map(\.content) == ["same", "other"])
    }
}
