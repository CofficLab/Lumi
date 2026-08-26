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

    init(input: (any ConversationInputProviding)?, sender: (any MessageSendingProviding)?) {
        self.input = input
        self.sender = sender
        _errorMessage = State(initialValue: input?.errorMessage)
    }

    var body: some View {
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
            // 才能读取到新的错误值。输入文本变化也会经过这里，但只有
            // errorMessage 实际变化时才触发本地状态更新。
            DispatchQueue.main.async {
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
        guard !trimmed.isEmpty else { return }

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
