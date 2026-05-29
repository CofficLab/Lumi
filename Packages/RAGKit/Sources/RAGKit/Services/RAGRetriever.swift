import CryptoKit
import Foundation

public struct RAGRetriever {
    private let store: RAGSQLiteStore
    private let logger: RAGLogger

    /// 查询结果缓存（线程安全，通过 cacheLock 保护）
    private static let cacheLock = NSLock()
    private nonisolated(unsafe) static var cache: [String: CacheEntry] = [:]
    private static let cacheTTLSeconds: TimeInterval = 120 // 缓存有效期 2 分钟
    private static let maxCacheSize = 50 // 最多缓存 50 条

    private struct CacheEntry {
        let results: [RAGSearchResult]
        let timestamp: CFAbsoluteTime
    }

    init(store: RAGSQLiteStore, logger: RAGLogger = NullRAGLogger()) {
        self.store = store
        self.logger = logger
    }

    public func retrieve(
        queryEmbedding: [Float],
        query: String,
        projectPath: String?,
        topK: Int
    ) throws -> [RAGSearchResult] {
        // 检查缓存
        let cacheKey = Self.buildCacheKey(query: query, projectPath: projectPath, topK: topK)
        if let cached = Self.getCached(key: cacheKey) {
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
            candidates = try store.loadCandidateChunks(
                projectPath: projectPath,
                queryTerms: queryTerms,
                lexicalLimit: 2500,
                fallbackLimit: 7000
            )
            let lexicalDuration = (CFAbsoluteTimeGetCurrent() - lexicalStart) * 1000
            usedFallback = true

            logger.info("[RAGRetriever] 词法检索耗时：\(String(format: "%.2f", lexicalDuration))ms, 结果数：\(candidates.count)")
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

        if totalDuration > 200 {
            logger.warning("[RAGRetriever]⚠️ retrieve 耗时过长：\(String(format: "%.2f", totalDuration))ms (>200ms) [ANN=\(String(format: "%.0f", annDuration))ms, scoring=\(String(format: "%.0f", scoringDuration))ms, candidates=\(candidates.count)]")
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
        Self.setCache(key: cacheKey, results: results)

        return results
    }

    // MARK: - Cache

    private static func buildCacheKey(query: String, projectPath: String?, topK: Int) -> String {
        let raw = "\(query)|\(projectPath ?? "")|\(topK)"
        let digest = SHA256.hash(data: Data(raw.utf8))
        return digest.map { String(format: "%02x", $0) }.joined()
    }

    private static func getCached(key: String) -> [RAGSearchResult]? {
        cacheLock.lock()
        defer { cacheLock.unlock() }
        guard let entry = cache[key] else { return nil }
        let now = CFAbsoluteTimeGetCurrent()
        guard now - entry.timestamp < cacheTTLSeconds else {
            cache.removeValue(forKey: key)
            return nil
        }
        return entry.results
    }

    private static func setCache(key: String, results: [RAGSearchResult]) {
        cacheLock.lock()
        defer { cacheLock.unlock() }
        // 淘汰过期条目
        let now = CFAbsoluteTimeGetCurrent()
        cache = cache.filter { now - $0.value.timestamp < cacheTTLSeconds }
        // 如果超过上限，移除最旧的
        if cache.count >= maxCacheSize {
            let oldest = cache.min { $0.value.timestamp < $1.value.timestamp }?.key
            if let oldest { cache.removeValue(forKey: oldest) }
        }
        cache[key] = CacheEntry(results: results, timestamp: now)
    }

    /// 清除所有缓存（索引更新时调用）
    public static func clearCache() {
        cacheLock.lock()
        defer { cacheLock.unlock() }
        cache.removeAll()
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
