import LumiCoreKit
import LumiUI
import SwiftUI

struct ChatSubmitToolbarButton: View {
    @LumiUI.LumiTheme private var theme: any LumiUITheme
    let submitContext: ChatSubmitContext

    var body: some View {
        sidebarToolbarButton(
            id: "chat-submit",
            tooltip: LumiPluginLocalization.string("Send Message", bundle: .module)
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
        .accessibilityLabel(LumiPluginLocalization.string("Send Message", bundle: .module))
    }

    private var canSubmit: Bool {
        submitContext.canSubmit
    }

    private func submit() {
        Task {
            await submitContext.submitDraft()
        }
    }
}
