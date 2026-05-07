import Foundation
import MagicKit
import os

/// 语言偏好注入中间件
///
/// 在每次发送用户消息前，自动读取当前用户的语言偏好，
/// 将语言指令注入到 LLM 的 transientSystemPrompts 中，
/// 让大模型知道应该用什么语言回复。
///
/// ## 设计决策
/// - 语言偏好从 ProjectVM 读取，来源统一
/// - 使用 `LanguagePreference.systemPromptDescription` 作为注入内容
/// - order 设为 -10（很低），确保在其他中间件之前注入，使后续中间件能看到语言上下文
@MainActor
final class LanguageSendMiddleware: SuperSendMiddleware, SuperLog {
    nonisolated static let emoji = "🌐"
    nonisolated static let verbose: Bool = false
    let id: String = "language-preference"
    /// 优先级设为 -10，在大多数中间件之前执行
    let order: Int = -10

    func handle(
        ctx: SendMessageContext,
        next: @escaping @MainActor (SendMessageContext) async -> Void
    ) async {
        let preference = ctx.projectVM.languagePreference

        if Self.verbose {
            os.Logger(subsystem: "com.coffic.lumi", category: "middleware.language")
                .info("🌐 语言中间件：注入 \(preference.displayName)")
        }

        ctx.transientSystemPrompts.append(preference.systemPromptDescription)

        await next(ctx)
    }
}
