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
            // 后台启动或刷新索引，不阻塞本次请求等待全量索引完成。
            try await provider.ensureIndexed(projectPath: projectPath, force: false, background: true)
            let response = try await provider.search(
                query: latestUserMessage.content,
                projectPath: projectPath,
                topK: 8
            )
            guard !response.results.isEmpty else { return context }

            let results = response.results.map {
                RAGSearchResult(content: $0.content, source: $0.source, score: $0.score)
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
