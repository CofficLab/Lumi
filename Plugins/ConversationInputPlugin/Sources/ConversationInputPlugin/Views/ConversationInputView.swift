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

    var body: some View {
        VStack(spacing: 0) {
            AppDivider()

            if let errorMessage = inputState.errorMessage {
                InputErrorView(message: errorMessage, onDismiss: {
                    inputState.errorMessage = nil
                })
                .padding(.bottom, 4)
            }

            ComposerView(
                text: $inputState.text,
                inputHeight: $inputState.inputHeight,
                isInputFocused: $inputState.isInputFocused,
                inputCursorPosition: $inputState.inputCursorPosition,
                onSend: { inputState.send(kernel: kernel) }
            )
        }
        .background(theme.background)
    }
}
