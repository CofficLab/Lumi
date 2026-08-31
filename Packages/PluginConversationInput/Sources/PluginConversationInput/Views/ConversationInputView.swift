import Combine
import LumiUI
import ProviderConversationInput
import ProviderMessageSender
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
    @State private var errorMessage: String?
    /// 输入 Provider 的 `objectWillChange` 不会自动让这个 View 重建，
    /// 而 `ComposerView` 依赖的是普通 Binding；用 revision 让文本变化触发
    /// `ChatInputEditorView.updateNSView`，及时把 NSTextView 同步到 Provider。
    @State private var inputRevision = 0

    init(input: (any ConversationInputProviding)?, sender: (any MessageSendingProviding)?) {
        self.input = input
        self.sender = sender
        _errorMessage = State(initialValue: input?.errorMessage)
    }

    var body: some View {
        let _ = inputRevision

        VStack(spacing: 0) {
            AppDivider()

            if let errorMessage {
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
        .onReceive(input?.objectWillChange ?? ObservableObjectPublisher()) { _ in
            // ObservableObjectPublisher 在 @Published 写入前发送，延迟一拍
            // 才能读取到新的错误值；同时递增 revision，确保输入文本变化
            // 也会触发 ComposerView 的 NSView 同步。
            DispatchQueue.main.async {
                inputRevision &+= 1
                let newValue = input?.errorMessage
                if errorMessage != newValue {
                    errorMessage = newValue
                }
            }
        }
    }

    /// 发送当前输入框文本
    private func send() {
        guard let input, let sender else { return }
        let trimmed = input.text.trimmingCharacters(in: .whitespacesAndNewlines)
        let hasAttachments = !sender.pendingImageAttachments.isEmpty || !sender.pendingFileAttachments.isEmpty
        guard !trimmed.isEmpty || hasAttachments else { return }

        input.text = ""
        input.errorMessage = nil

        Task { @MainActor in
            do {
                try await sender.sendMessage(trimmed, conversationID: nil)
            } catch {
                input.errorMessage = error.localizedDescription
            }
        }
    }
}
