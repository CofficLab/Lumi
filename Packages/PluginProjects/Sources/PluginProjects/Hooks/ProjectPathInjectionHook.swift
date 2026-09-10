import Foundation
import KitLLM
import KitSuperLog
import os
import ProviderConversation
import ProviderLifecycleHooks

/// `willSendToLLM` 钩子：将当前对话绑定的项目路径注入 LLM 上下文。
///
/// 项目路径属于对话，而不是当前 UI 打开的项目。未找到对话、未绑定项目或
/// 项目路径为空时不注入，保持原始上下文不变。
@MainActor
final class ProjectPathInjectionHook: SuperLog {
    nonisolated static let logger = Logger(
        subsystem: "com.coffic.lumi.plugin.projects",
        category: "Projects.Hook"
    )

    private let conversations: any ConversationManaging

    init(conversations: any ConversationManaging) {
        self.conversations = conversations
    }

    func apply(to context: WillSendToLLMContext) async -> WillSendToLLMContext {
        guard let projectPath = (await conversations.fetchConversation(id: context.conversationID))?.projectPath?
                .trimmingCharacters(in: .whitespacesAndNewlines),
              !projectPath.isEmpty else {
            return context
        }
        var ctx = context
        let projectMessage = LLMMessage(
            role: .system,
            content: "当前对话项目路径：\(projectPath)"
        )
        ctx.messages = [projectMessage] + ctx.messages
        return ctx
    }
}
