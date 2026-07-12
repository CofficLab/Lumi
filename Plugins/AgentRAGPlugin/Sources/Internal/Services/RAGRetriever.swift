import Foundation
import SuperLogKit
import os

public struct RAGRetriever: SuperLog {
    public nonisolated static let emoji = "🔍"
    public nonisolated static let verbose: Bool = false
    public nonisolated static let logger = Logger(subsystem: "com.coffic.lumi", category: "plugin.rag.retriever")

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

            if Self.verbose {
                Self.logger.info("\(Self.t)词法检索耗时：\(String(format: "%.2f", lexicalDuration))ms, 结果数：\(candidates.count), 向量后端: \(usingSwiftCosine ? "swiftCosine(fallback=\(fallbackLimit))" : "sqliteVec")")
            }
        } else {
            candidates = annCandidates
            usedFallback = false
        }

        if candidates.isEmpty {
            if Self.verbose {
                Self.logger.info("\(Self.t)未找到候选文档")
            }
            return []
        }

        if Self.verbose {
            Self.logger.info("\(Self.t)ANN 检索耗时：\(String(format: "%.2f", annDuration))ms, 结果数：\(annCandidates.count), 使用fallback: \(usedFallback)")
        }

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

        if Self.verbose {
            Self.logger.info("\(Self.t)相似度计算耗时：\(String(format: "%.2f", scoringDuration))ms, 候选数：\(candidates.count), 返回：\(top.count)")
            Self.logger.info("\(Self.t)retrieve 总耗时：\(String(format: "%.2f", totalDuration))ms")
        }

        // 性能预警阈值：>3s 升级为 error 级（语义检索明显异常，可能 sqlite-vec 未启用或候选过多），
        // 200ms-3s 维持 warning（轻度偏慢），便于在日志里区分严重程度。
        if totalDuration > 3000 {
            if Self.verbose {
                Self.logger.error("\(Self.t)🚨 retrieve 耗时严重过长：\(String(format: "%.2f", totalDuration))ms (>3000ms) [ANN=\(String(format: "%.0f", annDuration))ms, scoring=\(String(format: "%.0f", scoringDuration))ms, candidates=\(candidates.count)]")
            }
        } else if totalDuration > 200 {
            if Self.verbose {
                Self.logger.warning("\(Self.t)⚠️ retrieve 耗时偏长：\(String(format: "%.2f", totalDuration))ms (>200ms) [ANN=\(String(format: "%.0f", annDuration))ms, scoring=\(String(format: "%.0f", scoringDuration))ms, candidates=\(candidates.count)]")
            }
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
