import Foundation
import KernelCore
import ProviderChatSection
import ProviderConversation
import ProviderAgentLoop
import ProviderMessage
import SwiftUI

/// 会话详细程度控制插件（V1 简洁 / V2 标准 / V3 详细）。
///
/// 复刻自旧版 `Plugins/ConversationVerbosityPlugin`：
/// - 在 Chat 分区工具栏注册详细度 chip（`ChatSectionBarPlacement.toolbarLeading`）；
/// - 向 AgentLoop 注册 `AgentLoopMessagePreparer`（对齐旧版 `willSendToLLM`）：
///   请求发往 LLM 前注入一条瞬态 system 指令（response style prompt），
///   不落库、只对本次请求生效。
@MainActor
public final class ConversationVerbosityPlugin: SuperPlugin {
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
            return
        }

        // willSendToLLM 钩子：详细度指令注入 system。
        if let agentLoop = kernel.resolveProvider((any AgentLoopProviding).self) {
            agentLoop.addMessagePreparer { [weak conversations] messages in
                guard let conversations else { return messages }
                return await VerbosityPreparer(conversations: conversations).prepare(messages)
            }
        }

        chat.addBarItems([
            ChatSectionBarItem(
                id: "\(id).toolbar-button",
                order: 85,
                placement: .toolbarLeading
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

/// 详细度消息准备器：把选中的 response style 作为瞬态 system 消息注入。
@MainActor
struct VerbosityPreparer {
    private static let promptMarker = "verbosityPrompt"

    let conversations: any ConversationManaging

    func prepare(_ messages: [Message]) async -> [Message] {
        guard let conversationID = messages.first?.conversationID else { return messages }
        let verbosity = conversations.verbosity(for: conversationID)

        let withoutPreviousPrompt = messages.filter {
            $0.metadata[Self.promptMarker] != "true"
        }
        let prompt = Message(
            conversationID: conversationID,
            role: .system,
            content: Self.responseStylePrompt(for: verbosity),
            metadata: [Self.promptMarker: "true"]
        )
        return [prompt] + withoutPreviousPrompt
    }

    static func responseStylePrompt(for verbosity: LumiResponseVerbosity) -> String {
        switch verbosity {
        case .brief:
            return """
            ## Response style: V1 (brief)
            Give the user the direct answer first. Keep the response concise and focused on the requested outcome. Use short paragraphs or a small number of bullets when useful. Omit unnecessary background, repetition, and optional explanations, but do not omit required steps, warnings, errors, or information needed to act on the answer. Do not expose private chain-of-thought; provide only a concise, verifiable explanation when explanation is necessary.
            """
        case .standard:
            return """
            ## Response style: V2 (standard)
            Provide the answer first, followed by the necessary explanation, steps, and important caveats. Keep the response clear and reasonably concise. Include enough context for the user to understand and act on the result. Do not expose private chain-of-thought; summarize reasoning with concise, verifiable explanations.
            """
        case .detailed:
            return """
            ## Response style: V3 (detailed)
            Provide a thorough answer with relevant background, reasoning summaries, implementation details, alternatives, and important edge cases when they help the user. Organize longer responses with clear sections or bullets. Remain focused on the request and do not expose private chain-of-thought; provide concise, verifiable reasoning summaries instead.
            """
        }
    }
}
