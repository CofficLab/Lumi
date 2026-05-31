import SwiftUI
import LumiCoreKit
import LumiUI

public struct InputView: View {
    @EnvironmentObject private var conversationVM: WindowConversationVM
    @LumiUI.LumiTheme private var theme: any LumiUITheme
    @FocusState private var isFocused: Bool

    public init() {}

    public var body: some View {
        VStack(spacing: 8) {
            TextEditor(text: draftBinding)
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
            if conversationVM.draftText.isEmpty {
                conversationVM.setDraftText(value)
            } else {
                conversationVM.setDraftText("\(conversationVM.draftText)\n\n\(value)")
            }
            isFocused = true
        }
    }

    private var draftBinding: Binding<String> {
        Binding(
            get: { conversationVM.draftText },
            set: { conversationVM.setDraftText($0) }
        )
    }

    private var canSubmit: Bool {
        conversationVM.canSubmitText && !conversationVM.draftText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
    }

    private func submit() {
        let value = conversationVM.draftText.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !value.isEmpty else { return }
        Task { await conversationVM.submitDraftText(value) }
    }
}
