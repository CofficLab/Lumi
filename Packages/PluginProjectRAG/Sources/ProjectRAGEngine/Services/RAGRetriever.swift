import Foundation
import LumiLoggingKit
import os

public struct RAGRetriever: SuperLog {
    public nonisolated static let emoji = "🔍"
    public nonisolated static let verbose: Bool = false
    public nonisolated static let logger = Logger(subsystem: "com.coffic.lumi", category: "plugin.rag.retriever")
    // Keep the total number of materialized chunks bounded. Each row also
    // materializes its text and embedding, so this is an important memory cap.
    static let lexicalCandidateLimit = 1_000
    static let fallbackCandidateLimit = 2_500

    private let store: any RAGStore
    private let cache: RAGCache

    init(store: any RAGStore, cache: RAGCache = RAGCache()) {
        self.store = store
        self.cache = cache
    }

    public func retrieve(
        queryEmbedding: [Float],
        query: String,
        projectPath: String?,
        topK: Int
    ) throws -> [RAGSearchResult] {
        try Task.checkCancellation()
        // 检查缓存
        let cacheKey = cache.buildKey(query: query, projectPath: projectPath, topK: topK)
        if let cached = cache.get(key: cacheKey) {
            if Self.verbose {
                Self.logger.info("\(Self.t)缓存命中: \(query.prefix(40))")
            }
            return cached
        }
        let start = CFAbsoluteTimeGetCurrent()

        let queryTerms = RAGTextUtils.tokenize(query.lowercased())

        // ANN 检索
        let annStart = CFAbsoluteTimeGetCurrent()
        let annCandidates = try loadANNCandidates(queryEmbedding: queryEmbedding, projectPath: projectPath, topK: topK)
        try Task.checkCancellation()
        let annDuration = (CFAbsoluteTimeGetCurrent() - annStart) * 1000

        // 词法候选始终加载，用 BM25 排序后与 ANN 做 RRF 融合（Task 2.1b'）。
        let lexicalStart = CFAbsoluteTimeGetCurrent()
        let lexicalCandidates = try store.loadCandidateChunks(
            projectPath: projectPath,
            queryTerms: queryTerms,
            lexicalLimit: Self.lexicalCandidateLimit,
            fallbackLimit: Self.fallbackCandidateLimit
        )
        try Task.checkCancellation()
        let lexicalDuration = (CFAbsoluteTimeGetCurrent() - lexicalStart) * 1000

        let annScored: [(RAGStoredChunk, Float)] = annCandidates
            .compactMap { chunk -> (RAGStoredChunk, Float)? in
                guard chunk.embedding.count == queryEmbedding.count else { return nil }
                return (chunk, RAGMathUtils.cosineSimilarity(queryEmbedding, chunk.embedding))
            }
            .sorted { $0.1 > $1.1 }

        let bm25Scores = RAGBM25.scores(
            queryTerms: queryTerms,
            documents: lexicalCandidates.map(\.content)
        )
        let lexicalScored: [(RAGStoredChunk, Float)] = zip(lexicalCandidates, bm25Scores)
            .filter { $0.1 > 0 }
            .sorted { $0.1 > $1.1 }
            .map { ($0.0, Float($0.1)) }

        if Self.verbose {
            Self.logger.info("\(Self.t)ANN 检索耗时：\(String(format: "%.2f", annDuration))ms, 结果数：\(annScored.count); 词法 BM25 耗时：\(String(format: "%.2f", lexicalDuration))ms, 命中数：\(lexicalScored.count)")
        }

        if annScored.isEmpty && lexicalScored.isEmpty {
            if Self.verbose {
                Self.logger.info("\(Self.t)未找到候选文档")
            }
            return []
        }

        // RRF 决定排序；旧 lexicalBoost 复合分只作展示项，不再决定排序。
        let scoringStart = CFAbsoluteTimeGetCurrent()
        let lists = [annScored, lexicalScored]
        let inputs = lists.map { list in
            list.map { chunk, score in
                RAGFusionInput(
                    source: chunk.filePath,
                    startLine: chunk.lineRange?.startLine,
                    endLine: chunk.lineRange?.endLine,
                    content: chunk.content,
                    score: score
                )
            }
        }
        let fused = RAGRankFusion.fuse(inputs, limit: topK)

        var results: [RAGSearchResult] = fused.map { output in
            let chunk = lists[output.listIndex][output.itemIndex].0
            return Self.makeResult(
                chunk: chunk,
                queryEmbedding: queryEmbedding,
                query: query,
                queryTerms: queryTerms,
                projectPath: projectPath,
                matchKind: output.listIndex == 0 ? .semantic : .indexedLexical
            )
        }

        // Task 2.3：低于工具侧阈值的语义候选直接丢弃；全部被丢弃时走词法兜底。
        let beforeDrop = results.count
        results.removeAll {
            $0.matchKind == .semantic && $0.score < RAGInjectionPolicy.semanticResultThreshold
        }
        let dropped = beforeDrop - results.count
        if dropped > 0 {
            Self.logger.info("\(Self.t)丢弃低分语义候选 \(dropped) 条（阈值 \(RAGInjectionPolicy.semanticResultThreshold)）")
        }
        if results.isEmpty && !lexicalScored.isEmpty {
            results = lexicalScored.prefix(topK).map { chunk, _ in
                Self.makeResult(
                    chunk: chunk,
                    queryEmbedding: queryEmbedding,
                    query: query,
                    queryTerms: queryTerms,
                    projectPath: projectPath,
                    matchKind: .indexedLexical
                )
            }
        }
        let scoringDuration = (CFAbsoluteTimeGetCurrent() - scoringStart) * 1000

        let totalDuration = (CFAbsoluteTimeGetCurrent() - start) * 1000

        if Self.verbose {
            Self.logger.info("\(Self.t)融合打分耗时：\(String(format: "%.2f", scoringDuration))ms, 返回：\(results.count)")
            Self.logger.info("\(Self.t)retrieve 总耗时：\(String(format: "%.2f", totalDuration))ms")
        }

        // 性能预警阈值：>3s 升级为 error 级（语义检索明显异常，可能 sqlite-vec 未启用或候选过多），
        // 200ms-3s 维持 warning（轻度偏慢），便于在日志里区分严重程度。
        if totalDuration > 3000 {
            if Self.verbose {
                Self.logger.error("\(Self.t)🚨 retrieve 耗时严重过长：\(String(format: "%.2f", totalDuration))ms (>3000ms) [ANN=\(String(format: "%.0f", annDuration))ms, scoring=\(String(format: "%.0f", scoringDuration))ms]")
            }
        } else if totalDuration > 200 {
            if Self.verbose {
                Self.logger.warning("\(Self.t)⚠️ retrieve 耗时偏长：\(String(format: "%.2f", totalDuration))ms (>200ms) [ANN=\(String(format: "%.0f", annDuration))ms, scoring=\(String(format: "%.0f", scoringDuration))ms]")
            }
        }

        // 存入缓存
        cache.set(key: cacheKey, results: results)

        return results
    }

