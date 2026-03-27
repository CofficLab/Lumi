import Foundation

struct RAGRetriever {
    private let store: RAGSQLiteStore

    init(store: RAGSQLiteStore) {
        self.store = store
    }

    func retrieve(
        queryEmbedding: [Float],
        query: String,
        projectPath: String?,
        topK: Int
    ) throws -> [RAGSearchResult] {
        let queryTerms = tokenize(query.lowercased())
        let annCandidates = try loadANNCandidates(queryEmbedding: queryEmbedding, projectPath: projectPath, topK: topK)
        let candidates: [RAGStoredChunk]
        if annCandidates.isEmpty {
            candidates = try store.loadCandidateChunks(
                projectPath: projectPath,
                queryTerms: queryTerms,
                lexicalLimit: 2500,
                fallbackLimit: 7000
            )
        } else {
            candidates = annCandidates
        }
        if candidates.isEmpty { return [] }

        var scored: [(RAGStoredChunk, Float)] = []
        scored.reserveCapacity(candidates.count)

        for chunk in candidates {
            guard chunk.embedding.count == queryEmbedding.count else { continue }
            let semantic = cosineSimilarity(queryEmbedding, chunk.embedding)
            let lexical = lexicalBoost(query: query, content: chunk.content)
            let pathBoost = sourcePathBoost(queryTerms: queryTerms, filePath: chunk.filePath)
            let finalScore = semantic * 0.75 + lexical * 0.20 + pathBoost * 0.05
            scored.append((chunk, finalScore))
        }

        scored.sort { $0.1 > $1.1 }
        let top = pickTopWithDiversity(scored, topK: topK)

        return top.map {
            let sourcePath = displayPath(filePath: $0.0.filePath, projectPath: projectPath)
            return RAGSearchResult(
                content: $0.0.content,
                source: sourcePath,
                score: $0.1
            )
        }
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

    private func cosineSimilarity(_ a: [Float], _ b: [Float]) -> Float {
        guard a.count == b.count, !a.isEmpty else { return 0 }
        let dot = zip(a, b).reduce(Float(0)) { $0 + $1.0 * $1.1 }
        let magA = sqrt(a.reduce(Float(0)) { $0 + $1 * $1 })
        let magB = sqrt(b.reduce(Float(0)) { $0 + $1 * $1 })
        guard magA > 0, magB > 0 else { return 0 }
        return dot / (magA * magB)
    }

    private func lexicalBoost(query: String, content: String) -> Float {
        let tokens = tokenize(query.lowercased())
        guard !tokens.isEmpty else { return 0 }

        let lowerContent = content.lowercased()
        let hitCount = tokens.reduce(0) { partial, token in
            partial + (lowerContent.contains(token) ? 1 : 0)
        }
        return Float(hitCount) / Float(tokens.count)
    }

    private func sourcePathBoost(queryTerms: [String], filePath: String) -> Float {
        guard !queryTerms.isEmpty else { return 0 }
        let lowerPath = filePath.lowercased()
        let hits = queryTerms.reduce(0) { $0 + (lowerPath.contains($1) ? 1 : 0) }
        return Float(hits) / Float(queryTerms.count)
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

    private func tokenize(_ text: String) -> [String] {
        var tokens: [String] = []
        var buffer = ""

        for scalar in text.unicodeScalars {
            if CharacterSet.alphanumerics.contains(scalar) {
                buffer.unicodeScalars.append(scalar)
                continue
            }

            if !buffer.isEmpty {
                tokens.append(buffer)
                buffer.removeAll(keepingCapacity: true)
            }

            if scalar.isCJK {
                tokens.append(String(scalar))
            }
        }

        if !buffer.isEmpty {
            tokens.append(buffer)
        }
        return tokens
    }

    private func displayPath(filePath: String, projectPath: String?) -> String {
        guard let projectPath, !projectPath.isEmpty else { return filePath }
        if filePath.hasPrefix(projectPath) {
            let index = filePath.index(filePath.startIndex, offsetBy: projectPath.count)
            let suffix = String(filePath[index...])
            return suffix.hasPrefix("/") ? String(suffix.dropFirst()) : suffix
        }
        return filePath
    }
}
