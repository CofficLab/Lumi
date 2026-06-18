import LumiCoreKit
import LumiUI
import SwiftUI

struct ErrorMessageView: View {
    @LumiTheme private var theme

    let message: LumiChatMessage
    @Binding var showRawMessage: Bool

    var body: some View {
        MessageViewChrome(message: message, showRawMessage: $showRawMessage) {
            BorderedUtilityContent(tint: theme.error, role: .error) {
                VStack(alignment: .leading, spacing: 8) {
                    Text(message.content.isEmpty ? "Request failed." : message.content)
                        .font(.appBody)
                        .foregroundColor(theme.error)
                        .textSelection(.enabled)

                    if let detail = message.rawErrorDetail, !detail.isEmpty {
                        Text(detail)
                            .font(.appMonoCaption)
                            .foregroundColor(theme.textSecondary)
                            .textSelection(.enabled)
                    }
                }
            }
        }
    }
}
