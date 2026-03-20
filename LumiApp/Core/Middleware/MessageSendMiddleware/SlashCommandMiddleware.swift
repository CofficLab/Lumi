import Foundation
import MagicKit

/// 把 Slash 命令分发从 `SendMessageHandler` 迁移到中间件层。
///
/// 目标：当命令被“处理完”时短路；当 `.notHandled` 时继续让后续插件链 + core send 执行。
@MainActor
struct SlashCommandMiddleware: MessageSendMiddleware, SuperLog {
    nonisolated static let emoji = "⌨️"
    nonisolated static let verbose = SendMessageHandler.verbose

    let id: String = "core.send-message.slash-command"
    let order: Int = 10

    func handle(
        event: MessageSendEvent,
        ctx: MessageSendMiddlewareContext,
        next: @escaping @MainActor (MessageSendEvent, MessageSendMiddlewareContext) async -> Void
    ) async {
        guard case let .sendMessage(message, conversationId) = event else {
            await next(event, ctx)
            return
        }

        let trimmed = message.content.trimmingCharacters(in: .whitespacesAndNewlines)

        let isCommand = await ctx.services.isSlashCommand(trimmed)
        guard isCommand else {
            await next(event, ctx)
            return
        }

        if Self.verbose {
            AppLogger.core.info("\(Self.t) 🔧 检测到 Slash 命令：\(trimmed)")
        }

        let result = await ctx.services.handleSlashCommand(trimmed)
        switch result {
        case .handled:
            if Self.verbose {
                AppLogger.core.info("\(Self.t) ✅ Slash 命令已处理")
            }
            return

        case .notHandled:
            if Self.verbose {
                AppLogger.core.info("\(Self.t) ⚠️ Slash 命令未处理，作为普通消息发送")
            }

            // 保持原本的异步时序：发送队列移除早于 core send 完成。
            Task { @MainActor in
                await next(event, ctx)
            }
            return

        case let .error(msg):
            if Self.verbose {
                AppLogger.core.info("\(Self.t) ❌ Slash 命令执行出错：\(msg)")
            }
            let errorMessage = ChatMessage(role: .assistant, content: "命令错误：\(msg)", isError: true)
            ctx.services.appendMessage(errorMessage)
            return

        case let .systemMessage(content):
            if Self.verbose {
                AppLogger.core.info("\(Self.t) 📋 添加系统消息")
            }
            let systemMessage = ChatMessage(role: .assistant, content: content)
            ctx.services.appendMessage(systemMessage)
            return

        case let .userMessage(content, triggerProcessing):
            if Self.verbose {
                AppLogger.core.info("\(Self.t) 📝 添加用户消息并触发处理：\(triggerProcessing)")
            }
            let userMessage = ChatMessage(role: .user, content: content)
            ctx.services.appendMessage(userMessage)

            // 保持原本的异步时序：这里不阻塞 pipeline 返回。
            Task { @MainActor in
                await ctx.services.saveMessage(userMessage, conversationId)
                if triggerProcessing {
                    ctx.services.enqueueTurnProcessing(conversationId, 0)
                }
            }
            return

        case .clearHistory:
            if Self.verbose {
                AppLogger.core.info("\(Self.t) 🗑️ 清空历史记录")
            }
            return

        case let .triggerPlanning(task):
            if Self.verbose {
                AppLogger.core.info("\(Self.t) 📋 触发规划模式：\(task)")
            }
            return

        case let .mcpCommand(subCommand, param):
            if Self.verbose {
                AppLogger.core.info("\(Self.t) 🔧 MCP 命令：\(subCommand) \(param)")
            }
            return
        }
    }
}

