import SwiftUI
import LumiUI

public struct InputView: View {
    @LumiUI.LumiTheme private var theme: any LumiUITheme
    @State private var text = ""
    @FocusState private var isFocused: Bool

    public init() {}

    public var body: some View {
        VStack(spacing: 8) {
            TextEditor(text: $text)
                .font(.appBody)
                .foregroundColor(theme.textPrimary)
                .scrollContentBackground(.hidden)
                .focused($isFocused)
                .frame(minHeight: 72, maxHeight: 160)
                .padding(8)
                .background(theme.textSecondary.opacity(0.06))
                .clipShape(RoundedRectangle(cornerRadius: 8, style: .continuous))

            HStack {
                Spacer()
                AppButton(
                    String(localized: "Send", table: "ChatInputPlugin"),
                    style: .primary,
                    size: .small
                ) {
                    submit()
                }
                .disabled(!canSubmit)
            }
        }
        .padding(.horizontal, 8)
        .padding(.vertical, 8)
        .background(theme.surface)
        .onAppear {
            isFocused = true
        }
        .onReceive(NotificationCenter.default.publisher(for: Notification.Name("addToChat"))) { notification in
            guard let value = notification.userInfo?["text"] as? String,
                  !value.isEmpty else {
                return
            }
            if text.isEmpty {
                text = value
            } else {
                text += "\n\n\(value)"
            }
            isFocused = true
        }
    }

    private var canSubmit: Bool {
        ChatInputRuntime.canChat && !text.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
    }

    private func submit() {
        let value = text.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !value.isEmpty else { return }
        text = ""
        Task { await ChatInputRuntime.submitText(value) }
    }
}
