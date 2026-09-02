import ProviderConversation
import ProviderMessage
import ProviderMessageSender
import SwiftUI

/// 「一键续接到新对话」按钮。
///
/// 点击后：摘要当前对话 → 建新对话 → 摘要作为首条 user 消息 → 自动续写。
struct ConversationForkButton: View {
    let conversations: any ConversationManaging
    let messages: any MessageManaging
    let sender: any MessageSendingProviding
    let summarizer: ConversationSummarizer

    @State private var isForking = false
    @State private var lastFallbackNotice: String?

    var body: some View {
        Group {
            if isForking {
                ProgressView()
                    .controlSize(.small)
                    .help(LumiPluginLocalization.string("Summarizing conversation…", bundle: .module))
            } else {
                Button {
                    fork()
                } label: {
                    Image(systemName: "arrow.uturn.forward.circle")
                        .font(.system(size: 13, weight: .medium))
                        .foregroundColor(.secondary)
                        .padding(4)
                }
                .buttonStyle(.plain)
                .help(LumiPluginLocalization.string("Summarize the current conversation and continue it in a new chat", bundle: .module))
            }
        }
    }

    @MainActor
    private func fork() {
        guard !isForking,
              conversations.selectedConversationID != nil else {
            return
        }

        isForking = true
        Task { @MainActor in
            guard let currentID = conversations.selectedConversationID,
                  !(await messages.messagesSnapshot(in: currentID)).isEmpty else {
                isForking = false
                return
            }
            let outcome = await summarizer.summarize(conversationID: currentID)
            let summary = outcome.summary
            lastFallbackNotice = outcome.usedFallback
                ? "Summary generation failed, used a compact fallback."
                : nil

            // 透传旧对话的标题 / 项目 / 语言到新对话。
            let oldSummary = conversations.conversations.first { $0.id == currentID }
            let newID = (try? conversations.createConversation(
                title: oldSummary?.title,
                projectPath: oldSummary?.projectPath,
                providerID: conversations.providerID(for: currentID),
                modelName: conversations.modelName(for: currentID)
            )) ?? UUID()
            conversations.selectConversation(id: newID)

            do {
                try await sender.sendMessage(summary, conversationID: newID)
            } catch {
                // 续写失败不致命：摘要已在输入区可见。
            }
            isForking = false
        }
    }
}
