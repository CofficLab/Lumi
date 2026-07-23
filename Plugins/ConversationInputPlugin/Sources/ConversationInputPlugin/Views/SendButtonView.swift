import LumiKernel
import LumiUI
import SwiftUI

/// 发送/停止按钮视图
struct SendButtonView: View {
    @LumiTheme private var theme
    @ObservedObject var kernel: LumiKernel
    @ObservedObject var inputState: InputState

    private var isSending: Bool {
        kernel.messageSender?.isSending ?? false
    }

    private var canSend: Bool {
        !inputState.text.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty && !isSending
    }

    var body: some View {
        Group {
            if isSending {
                stopButton
            } else {
                sendButton
            }
        }
    }

    private var sendButton: some View {
        Button {
            send()
        } label: {
            Image(systemName: "arrow.up.circle.fill")
                .font(.system(size: 20))
                .foregroundColor(canSend ? theme.primary : theme.textTertiary)
        }
        .buttonStyle(.plain)
        .disabled(!canSend)
        .help("Send")
    }

    private var stopButton: some View {
        Button {
            stop()
        } label: {
            Image(systemName: "stop.circle.fill")
                .font(.system(size: 20))
                .foregroundColor(.red)
        }
        .buttonStyle(.plain)
        .help("Stop")
    }

    private func send() {
        let trimmed = inputState.text.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return }
        guard let messageSend = kernel.messageSender else { return }

        inputState.text = ""

        Task { @MainActor in
            try? await messageSend.sendMessage(trimmed, conversationID: nil)
        }
    }

    private func stop() {
        kernel.messageSender?.cancelCurrentRequest()
    }
}
