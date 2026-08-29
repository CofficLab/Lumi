import Foundation
import KitLLM
import ProjectRAGEngine
import ProviderLifecycleHooks
import ProviderProjectRAG

/// 在 LLM 请求前为代码问题注入一次项目检索上下文。
///
/// 这个 hook 只负责路由和上下文注入，不负责工具注册、工具执行或 AgentLoop 状态管理。
@MainActor
final class ProjectRAGLLMContextHook {
    private let provider: any ProjectRAGProviding
    private var injectedQueryKeys: Set<String> = []

    init(provider: any ProjectRAGProviding) {
        self.provider = provider
    }

    func apply(to context: WillSendToLLMContext) async -> WillSendToLLMContext {
        let userMessages = context.messages.filter { $0.role == .user }
        guard let latestUserMessage = userMessages.last,
              !latestUserMessage.content.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty,
              RAGIntentAnalyzer.shouldUseRAG(for: latestUserMessage.content),
              let projectPath = provider.currentProjectPath,
              !projectPath.isEmpty else {
            return context
        }

        let queryKey = "\(context.conversationID.uuidString):\(userMessages.count):\(latestUserMessage.content)"
        guard !injectedQueryKeys.contains(queryKey) else { return context }

        do {
            let hasIndex = try await provider.indexStatus(projectPath: projectPath) != nil
            if !hasIndex && !provider.isIndexing(projectPath: projectPath) {
                // 没有可用索引时，首次请求需要先建立一份索引，避免把
                // “索引尚未完成”误当成“没有相关代码”。
                try await provider.ensureIndexed(projectPath: projectPath, force: false, background: false)
            } else {
                // 已有旧索引时立即查询，同时在后台刷新；已有后台任务则由
                // Provider 内部去重。
                try await provider.ensureIndexed(projectPath: projectPath, force: false, background: true)
            }
            let response = try await provider.search(
                query: latestUserMessage.content,
                projectPath: projectPath,
                topK: 8
            )
            guard !response.results.isEmpty else { return context }

            let results = response.results.map {
                RAGSearchResult(
                    content: $0.content,
                    source: $0.source,
                    score: $0.score,
                    matchKind: RAGMatchKind(rawValue: $0.matchKind.rawValue) ?? .semantic,
                    lineRange: $0.lineRange.map {
                        RAGLineRange(startLine: $0.startLine, endLine: $0.endLine)
                    }
                )
            }
            let language: RAGLanguagePreference = containsCJK(latestUserMessage.content) ? .chinese : .english
            let prompt = RAGContextBuilder.buildPrompt(
                query: latestUserMessage.content,
                results: results,
                projectPath: projectPath,
                languagePreference: language
            )

            var updated = context
            updated.messages.insert(
                LLMMessage(
                    role: .system,
                    content: "Project code navigation context:\n\(prompt)"
                ),
                at: 0
            )
            injectedQueryKeys.insert(queryKey)
            return updated
        } catch {
            // RAG 不可用时不改变原始请求，避免检索故障阻塞正常对话。
            return context
        }
    }

    private func containsCJK(_ text: String) -> Bool {
        text.unicodeScalars.contains { scalar in
            (0x3400...0x4DBF).contains(scalar.value)
                || (0x4E00...0x9FFF).contains(scalar.value)
                || (0xF900...0xFAFF).contains(scalar.value)
        }
    }
}
