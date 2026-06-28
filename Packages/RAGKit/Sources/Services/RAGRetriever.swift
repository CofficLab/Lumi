import Foundation

public struct RAGRetriever {
    private let store: any RAGStore
    private let cache: RAGCache
    private let logger: RAGLogger

    init(store: any RAGStore, cache: RAGCache = RAGCache(), logger: RAGLogger = NullRAGLogger()) {
        self.store = store
        self.cache = cache
        self.logger = logger
    }

    public func retrieve(
        queryEmbedding: [Float],
        query: String,
        projectPath: String?,
        topK: Int
    ) throws -> [RAGSearchResult] {
        // 检查缓存
        let cacheKey = cache.buildKey(query: query, projectPath: projectPath, topK: topK)
        if let cached = cache.get(key: cacheKey) {
            logger.info("[RAGRetriever] 缓存命中: \(query.prefix(40))")
            return cached
        }
        let start = CFAbsoluteTimeGetCurrent()

        let queryTerms = RAGTextUtils.tokenize(query.lowercased())

        // ANN 检索
        let annStart = CFAbsoluteTimeGetCurrent()
        let annCandidates = try loadANNCandidates(queryEmbedding: queryEmbedding, projectPath: projectPath, topK: topK)
        let annDuration = (CFAbsoluteTimeGetCurrent() - annStart) * 1000

        let candidates: [RAGStoredChunk]
        let usedFallback: Bool
        if annCandidates.isEmpty {
            let lexicalStart = CFAbsoluteTimeGetCurrent()
            // sqlite-vec 不可用（回退到 swiftCosine）时，余弦相似度需在内存逐个计算，
            // 候选过多会导致 search_code 超时。此时把 fallback 上限压到 1500，避免大量计算。
            // sqlite-vec 可用时仍放宽到 7000，保证召回质量。
            let usingSwiftCosine = (store as? RAGSQLiteStore)?.runtimeInfo.vectorBackend != .sqliteVec
            let fallbackLimit = usingSwiftCosine ? 1500 : 7000
            candidates = try store.loadCandidateChunks(
                projectPath: projectPath,
                queryTerms: queryTerms,
                lexicalLimit: 2500,
                fallbackLimit: fallbackLimit
            )
            let lexicalDuration = (CFAbsoluteTimeGetCurrent() - lexicalStart) * 1000
            usedFallback = true

            logger.info("[RAGRetriever] 词法检索耗时：\(String(format: "%.2f", lexicalDuration))ms, 结果数：\(candidates.count), 向量后端: \(usingSwiftCosine ? "swiftCosine(fallback=\(fallbackLimit))" : "sqliteVec")")
        } else {
            candidates = annCandidates
            usedFallback = false
        }

        if candidates.isEmpty {
            logger.info("[RAGRetriever] 未找到候选文档")
            return []
        }

        logger.info("[RAGRetriever] ANN 检索耗时：\(String(format: "%.2f", annDuration))ms, 结果数：\(annCandidates.count), 使用fallback: \(usedFallback)")

        // 相似度计算
        let scoringStart = CFAbsoluteTimeGetCurrent()
        var scored: [(RAGStoredChunk, Float)] = []
        scored.reserveCapacity(candidates.count)

        for chunk in candidates {
            guard chunk.embedding.count == queryEmbedding.count else { continue }
            let semantic = RAGMathUtils.cosineSimilarity(queryEmbedding, chunk.embedding)
            let lexical = RAGTextUtils.lexicalBoost(query: query, content: chunk.content)
            let pathBoost = RAGTextUtils.sourcePathBoost(queryTerms: queryTerms, filePath: chunk.filePath)
            let finalScore = semantic * 0.75 + lexical * 0.20 + pathBoost * 0.05
            scored.append((chunk, finalScore))
        }

        scored.sort { $0.1 > $1.1 }
        let top = pickTopWithDiversity(scored, topK: topK)
        let scoringDuration = (CFAbsoluteTimeGetCurrent() - scoringStart) * 1000

        let totalDuration = (CFAbsoluteTimeGetCurrent() - start) * 1000

        logger.info("[RAGRetriever] 相似度计算耗时：\(String(format: "%.2f", scoringDuration))ms, 候选数：\(candidates.count), 返回：\(top.count)")
        logger.info("[RAGRetriever] retrieve 总耗时：\(String(format: "%.2f", totalDuration))ms")

        // 性能预警阈值：>3s 升级为 error 级（语义检索明显异常），200ms-3s 维持 warning。
        if totalDuration > 3000 {
            logger.error("[RAGRetriever]🚨 retrieve 耗时严重过长：\(String(format: "%.2f", totalDuration))ms (>3000ms) [ANN=\(String(format: "%.0f", annDuration))ms, scoring=\(String(format: "%.0f", scoringDuration))ms, candidates=\(candidates.count)]")
        } else if totalDuration > 200 {
            logger.warning("[RAGRetriever]⚠️ retrieve 耗时偏长：\(String(format: "%.2f", totalDuration))ms (>200ms) [ANN=\(String(format: "%.0f", annDuration))ms, scoring=\(String(format: "%.0f", scoringDuration))ms, candidates=\(candidates.count)]")
        }

        let results = top.map {
            let sourcePath = RAGPathUtils.displayPath(filePath: $0.0.filePath, projectPath: projectPath)
            return RAGSearchResult(
                content: $0.0.content,
                source: sourcePath,
                score: $0.1
            )
        }

        // 存入缓存
        cache.set(key: cacheKey, results: results)

        return results
    }

    // MARK: - Private

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

    private func pickTopWithDiversity(_ scored: [(RAGStoredChunk, Float)], topK: Int) -> [(RAGStoredChunk, Float)] {
        let target = max(topK, 1)
        var picked: [(RAGStoredChunk, Float)] = []
        var perFileCounter: [String: Int] = [:]
        let maxChunksPerFile = 2

        for candidate in scored {
            let file = candidate.0.filePath
            let used = perFileCounter[file, default: 0]
            if used >= maxChunksPerFile { continue }

            picked.append(candidate)
            perFileCounter[file] = used + 1
            if picked.count >= target { break }
        }

        if picked.count < target {
            for candidate in scored where !picked.contains(where: { $0.0.filePath == candidate.0.filePath && $0.0.content == candidate.0.content }) {
                picked.append(candidate)
                if picked.count >= target { break }
            }
        }
        return picked
    }
}
