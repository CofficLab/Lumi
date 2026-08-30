import Foundation
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
        let hasIndex = try await provider.indexStatus(projectPath: projectPath) != nil
        let isIndexing = await provider.isIndexing(projectPath: projectPath)
        if !hasIndex && !isIndexing {
            try await provider.ensureIndexed(projectPath: projectPath, force: false, background: false)
        } else {
            try await provider.ensureIndexed(projectPath: projectPath, force: false, background: true)
        }
        return try await provider.search(query: query, projectPath: projectPath, topK: topK)
    }
}
