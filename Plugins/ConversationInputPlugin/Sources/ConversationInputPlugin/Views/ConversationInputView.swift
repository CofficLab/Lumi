import LumiKernel
import LumiUI
import SuperLogKit
import SwiftUI
import os

/// 输入框视图
struct ConversationInputView: View, SuperLog {
    nonisolated static let logger = Logger(subsystem: "com.coffic.lumi", category: "plugin.conversation-input.view")
    nonisolated static let verbose = false

    @LumiTheme private var theme
    @ObservedObject var kernel: LumiKernel

    var body: some View {
        if let inputState = kernel.conversationInput {
            VStack(spacing: 0) {
                AppDivider()

                if let errorMessage = inputState.errorMessage {
                    InputErrorView(message: errorMessage, onDismiss: {
                        inputState.errorMessage = nil
                    })
                    .padding(.bottom, 4)
                }

                ComposerView(
                    inputState: inputState,
                    kernel: kernel,
                    onSend: { inputState.send(kernel: kernel) }
                )
            }
            .background(theme.background)
        } else {
            EmptyView()
        }
    }
}
