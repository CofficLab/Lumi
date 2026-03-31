import Foundation
import MagicKit

/// 在用户消息发送前，将「最近项目」合并进会话中**第一条** system 消息（根 system），
/// 以便 Anthropic 等只消费首条 system 的 Provider 也能看到该上下文。
@MainActor
struct RecentProjectsRootSystemMergeMiddleware: SendMiddleware {
    let id: String = "agent.recent-projects.root-system-merge"
    /// 早于默认的自动标题中间件（同一会话内先更新根 system 再进入后续管线）。
    let order: Int = -20

    private static let beginMarker = "<!-- lumi:recent-projects -->"
    private static let endMarker = "<!-- /lumi:recent-projects -->"

    func handle(
        ctx: SendMessageContext,
        next: @escaping @MainActor (SendMessageContext) async -> Void
    ) async {
        guard ctx.message.role == .user else {
            await next(ctx)
            return
        }
        await mergeIntoRootSystemIfNeeded(ctx: ctx)
        await next(ctx)
    }

    private func mergeIntoRootSystemIfNeeded(ctx: SendMessageContext) async {
        guard let history = await ctx.chatHistoryService.loadMessages(forConversationId: ctx.conversationId),
              let rootIndex = history.firstIndex(where: { $0.role == .system }) else {
            return
        }

        let root = history[rootIndex]
        let store = RecentProjectsStore()
        let projects = store.loadProjects()
        let currentPath = store.getCurrentProject()?.path

        let stripped = Self.stripBlock(from: root.content)
        let newContent: String
        if projects.isEmpty {
            newContent = stripped
        } else {
            let block = Self.formatBlock(projects: projects, currentPath: currentPath)
            if stripped.isEmpty {
                newContent = block
            } else {
                let sep = stripped.hasSuffix("\n") ? "\n" : "\n\n"
                newContent = stripped + sep + block
            }
        }

        guard newContent != root.content else { return }

        let updated = ChatMessage(
            id: root.id,
            role: root.role,
            conversationId: root.conversationId,
            content: newContent,
            timestamp: root.timestamp,
            isError: root.isError,
            toolCalls: root.toolCalls,
            toolCallID: root.toolCallID,
            images: root.images,
            providerId: root.providerId,
            modelName: root.modelName,
            latency: root.latency,
            inputTokens: root.inputTokens,
            outputTokens: root.outputTokens,
            totalTokens: root.totalTokens,
            timeToFirstToken: root.timeToFirstToken,
            streamingDuration: root.streamingDuration,
            thinkingDuration: root.thinkingDuration,
            finishReason: root.finishReason,
            requestId: root.requestId,
            temperature: root.temperature,
            maxTokens: root.maxTokens,
            thinkingContent: root.thinkingContent,
            isTransientStatus: root.isTransientStatus,
            queueStatus: root.queueStatus
        )

        _ = await ctx.chatHistoryService.updateMessageAsync(updated, conversationId: ctx.conversationId)
    }

    private static func stripBlock(from text: String) -> String {
        guard let beginRange = text.range(of: beginMarker) else {
            return text.trimmingCharacters(in: .whitespacesAndNewlines)
        }
        if let endRange = text.range(of: endMarker, range: beginRange.upperBound..<text.endIndex) {
            let before = text[..<beginRange.lowerBound]
            let after = text[endRange.upperBound...]
            return (String(before) + String(after)).trimmingCharacters(in: .whitespacesAndNewlines)
        }
        return String(text[..<beginRange.lowerBound]).trimmingCharacters(in: .whitespacesAndNewlines)
    }

    private static func formatBlock(projects: [Project], currentPath: String?) -> String {
        var lines: [String] = [beginMarker, "Recent projects (most recent first):"]
        for p in projects {
            let current = (currentPath != nil && p.path == currentPath) ? " (current)" : ""
            lines.append("- \(p.name)\(current) — \(p.path)")
        }
        lines.append(endMarker)
        return lines.joined(separator: "\n")
    }
}
