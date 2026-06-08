import LumiUI
import SwiftUI

struct ChatComposerView<LanguagePicker: View, AutomationPicker: View, ProviderPicker: View, VerbosityPicker: View>: View {
    @LumiTheme private var theme

    @Binding var text: String
    let isSending: Bool
    let hasConversation: Bool
    @ViewBuilder let languagePicker: () -> LanguagePicker
    @ViewBuilder let automationPicker: () -> AutomationPicker
    @ViewBuilder let providerPicker: () -> ProviderPicker
    @ViewBuilder let verbosityPicker: () -> VerbosityPicker
    let onScreenshot: () -> Void
    let onAttachImage: () -> Void
    let onSend: () -> Void

    var body: some View {
        VStack(spacing: 0) {
            TextField("Message", text: $text, axis: .vertical)
                .textFieldStyle(.plain)
                .font(.appBody)
                .foregroundColor(theme.textPrimary)
                .lineLimit(1...6)
                .padding(.horizontal, 14)
                .padding(.top, 12)
                .padding(.bottom, 10)
                .disabled(isSending)
                .onSubmit {
                    sendIfPossible()
                }

            Rectangle()
                .fill(theme.appSubtleBorder)
                .frame(height: 1)

            HStack(spacing: 10) {
                languagePicker()
                automationPicker()
                verbosityPicker()

                providerPicker()
                    .frame(maxWidth: 320, alignment: .leading)

                ChatComposerToolbarButton(systemImage: "crop", help: "截图", action: onScreenshot)
                ChatComposerToolbarButton(systemImage: "photo", help: "图片", action: onAttachImage)

                Spacer(minLength: 10)

                ChatComposerSendButton(isSending: isSending, canSend: canSend) {
                    sendIfPossible()
                }
                .help(isSending ? "Sending" : "Send")
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 8)
        }
        .appSurface(style: .toolbar, cornerRadius: 0)
    }

    private var canSend: Bool {
        !isSending && !text.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
    }

    private func sendIfPossible() {
        guard canSend else {
            return
        }
        onSend()
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
