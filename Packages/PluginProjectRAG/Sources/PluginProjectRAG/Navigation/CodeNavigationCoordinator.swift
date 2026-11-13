import Foundation
import ProjectRAGEngine
import ProviderProjectRAG

/// 代码导航的第一层协调器。
///
/// 当前只统一 Project RAG 的索引就绪策略和检索调用；后续可以在这里合并
/// 精确文本、文件名和符号检索，而不让 Hook 或工具分别维护这些规则。
struct CodeNavigationCoordinator: Sendable {
    private let provider: any ProjectRAGProviding

    init(provider: any ProjectRAGProviding) {
        self.provider = provider
    }

    func search(query: String, projectPath: String, topK: Int) async throws -> ProjectRAGResponse {
        // Live lexical/path search never depends on index state: while background
        // indexing runs they are the only evidence returned, so callers always get
        // real results. Semantic search stays gated inside searchProjectRAG, which
        // returns empty while indexing instead of queueing behind the index actor.
        async let semanticResponse = searchProjectRAG(
            query: query,
            projectPath: projectPath,
            topK: topK
        )
        // 语义 embed 用原始 query；词法/路径用提取后的搜索词，
        // 避免疑问词进入 rg 模式稀释命中。
        let liveQuery = RAGQueryAnalyzer.extractTerms(query: query).joined(separator: " ")
        async let lexicalResults = (try? await RAGLexicalFileSearcher.search(
            query: liveQuery,
            projectPath: projectPath,
            topK: topK
        )) ?? []
        async let pathResults = (try? await RAGFilePathSearcher.search(
            query: liveQuery,
            projectPath: projectPath,
            topK: topK
        )) ?? []

        let response = try await semanticResponse
        let lexical = await lexicalResults.map { makeProviderResult($0) }
        let path = await pathResults.map { makeProviderResult($0) }
        let lists = [response.results, lexical, path]
        let inputs = lists.map { list in
            list.map {
                RAGFusionInput(
                    source: $0.source,
                    startLine: $0.lineRange?.startLine,
                    endLine: $0.lineRange?.endLine,
                    content: $0.content,
                    score: $0.score
                )
            }
        }
        let results = RAGRankFusion.fuse(inputs, limit: topK).map { output -> ProjectRAGSearchResult in
            let original = lists[output.listIndex][output.itemIndex]
            return ProjectRAGSearchResult(
                content: original.content,
                source: original.source,
                score: output.bestOriginalScore,
                matchKind: original.matchKind,
                lineRange: original.lineRange
            )
        }

        return ProjectRAGResponse(query: response.query, results: results)
    }

    private func searchProjectRAG(
        query: String,
        projectPath: String,
        topK: Int
    ) async throws -> ProjectRAGResponse {
        // Semantic search must never queue behind the indexing actor: while
        // indexing is active, return empty and let live search carry the turn.
        guard !(await provider.isIndexing(projectPath: projectPath)) else {
            return ProjectRAGResponse(query: query, results: [])
        }

        let hasIndex = try await provider.indexStatus(projectPath: projectPath) != nil
        let isIndexing = await provider.isIndexing(projectPath: projectPath)
        if !hasIndex && !isIndexing {
            try await provider.ensureIndexed(projectPath: projectPath, force: false, background: false)
        } else {
            try await provider.ensureIndexed(projectPath: projectPath, force: false, background: true)
        }

        // Indexing may have started while index readiness was checked. Do not
        // enqueue the semantic search behind it.
        guard !(await provider.isIndexing(projectPath: projectPath)) else {
            return ProjectRAGResponse(query: query, results: [])
        }
        return try await provider.search(query: query, projectPath: projectPath, topK: topK)
    }

    private func makeProviderResult(_ result: RAGSearchResult) -> ProjectRAGSearchResult {
        ProjectRAGSearchResult(
            content: result.content,
            source: result.source,
            score: result.score,
            matchKind: ProjectRAGMatchKind(rawValue: result.matchKind.rawValue) ?? .filesystemLexical,
            lineRange: result.lineRange.map {
                ProjectRAGLineRange(startLine: $0.startLine, endLine: $0.endLine)
            }
        )
    }
}
