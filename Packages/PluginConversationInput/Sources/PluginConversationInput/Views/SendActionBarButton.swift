import LumiUI
import ProviderConversationInput
import ProviderMessageSender
import SwiftUI

/// Action Bar 上的发送/停止按钮
///
/// 由旧版 `SendActionBarButton` 复刻而来；`kernel` 依赖改为注入
/// 内核的 `ConversationInputProviding` 与 `MessageSendingProviding`。
struct SendActionBarButton: View {
    let input: (any ConversationInputProviding)?
    let sender: (any MessageSendingProviding)?

    var body: some View {
        let state = SendActionBarState(
            isSending: sender?.isSending ?? false,
            canSend: canSend
        )

        HStack(spacing: 6) {
            if state.showsSendButton {
                SendButton(canSend: state.canSend, action: { send() })
                    .help(LumiPluginLocalization.string("Send", bundle: .module))
            }

            if state.showsStopButton {
                StopButton(action: { sender?.cancelCurrentRequest() })
                    .help(LumiPluginLocalization.string("Stop", bundle: .module))
            }
        }
    }

    private var canSend: Bool {
        guard let input else { return false }
        return !input.text.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
    }

    /// 发送当前输入框文本（沿用旧版 `InputState.send(kernel:)` 语义）。
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

/// Keeps the queue affordance visible while a turn is running.
///
/// Sending another non-empty draft during an active turn enqueues it in
/// `MessageSender`; the stop control is an additional action, not a replacement
/// for the send control.
struct SendActionBarState {
    let isSending: Bool
    let canSend: Bool

    var showsSendButton: Bool { true }
    var showsStopButton: Bool { isSending }
}
