import LumiCoreKit
import LumiUI
import SwiftUI

struct SublyxRequestFailedView: View {
    @LumiTheme private var theme
    private static let transportDetailsSeparator = "\n\n--- Request / Response Details ---\n"

    let message: LumiChatMessage
    @Binding var showRawMessage: Bool

    private var displayText: String {
        let raw = ((message.rawErrorDetail?.isEmpty == false) ? message.rawErrorDetail : message.content) ?? ""
        return raw.components(separatedBy: Self.transportDetailsSeparator).first ?? raw
    }

    var body: some View {
        ErrorMessageLayout(message: message, showRawMessage: $showRawMessage) {
            VStack(alignment: .leading, spacing: 6) {
                Text(NSLocalizedString("Sublyx request failed", bundle: .module, comment: ""))
                    .font(.appCallout)
                    .fontWeight(.semibold)
                    .foregroundColor(theme.textPrimary)

                if !displayText.isEmpty {
                    Text(displayText)
                        .font(.appCaption)
                        .foregroundColor(theme.textSecondary)
                        .textSelection(.enabled)
                }
            }
        }
    }
}
