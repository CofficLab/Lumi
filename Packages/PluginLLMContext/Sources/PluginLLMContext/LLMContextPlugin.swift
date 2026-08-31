import Foundation
import KernelCore
import KitSuperLog
import os
import ProviderConversation
import ProviderLifecycleHooks
import ProviderLLMContext
import ProviderLLMManager
import ProviderMessage

/// 为 App 提供 LLM 上下文准备能力的独立插件。
@MainActor
public final class LLMContextPlugin: SuperPlugin, SuperLog {
    nonisolated static let logger = Logger(
        subsystem: "com.coffic.lumi.plugin.llm-context",
        category: "LLMContextPlugin"
    )
    public nonisolated static let emoji = "🧠"
    public let id = "com.coffic.lumi.plugin.llm-context"
    public let order = 8
    public let metadata = PluginMetadata(
        id: "com.coffic.lumi.plugin.llm-context",
        name: "LLM Context",
        description: "Prepares bounded LLM context and refreshes summaries in the background.",
        category: .chat,
        stage: .preview,
        policy: .alwaysOn
    )

    private var provider: LLMContextProvider?

    public init() {}

    public func onBoot(kernel: KernelCoreContainer) throws {
        guard let messages = kernel.resolveProvider((any MessageManaging).self),
              let conversations = kernel.resolveProvider((any ConversationManaging).self),
              let llmProvider = kernel.resolveProvider((any LLMManaging).self) else {
            Self.logger.error("\(Self.t)上下文插件缺少消息、会话或 LLM Provider，跳过启动")
            return
        }

        let provider = LLMContextProvider(
            messages: messages,
            conversations: conversations,
            llmProvider: llmProvider
        )
        self.provider = provider

        kernel.unregisterProvider((any LLMContextProviding).self)
        try kernel.registerProvider((any LLMContextProviding).self, provider)

        kernel.resolveProvider((any LifecycleHooksProviding).self)?
            .addTurnFinishedHook { [weak provider] context in
                guard context.endReason == .completed else { return }
                provider?.scheduleBackgroundCompaction(for: context.conversationID)
            }
    }

    public func onShutdown(kernel: KernelCoreContainer) throws {
        provider?.shutdown()
        provider = nil
        kernel.unregisterProvider((any LLMContextProviding).self)
    }
}
