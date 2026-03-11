import Foundation

/// 上下文注入中间件
///
/// 目标：
/// - 在“发送前”把常用上下文注入给模型（项目、选中文件、选中文本）
/// - 控制体积：对大字段做截断，避免拖慢请求与污染上下文窗口
@MainActor
struct ContextInjectionMiddleware: MessageSendMiddleware {
    let id: String = "agent.context-injection"
    let order: Int = 95

    private let maxSelectedTextChars = 800
    private let maxSelectedFileChars = 2000

    func handle(
        event: MessageSendEvent,
        ctx: MessageSendMiddlewareContext,
        next: @escaping @MainActor (MessageSendEvent, MessageSendMiddlewareContext) async -> Void
    ) async {
        guard case let .sendMessage(message, conversationId) = event, message.role == .user else {
            await next(event, ctx)
            return
        }

        var lines: [String] = []

        if ctx.services.isProjectSelected() {
            let info = ctx.services.getProjectInfo()
            if !info.name.isEmpty { lines.append("项目：\(info.name)") }
            if !info.path.isEmpty { lines.append("路径：\(info.path)") }
        }

        if ctx.services.isFileSelected() {
            let file = ctx.services.getSelectedFileInfo()
            if !file.path.isEmpty {
                lines.append("选中文件：\(file.path)")
            }
            let content = file.content.trimmingCharacters(in: .whitespacesAndNewlines)
            if !content.isEmpty {
                lines.append("选中文件内容（截断）：\(truncate(content, max: maxSelectedFileChars))")
            }
        }

        if let selected = ctx.services.getSelectedText()?.trimmingCharacters(in: .whitespacesAndNewlines),
           !selected.isEmpty {
            lines.append("选中文本（截断）：\(truncate(selected, max: maxSelectedTextChars))")
        }

        // 没有可注入上下文：直接透传
        guard !lines.isEmpty else {
            await next(event, ctx)
            return
        }

        let block = """
        [上下文]
        \(lines.joined(separator: "\n"))
        [/上下文]

        """

        // 避免重复注入（例如上游中间件重放事件）
        if message.content.hasPrefix("[上下文]\n") {
            await next(event, ctx)
            return
        }

        let rewritten = ChatMessage(role: .user, content: block + message.content, images: message.images)
        await next(.sendMessage(rewritten, conversationId: conversationId), ctx)
    }

    private func truncate(_ text: String, max: Int) -> String {
        if text.count <= max { return text }
        return String(text.prefix(max)) + "…"
    }
}

