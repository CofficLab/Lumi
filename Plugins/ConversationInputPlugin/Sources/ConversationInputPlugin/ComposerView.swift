import AppKit
import EditorChatInputKit
import LumiUI
import SwiftUI

struct ComposerView: View {
    @LumiTheme private var theme

    @Binding var text: String
    @Binding var inputHeight: CGFloat
    @Binding var isInputFocused: Bool
    @Binding var inputCursorPosition: Int
    let isSending: Bool
    let onSend: () -> Void
    let onStop: () -> Void

    var body: some View {
        VStack(spacing: 0) {
            ChatInputEditorView(
                text: $text,
                height: $inputHeight,
                textColor: NSColor(theme.textPrimary),
                onSubmit: sendIfPossible,
                onEnter: sendIfPossible,
                isFocused: $isInputFocused,
                cursorPosition: $inputCursorPosition,
                isImageDragHovering: .constant(false)
            )
            .frame(height: inputHeight)
            .padding(.horizontal, 10)
            .padding(.top, 8)

            Rectangle()
                .fill(theme.appSubtleBorder)
                .frame(height: 1)

            HStack(spacing: 8) {
                Spacer(minLength: 10)

                if isSending {
                    StopButton(action: onStop)
                        .help("Stop")
                } else {
                    SendButton(canSend: canSend, action: sendIfPossible)
                        .help("Send")
                }
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 6)
        }
        .appSurface(style: .toolbar, cornerRadius: 0)
    }

    private var canSend: Bool {
        !text.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty && !isSending
    }

    private func sendIfPossible() {
        guard canSend else { return }
        onSend()
    }
}
