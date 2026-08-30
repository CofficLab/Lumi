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
        async let semanticResponse = searchProjectRAG(
            query: query,
            projectPath: projectPath,
            topK: topK
        )
        let lexicalResults = (try? RAGLexicalFileSearcher.search(
            query: query,
            projectPath: projectPath,
            topK: topK
        )) ?? []
        let pathResults = (try? RAGFilePathSearcher.search(
            query: query,
            projectPath: projectPath,
            topK: topK
        )) ?? []
        let response = try await semanticResponse

        var merged = response.results
        merged.append(contentsOf: lexicalResults.map {
            makeProviderResult($0)
        })
        merged.append(contentsOf: pathResults.map {
            makeProviderResult($0)
        })

        return ProjectRAGResponse(
            query: response.query,
            results: deduplicateAndSort(merged, limit: topK)
        )
    }

    private func searchProjectRAG(
        query: String,
        projectPath: String,
        topK: Int
    ) async throws -> ProjectRAGResponse {
        let hasIndex = try await provider.indexStatus(projectPath: projectPath) != nil
        let isIndexing = await provider.isIndexing(projectPath: projectPath)
        if !hasIndex && !isIndexing {
            try await provider.ensureIndexed(projectPath: projectPath, force: false, background: false)
        } else {
            try await provider.ensureIndexed(projectPath: projectPath, force: false, background: true)
        }
        return try await provider.search(query: query, projectPath: projectPath, topK: topK)
    }

    private func deduplicateAndSort(
        _ results: [ProjectRAGSearchResult],
        limit: Int
    ) -> [ProjectRAGSearchResult] {
        var seen = Set<String>()
        return results
            .filter { result in
                let lineKey = result.lineRange.map { "\($0.startLine)-\($0.endLine)" } ?? "-"
                return seen.insert("\(result.source)|\(lineKey)|\(result.content)").inserted
            }
            .sorted {
                if $0.score != $1.score { return $0.score > $1.score }
                return $0.source < $1.source
            }
            .prefix(max(limit, 1))
            .map { $0 }
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
