import Foundation
import os
import KitLLM
import KernelCore
import ProviderChatSection
import ProviderConversation
import ProviderLifecycleHooks
import SuperLogKit
import SwiftUI

/// 会话详细程度控制插件（V1 简洁 / V2 标准 / V3 详细）。
///
/// 复刻自旧版 `Plugins/ConversationVerbosityPlugin`：
/// - 在 Chat 分区工具栏注册详细度 chip（`ChatSectionBarPlacement.toolbarLeading`）；
/// - 通过 `LifecycleHooksProviding` 注册 `willSendToLLM` 钩子：
///   请求发往 LLM 前注入一条瞬态 system 指令（response style prompt），
///   不落库、只对本次请求生效。
@MainActor
public final class ConversationVerbosityPlugin: SuperPlugin, SuperLog {
    nonisolated static let logger = Logger(subsystem: "com.coffic.lumi.plugin.verbosity", category: "ConversationVerbosity")

    /// 保持旧版插件 ID。
    public let id = "com.coffic.lumi.plugin.verbosity"
    public let order = 85

    public init() {}

    public var metadata: PluginMetadata {
        PluginMetadata(
            id: id,
            name: "Verbosity",
            description: "Response detail level (brief / standard / detailed)",
            category: .chat,
            stage: .preview,
            policy: .alwaysOn
        )
    }

    public func onBoot(kernel: KernelCoreContainer) throws {
        guard let chat = kernel.resolveProvider((any ChatSectionProviding).self),
              let conversations = kernel.resolveProvider((any ConversationManaging).self) else {
            Self.logger.error("\(Self.t)Failed to resolve ChatSectionProviding, ConversationManaging from kernel")
            return
        }

        // willSendToLLM 钩子：详细度指令注入 system。
        if let hooks = kernel.resolveProvider((any LifecycleHooksProviding).self) {
            hooks.addWillSendToLLMHook { [weak conversations] context in
                guard let conversations else { return context }
                let verbosity = conversations.verbosity(for: context.conversationID)
                let prompt: String
                switch verbosity {
                case .brief:
                    prompt = "## Response style: V1 (brief)\nGive the user the direct answer first. Keep the response concise and focused on the requested outcome."
                case .standard:
                    prompt = "## Response style: V2 (standard)\nProvide the answer first, followed by the necessary explanation, steps, and important caveats."
                case .detailed:
                    prompt = "## Response style: V3 (detailed)\nProvide a thorough answer with relevant background, reasoning summaries, implementation details, alternatives, and important edge cases."
                }
                var ctx = context
                ctx.messages = [LLMMessage(role: .system, content: prompt)] + ctx.messages
                return ctx
            }
        }

        chat.addBarItems([
            ChatSectionBarItem(
                id: "\(id).toolbar-button",
                order: 85,
                placement: .toolbarTrailing
            ) {
                VerbosityToolbarView(conversations: conversations)
            },
        ])
    }

    public func onShutdown(kernel: KernelCoreContainer) throws {
        kernel.resolveProvider((any ChatSectionProviding).self)?
            .removeBarItem(id: "\(id).toolbar-button")
    }
}
