import AgentToolKit
import LumiCoreKit
import os

/// 将当前对话语言偏好注入到 LLM 临时系统提示中。
@MainActor
public final class LanguageSendMiddleware: SuperSendMiddleware {
    public let id = "language-preference"
    public let order = -10

    public init() {}

    public func handle(
        ctx: SendMessageContext,
        next: @escaping @MainActor (SendMessageContext) async -> Void
    ) async {
        let preference = ctx.languagePreference
        os.Logger(subsystem: "com.coffic.lumi", category: "middleware.language")
            .info("🌐 语言中间件：注入 \(preference.displayName)")
        ctx.transientSystemPrompts.append(preference.systemPromptDescription)
        await next(ctx)
    }
}
