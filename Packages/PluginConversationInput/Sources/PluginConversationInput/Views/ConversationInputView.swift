import Combine
import LumiUI
import ProviderConversationInput
import ProviderMessageSender
import ProviderPerformanceMetrics
import KitSuperLog
import SwiftUI
import os

/// 输入框视图
///
/// 由旧版 `ConversationInputView` 复刻而来；`kernel` 依赖改为注入
/// 内核的 `ConversationInputProviding` 与 `MessageSendingProviding`。
struct ConversationInputView: View {
    @LumiTheme private var theme

    let input: (any ConversationInputProviding)?
    let sender: (any MessageSendingProviding)?
    let metrics: (any PerformanceMetricsProviding)?
    @ObservedObject var state: ConversationInputViewState

    init(
        input: (any ConversationInputProviding)?,
        sender: (any MessageSendingProviding)?,
        metrics: (any PerformanceMetricsProviding)? = nil,
        state: ConversationInputViewState
    ) {
        self.input = input
        self.sender = sender
        self.metrics = metrics
        _state = ObservedObject(wrappedValue: state)
    }

    var body: some View {
        let _ = state.revision

        VStack(spacing: 0) {
            AppDivider()

            if let errorMessage = state.errorMessage {
                InputErrorView(message: errorMessage, onDismiss: {
                    input?.errorMessage = nil
                })
                .padding(.bottom, 4)
            }

            ComposerView(
                input: input,
                sender: sender,
                onSend: { send() }
            )
        }
        .background(theme.background)
    }

    /// 发送当前输入框文本
    private func send() {
        guard let input, let sender else { return }
        let trimmed = input.text.trimmingCharacters(in: .whitespacesAndNewlines)
        let imageAttachments = sender.pendingImageAttachments
        let fileAttachments = sender.pendingFileAttachments
        let hasAttachments = !imageAttachments.isEmpty || !fileAttachments.isEmpty
        guard !trimmed.isEmpty || hasAttachments else { return }

        let trace = metrics?.begin(
            operation: "chat.send",
            metadata: ["attachments": hasAttachments ? "true" : "false"]
        )

        input.text = ""
        input.errorMessage = nil

        if hasAttachments {
            Task { @MainActor in
                do {
                    guard let commit = try await sender.commitUserMessageInBackground(
                        trimmed,
                        imageAttachments: imageAttachments,
                        fileAttachments: fileAttachments,
                        conversationID: nil
                    ) else { return }
                    if let trace {
                        metrics?.mark(trace, stage: "message.committed")
                        metrics?.end(trace)
                    }
                    guard !commit.wasQueued else { return }
                    await sender.startTurn(for: commit)
                } catch {
                    input.errorMessage = error.localizedDescription
                }
            }
            return
        }

        do {
            guard let commit = try sender.commitUserMessage(
                trimmed,
                imageAttachments: imageAttachments,
                fileAttachments: fileAttachments,
                conversationID: nil
            ) else { return }
            if let trace {
                metrics?.mark(trace, stage: "message.committed")
                metrics?.end(trace)
            }
            guard !commit.wasQueued else { return }

            // 用户消息已同步进入内存时间线；回合跟踪延后，不阻塞 Return → 首帧路径。
            Task { @MainActor in
                await sender.startTurn(for: commit)
            }
        } catch {
            input.errorMessage = error.localizedDescription
        }
    }
}
