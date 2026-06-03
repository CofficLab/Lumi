import LumiCoreKit
import LumiUI
import SwiftUI

struct ChatSubmitToolbarButton: View {
    @EnvironmentObject private var conversationVM: WindowConversationVM
    @LumiUI.LumiTheme private var theme: any LumiUITheme

    var body: some View {
        sidebarToolbarButton(
            id: "chat-submit",
            tooltip: String(localized: "Send Message", bundle: .module)
        ) {
            submit()
        } content: {
            Image(systemName: "paperplane.fill")
                .font(.appCaptionEmphasized)
                .foregroundColor(canSubmit ? theme.primary : theme.textSecondary)
                .frame(width: 28, height: 28)
                .background(theme.textPrimary.opacity(0.06))
                .clipShape(Circle())
        }
        .disabled(!canSubmit)
        .accessibilityLabel(String(localized: "Send Message", bundle: .module))
    }

    private var canSubmit: Bool {
        conversationVM.canSubmitText && !conversationVM.draftText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
    }

    private func submit() {
        let draftText = conversationVM.draftText
        Task {
            await conversationVM.submitDraftText(draftText)
        }
    }
}
