import Foundation

/// 待办提取中间件（ConversationTurnEvent）
///
/// 触发点：
/// - `.responseReceived`（非流式最终回复）
/// - `.streamFinished`（流式最终回复）
///
/// 行为：
/// - 规则提取：从回复内容中找 `- [ ]` / `* [ ]` / `TODO:` 等行
/// - 若提取到内容，则追加一条 assistant 消息“待办提取”，并落库
@MainActor
struct TodoExtractionMiddleware: ConversationTurnMiddleware {
    let id: String = "agent.todo-extraction"
    let order: Int = 35 // 要早于 PersistAndAppend(40) 与 StreamFinishedFinalize(20) 之后的短路点

    func handle(
        event: ConversationTurnEvent,
        ctx: ConversationTurnMiddlewareContext,
        next: @escaping @MainActor (ConversationTurnEvent, ConversationTurnMiddlewareContext) async -> Void
    ) async {
        let message: ChatMessage
        let conversationId: UUID

        switch event {
        case let .responseReceived(m, cid):
            message = m
            conversationId = cid
        case let .streamFinished(m, cid):
            message = m
            conversationId = cid
        default:
            await next(event, ctx)
            return
        }

        guard message.role == .assistant else {
            await next(event, ctx)
            return
        }

        // 防重复：同一条消息只处理一次
        var processed = ctx.runtimeStore.postProcessedMessageIdsByConversation[conversationId, default: []]
        if processed.contains(message.id) {
            await next(event, ctx)
            return
        }
        processed.insert(message.id)
        ctx.runtimeStore.postProcessedMessageIdsByConversation[conversationId] = processed

        // 避免对“提取结果消息”再提取
        if message.content.contains("[待办提取]") {
            await next(event, ctx)
            return
        }

        let todos = extractTodos(from: message.content)
        guard !todos.isEmpty else {
            await next(event, ctx)
            return
        }

        // 低优先级任务：保持在 MainActor，避免捕获非 Sendable 的 actions/ctx 造成编译错误。
        Task(priority: .background) { @MainActor in
            let content = """
            [待办提取]
            \(todos.map { "- \($0)" }.joined(separator: "\n"))
            [/待办提取]
            """

            let followUp = ChatMessage(role: .assistant, content: content)
            if ctx.env.selectedConversationId() == conversationId {
                ctx.actions.appendMessage(followUp)
            }
            await ctx.actions.saveMessage(followUp, conversationId)
        }

        await next(event, ctx)
    }

    private func extractTodos(from text: String) -> [String] {
        let lines = text.split(separator: "\n", omittingEmptySubsequences: false).map { String($0) }
        var results: [String] = []
        results.reserveCapacity(8)

        for line in lines {
            let trimmed = line.trimmingCharacters(in: .whitespacesAndNewlines)
            if trimmed.hasPrefix("- [ ]") || trimmed.hasPrefix("* [ ]") {
                let item = trimmed
                    .replacingOccurrences(of: "- [ ]", with: "")
                    .replacingOccurrences(of: "* [ ]", with: "")
                    .trimmingCharacters(in: .whitespacesAndNewlines)
                if !item.isEmpty { results.append(item) }
                continue
            }

            if trimmed.uppercased().hasPrefix("TODO:") {
                let item = String(trimmed.dropFirst(5)).trimmingCharacters(in: .whitespacesAndNewlines)
                if !item.isEmpty { results.append(item) }
                continue
            }
        }

        // 去重并限制数量，避免刷屏
        var seen = Set<String>()
        var uniq: [String] = []
        for t in results {
            if seen.insert(t).inserted {
                uniq.append(t)
            }
            if uniq.count >= 12 { break }
        }
        return uniq
    }
}

