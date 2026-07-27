import Testing
import Foundation
@testable import ProjectRAGPlugin

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
    }

    @Test func chunkProducesOverlapAcrossBlocks() {
        // 10 lines, maxLines 4, overlap 2 → windows: [0-3], [2-5], [4-7], [6-9]
        let content = (0..<10).map { "line \($0)" }.joined(separator: "\n")
        let chunks = RAGChunker(maxLines: 4, overlapLines: 2).chunk(content)
        #expect(chunks.count >= 3)
        // Overlap means "line 2"/"line 3" must appear in more than one chunk.
        let mentionsOfLine2 = chunks.filter { $0.content.contains("line 2") }.count
        #expect(mentionsOfLine2 >= 2)
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

    @Test func shouldUseRAGEnglishTriggerMatchesSubstring() {
        // Documented heuristic: "how" is a trigger word and matches as a
        // substring, so "how are you" trips RAG even in casual messages.
        #expect(RAGIntentAnalyzer.shouldUseRAG(for: "hello, how are you today") == true)
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
