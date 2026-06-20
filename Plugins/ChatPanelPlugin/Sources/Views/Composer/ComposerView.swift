import EditorChatInputKit
import AppKit
import LumiUI
import SwiftUI
import LumiCoreKit

struct ComposerView: View {
    @LumiTheme private var theme

    @Binding var text: String
    @Binding var inputHeight: CGFloat
    @Binding var isInputFocused: Bool
    @Binding var inputCursorPosition: Int
    @Binding var isImageDragHovering: Bool
    let isSending: Bool
    let hasConversation: Bool
    let hasAttachments: Bool
    let leadingToolbarItems: [LumiChatSectionToolbarItem]
    let trailingToolbarItems: [LumiChatSectionToolbarItem]
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
                textColor: NSColor(theme.textPrimary),
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
            .disabled(isSending)

            Rectangle()
                .fill(theme.appSubtleBorder)
                .frame(height: 1)

            HStack(spacing: 8) {
                ScreenshotButton(
                    screenshotState: screenshotState,
                    canAttach: hasConversation,
                    action: { screenshotState.startCapture() }
                )
                ToolbarButton(systemImage: "photo", help: "图片", action: onAttachImage)

                ForEach(leadingToolbarItems) { item in
                    item.makeView()
                }

                Spacer(minLength: 10)

                ForEach(trailingToolbarItems) { item in
                    item.makeView()
                }

                if isSending {
                    StopButton(action: onStop)
                        .help(LumiPluginLocalization.string("Stop", bundle: .module))
                }
                SendButton(isSending: isSending, canSend: canSend, action: sendIfPossible)
                    .help(LumiPluginLocalization.string("Send", bundle: .module))
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
        guard canSend else { return }
        onSend()
    }
}