    // MARK: - Private

    private static func makeResult(
        chunk: RAGStoredChunk,
        queryEmbedding: [Float],
        query: String,
        queryTerms: [String],
        projectPath: String?,
        matchKind: RAGMatchKind
    ) -> RAGSearchResult {
        let semantic = chunk.embedding.count == queryEmbedding.count
            ? RAGMathUtils.cosineSimilarity(queryEmbedding, chunk.embedding)
            : 0
        let lexical = RAGTextUtils.lexicalBoost(query: query, content: chunk.content)
        let pathBoost = RAGTextUtils.sourcePathBoost(queryTerms: queryTerms, filePath: chunk.filePath)
        let displayScore = semantic * 0.75 + lexical * 0.20 + pathBoost * 0.05
        return RAGSearchResult(
            content: chunk.content,
            source: RAGPathUtils.displayPath(filePath: chunk.filePath, projectPath: projectPath),
            score: displayScore,
            matchKind: matchKind,
            lineRange: chunk.lineRange
        )
    }

    private func loadANNCandidates(
        queryEmbedding: [Float],
        projectPath: String?,
        topK: Int
    ) throws -> [RAGStoredChunk] {
        let annLimit = max(topK * 12, 60)
        guard let vectorMatches = try store.searchNearestVectors(queryEmbedding: queryEmbedding, limit: annLimit),
              !vectorMatches.isEmpty else {
            return []
        }

        let ids = vectorMatches.map(\.chunkId)
        return try store.loadChunksByIDs(ids, projectPath: projectPath)
    }
}
