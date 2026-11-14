import Foundation
import KitLLM
import LumiLoggingKit
import ProjectRAGEngine
import ProviderConversation
import ProviderLifecycleHooks
import ProviderLLMContext
import ProviderProjectRAG

/// 在 LLM 请求前为代码问题注入一次项目检索上下文。
///
/// 这个 hook 只负责路由和上下文注入，不负责工具注册、工具执行或 AgentLoop 状态管理。
@MainActor
final class ProjectRAGLLMContextHook {
    private let provider: any ProjectRAGProviding
    private let coordinator: CodeNavigationCoordinator
    private let searchMemory: ProjectRAGSearchMemory?
    private let conversations: (any ConversationManaging)?
    private let defaults: UserDefaults
    private var injectedTurns = RAGInjectionDeduplication()

    init(
        provider: any ProjectRAGProviding,
        searchMemory: ProjectRAGSearchMemory? = nil,
        conversations: (any ConversationManaging)? = nil,
        defaults: UserDefaults = .standard
    ) {
        self.provider = provider
        self.coordinator = CodeNavigationCoordinator(provider: provider)
        self.searchMemory = searchMemory
        self.conversations = conversations
        self.defaults = defaults
    }

    func apply(to context: WillSendToLLMContext) async -> WillSendToLLMContext {
        // 用户开关：关闭后不再自动注入，grep/search_code 工具仍可用。
        guard defaults.object(forKey: RAGInjectionPolicy.autoInjectEnabledKey) as? Bool ?? true else {
            return context
        }

        let userMessages = context.messages.filter { $0.role == .user }
        guard let latestUserMessage = userMessages.last,
              !latestUserMessage.content.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty,
              RAGIntentAnalyzer.shouldAutoInject(for: latestUserMessage.content) else {
            return context
        }

        // 检索必须作用于「本次请求所属对话」绑定的项目，而非 UI 当前打开的项目：
        // 外部打开切换全局项目后旧对话仍可能选中，用全局路径会把别的项目代码注入
        // 旧对话（#603）。无法确定对话项目时不注入，绝不静默回退到可能无关的全局项目。
        let projectPath: String?
        if let conversations {
            projectPath = (await conversations.fetchConversation(id: context.conversationID))?
                .projectPath?
                .trimmingCharacters(in: .whitespacesAndNewlines)
        } else {
            projectPath = provider.currentProjectPath
        }
        guard let projectPath, !projectPath.isEmpty else {
            return context
        }

        // 历史已占满窗口时不再注入，避免请求超限后紧急重试带着同样超限内容再失败。
        if let budget = context.injectedContentTokenBudget, budget <= 0 {
            return context
        }

        // The background index shares the RAG service actor with retrieval.
        // Do not make the main LLM request wait for a first-time project index;
        // the next turn can inject semantic context after indexing completes.
        guard !provider.isIndexing(projectPath: projectPath) else { return context }

        let turnKey = RAGInjectionDeduplication.Key(
            conversationID: context.conversationID,
            userMessageCount: userMessages.count,
            content: latestUserMessage.content
        )
        // 同一用户回合的后续请求（工具调用后历史重建）复用已检索证据，而不是因
        // 去重键命中直接丢弃——否则只有首次模型调用能看到代码上下文（#604）。
        if let cached = injectedTurns.content(for: turnKey) {
            return Self.reinject(cached, into: context)
        }

        do {
            let response = try await coordinator.search(
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

            // 置信度门槛：低相关片段不注入。埋点只记长度与判定结果，不记用户消息全文。
            let topScore = results.map(\.score).max() ?? 0
            let topKind = results.first?.matchKind.rawValue ?? "none"
            let messageLength = latestUserMessage.content.count
            guard RAGInjectionPolicy.shouldInject(results: results) else {
                MagicLogger.debug("[ProjectRAG] autoInject injected=false reason=confidence topScore=\(topScore) kind=\(topKind) msgLen=\(messageLength)")
                return context
            }

            let language: RAGLanguagePreference = containsCJK(latestUserMessage.content) ? .chinese : .english
            let wrapper = "Project code navigation context:\n"
            // 预留 wrapper 的 token，保证整条注入消息（而非仅 prompt）落在预算内。
            let promptBudget = context.injectedContentTokenBudget.map {
                $0 - LLMContextTokenEstimator.estimate(text: wrapper)
            }
            guard let prompt = RAGContextBuilder.buildPrompt(
                query: latestUserMessage.content,
                results: results,
                projectPath: projectPath,
                languagePreference: language,
                maxTokens: promptBudget,
                tokenEstimator: LLMContextTokenEstimator.estimate(text:)
            ) else {
                MagicLogger.debug("[ProjectRAG] autoInject injected=false reason=budget topScore=\(topScore) kind=\(topKind) msgLen=\(messageLength)")
                return context
            }

            var updated = context
            // 插在最后一条 user 消息之前：历史前缀 [0..<anchor] 逐字节不变，
            // 供应商前缀缓存可命中到注入点之前；不得插 0，也不得 append 到 user 之后。
            guard let anchor = updated.messages.lastIndex(where: { $0.role == .user }) else {
                return context
            }
            let systemContent = wrapper + prompt
            updated.messages.insert(
                LLMMessage(
                    role: .system,
                    content: systemContent
                ),
                at: anchor
            )
            searchMemory?.recordAutomaticSearch(query: latestUserMessage.content, projectPath: projectPath)
            injectedTurns.record(turnKey, content: systemContent)
            MagicLogger.debug("[ProjectRAG] autoInject injected=true topScore=\(topScore) kind=\(topKind) budget=\(context.injectedContentTokenBudget.map(String.init) ?? "nil") msgLen=\(messageLength)")
            return updated
        } catch {
            // RAG 不可用时不改变原始请求，避免检索故障阻塞正常对话。
            return context
        }
    }

    /// 把已缓存的证据重新插回当前请求：历史重建会丢掉只存在于上次请求局部副本里的
    /// 注入消息，这里按相同锚点补回；若历史已持久化该消息则不重复插入（#604）。
    private static func reinject(_ content: String, into context: WillSendToLLMContext) -> WillSendToLLMContext {
        guard !context.messages.contains(where: { $0.role == .system && $0.content == content }) else {
            return context
        }
        var updated = context
        guard let anchor = updated.messages.lastIndex(where: { $0.role == .user }) else {
            return context
        }
        updated.messages.insert(LLMMessage(role: .system, content: content), at: anchor)
        return updated
    }

    private func containsCJK(_ text: String) -> Bool {
        text.unicodeScalars.contains { scalar in
            (0x3400...0x4DBF).contains(scalar.value)
                || (0x4E00...0x9FFF).contains(scalar.value)
                || (0xF900...0xFAFF).contains(scalar.value)
        }
    }
}
