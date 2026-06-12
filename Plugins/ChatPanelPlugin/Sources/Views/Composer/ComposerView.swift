import EditorChatInputKit
import LumiUI
import SwiftUI
import LumiCoreKit

struct ComposerView<LanguagePicker: View, AutomationPicker: View, ProviderPicker: View, VerbosityPicker: View>: View {
    @LumiTheme private var theme

    @Binding var text: String
    @Binding var inputHeight: CGFloat
    @Binding var isInputFocused: Bool
    @Binding var inputCursorPosition: Int
    @Binding var isImageDragHovering: Bool
    let isSending: Bool
    let hasConversation: Bool
    let hasAttachments: Bool
    @ViewBuilder let languagePicker: () -> LanguagePicker
    @ViewBuilder let automationPicker: () -> AutomationPicker
    @ViewBuilder let providerPicker: () -> ProviderPicker
    @ViewBuilder let verbosityPicker: () -> VerbosityPicker
    let onAttachImage: () -> Void
    let onFileDrop: (URL) -> Void
    let onSend: () -> Void
    let onStop: () -> Void
    let onEscape: () -> Void

    @StateObject private var screenshotState = ChatScreenshotState.shared

    var body: some View {
        VStack(spacing: 0) {
            ChatInputEditorView(
                text: $text,
                height: $inputHeight,
                onSubmit: sendIfPossible,
                onEnter: sendIfPossible,
                onEscape: onEscape,
                onFileDrop: onFileDrop,
                isFocused: $isInputFocused,
                cursorPosition: $inputCursorPosition,
                isImageDragHovering: $isImageDragHovering
            )
            .frame(height: inputHeight)
            .padding(.horizontal, 10)
            .padding(.top, 8)
            .disabled(isSending && !canSend)
            .opacity(isSending && !canSend ? 0.7 : 1)

            Rectangle()
                .fill(theme.appSubtleBorder)
                .frame(height: 1)

            HStack(spacing: 8) {
                languagePicker()
                automationPicker()
                verbosityPicker()

                ScreenshotButton(
                    screenshotState: screenshotState,
                    canAttach: hasConversation,
                    action: { screenshotState.startCapture() }
                )
                ToolbarButton(systemImage: "photo", help: "图片", action: onAttachImage)

                providerPicker()
                    .frame(maxWidth: 320, alignment: .leading)

                Spacer(minLength: 10)

                if isSending {
                    StopButton(action: onStop)
                        .help(LumiPluginLocalization.string("Stop", bundle: .module))
                } else {
                    SendButton(isSending: false, canSend: canSend, action: sendIfPossible)
                        .help(LumiPluginLocalization.string("Send", bundle: .module))
                }
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 6)
        }
        .appSurface(style: .toolbar, cornerRadius: 0)
    }

    private var canSend: Bool {
        hasConversation && (
            !text.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty || hasAttachments
        )
    }

    private func sendIfPossible() {
        guard canSend, !isSending else {
            return
        }
        onSend()
    }
}
