import LumiCoreKit
import LumiUI
import SwiftUI

/// 「一键续接到新对话」工具栏按钮。
///
/// 点击后：把当前对话摘要（LLM 生成，失败回退为精简摘要）→ 建新对话 →
/// 把摘要作为首条 user 消息注入并自动开始续写。
public struct ConversationForkButton: View {
    let chatService: any LumiChatServicing
    let summarizer: ConversationSummarizer

    @State private var isForking = false
    @State private var lastFallbackNotice: String?

    public init(
        chatService: any LumiChatServicing,
        summarizer: ConversationSummarizer = ConversationSummarizer()
    ) {
        self.chatService = chatService
        self.summarizer = summarizer
    }

    public var body: some View {
        Group {
            if isForking {
                // 摘要请求通常 3~8 秒，给一个明确的进度指示。
                ProgressView()
                    .controlSize(.small)
                    .help(LumiPluginLocalization.string("Summarizing conversation…", bundle: .module))
                    .accessibilityLabel(
                        LumiPluginLocalization.string("Summarizing conversation…", bundle: .module)
                    )
            } else {
                AppIconButton(
                    systemImage: "arrow.uturn.forward.circle",
                    label: LumiPluginLocalization.string("Continue in New Chat", bundle: .module),
                    size: .compact
                ) {
                    fork()
                }
                .help(
                    LumiPluginLocalization.string(
                        "Summarize the current conversation and continue it in a new chat",
                        bundle: .module
                    )
                )
            }
        }
        .help(text: lastFallbackNotice)
    }

    // MARK: - Fork

    @MainActor
    private func fork() {
        guard !isForking,
              let currentID = chatService.selectedConversationID,
              !chatService.messages(for: currentID).isEmpty
        else {
            return
        }

        isForking = true

        Task { @MainActor in
            let outcome = await summarizer.summarize(
                conversationID: currentID,
                chatService: chatService
            )
            let summary = outcome.summary
            lastFallbackNotice = outcome.usedFallback
                ? LumiPluginLocalization.string(
                    "Summary generation failed, used a compact fallback.",
                    bundle: .module
                )
                : nil

            // 记下旧对话的标题 / 项目 / 语言，透传给新对话（与 NewChatButton 的做法一致）。
            let oldTitle = chatService.conversations.first(where: { $0.id == currentID })?.title
            let oldProjectPath = chatService.conversations
                .first(where: { $0.id == currentID })?
                .projectPath
            let language = chatService.language(for: currentID)
            let automationLevel = chatService.automationLevel(for: currentID)

            // createConversation 内部会把新对话设为 selected（见 ConversationManager）。
            let newTitle = String(
                format: LumiPluginLocalization.string("Continued: %@", bundle: .module),
                oldTitle ?? ""
            ).trimmingCharacters(in: .whitespacesAndNewlines)
            let trimmedTitle = newTitle.isEmpty ? nil : newTitle

            let newID = chatService.createConversation(
                title: trimmedTitle,
                projectPath: oldProjectPath,
                language: language
            )
            chatService.setAutomationLevel(automationLevel, for: newID)

            // 注入摘要作为首条 user 消息；enqueueText 会自动触发该对话的 agent turn。
            chatService.enqueueText(
                ForkPromptTemplates.continuePrompt(summary: summary),
                in: newID
            )

            isForking = false
        }
    }
}

// MARK: - help(text:) helper

private extension View {
    /// 仅当传入文本非空时附加 help 提示，避免空 tooltip。
    @ViewBuilder
    func help(text: String?) -> some View {
        if let text, !text.isEmpty {
            self.help(text)
        } else {
            self
        }
    }
}
