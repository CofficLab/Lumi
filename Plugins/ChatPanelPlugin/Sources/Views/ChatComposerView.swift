import ChatInputEditorKit
import LumiUI
import SwiftUI

struct ChatComposerView<LanguagePicker: View, AutomationPicker: View, ProviderPicker: View, VerbosityPicker: View>: View {
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

            HStack(spacing: 10) {
                languagePicker()
                automationPicker()
                verbosityPicker()

                providerPicker()
                    .frame(maxWidth: 320, alignment: .leading)

                ChatComposerScreenshotButton(
                    screenshotState: screenshotState,
                    canAttach: hasConversation,
                    action: { screenshotState.startCapture() }
                )
                ChatComposerToolbarButton(systemImage: "photo", help: "图片", action: onAttachImage)

                Spacer(minLength: 10)

                if isSending {
                    ChatComposerStopButton(action: onStop)
                        .help("Stop")
                } else {
                    ChatComposerSendButton(isSending: false, canSend: canSend, action: sendIfPossible)
                        .help("Send")
                }
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 8)
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

private struct ChatComposerScreenshotButton: View {
    @LumiTheme private var theme
    @ObservedObject var screenshotState: ChatScreenshotState

    let canAttach: Bool
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            Group {
                if screenshotState.isPreparing {
                    ProgressView()
                        .controlSize(.small)
                } else {
                    Image(systemName: "crop")
                        .font(.system(size: 15, weight: .semibold))
                }
            }
            .foregroundColor(theme.textSecondary)
            .frame(width: 38, height: 38)
            .background(theme.textPrimary.opacity(0.07), in: Circle())
        }
        .buttonStyle(.plain)
        .disabled(!canAttach || screenshotState.isCapturing)
        .keyboardShortcut("S", modifiers: [.command, .shift])
        .help(helpText)
    }

    private var helpText: String {
        if screenshotState.isPreparing {
            return "准备截图…"
        }
        return "区域截图 (⌘⇧S)"
    }
}

private struct ChatComposerToolbarButton: View {
    @LumiTheme private var theme

    let systemImage: String
    let help: String
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            Image(systemName: systemImage)
                .font(.system(size: 15, weight: .semibold))
                .foregroundColor(theme.textSecondary)
                .frame(width: 38, height: 38)
                .background(theme.textPrimary.opacity(0.07), in: Circle())
        }
        .buttonStyle(.plain)
        .help(help)
    }
}

private struct ChatComposerSendButton: View {
    @LumiTheme private var theme

    let isSending: Bool
    let canSend: Bool
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            Image(systemName: isSending ? "hourglass" : "paperplane.fill")
                .font(.system(size: 15, weight: .semibold))
                .foregroundColor(canSend ? .white : theme.textSecondary.opacity(0.28))
                .frame(width: 40, height: 40)
                .background(sendBackground, in: Circle())
        }
        .buttonStyle(.plain)
        .disabled(!canSend)
    }

    private var sendBackground: Color {
        canSend ? theme.primary : theme.textPrimary.opacity(0.05)
    }
}

private struct ChatComposerStopButton: View {
    @LumiTheme private var theme

    let action: () -> Void

    var body: some View {
        Button(action: action) {
            Image(systemName: "stop.fill")
                .font(.system(size: 14, weight: .semibold))
                .foregroundColor(.white)
                .frame(width: 40, height: 40)
                .background(Color.red.opacity(0.88), in: Circle())
        }
        .buttonStyle(.plain)
    }
}
