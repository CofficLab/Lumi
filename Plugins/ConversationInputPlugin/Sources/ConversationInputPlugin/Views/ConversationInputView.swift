import LumiKernel
import LumiUI
import SuperLogKit
import SwiftUI
import os

/// 输入框视图
struct ConversationInputView: View, SuperLog {
    nonisolated static let logger = Logger(subsystem: "com.coffic.lumi", category: "plugin.conversation-input.view")
    nonisolated static let verbose = true

    @LumiTheme private var theme
    @ObservedObject var kernel: LumiKernel
    @ObservedObject var inputState: InputState
    @State private var errorMessage: String?

    /// 当前是否在向内核发送中
    private var isSending: Bool {
        kernel.messageSender?.isSending ?? false
    }

    var body: some View {
        VStack(spacing: 0) {
            AppDivider()

            if let errorMessage {
                InputErrorView(message: errorMessage, onDismiss: {
                    self.errorMessage = nil
                })
                .padding(.bottom, 4)
            }

            TextField("Send a message...", text: $inputState.text)
                .textFieldStyle(.plain)
                .font(.body)
                .foregroundColor(theme.textPrimary)
                .padding(.horizontal, 12)
                .padding(.vertical, 10)
                .disabled(isSending)
                .onSubmit {
                    send()
                }
        }
        .background(theme.background)
    }

    private func send() {
        let trimmed = inputState.text.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return }
        guard let messageSend = kernel.messageSender else {
            errorMessage = "Message service is not available"
            return
        }

        inputState.text = ""
        errorMessage = nil

        Task { @MainActor in
            do {
                try await messageSend.sendMessage(trimmed, conversationID: nil)
            } catch {
                errorMessage = error.localizedDescription
            }
        }
    }
}
