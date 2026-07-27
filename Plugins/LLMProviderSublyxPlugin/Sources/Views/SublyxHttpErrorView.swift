import LumiKernel
import LumiKernel
import LumiUI
import SwiftUI

struct SublyxHttpErrorView: View {
    @LumiTheme private var theme
    private static let transportDetailsSeparator = "\n\n--- Request / Response Details ---\n"

    let message: LumiChatMessage
    let statusCode: Int
    @Binding var showRawMessage: Bool

    private var title: String {
        String(format: NSLocalizedString("Sublyx HTTP %lld", bundle: .module, comment: ""), statusCode)
    }

    private var displayText: String {
        let raw = ((message.rawErrorDetail?.isEmpty == false) ? message.rawErrorDetail : message.content) ?? ""
        var text = raw.components(separatedBy: Self.transportDetailsSeparator).first ?? raw

        let prefix = "HTTP \(statusCode) "
        if text.hasPrefix(prefix) {
            text = String(text.dropFirst(prefix.count))
        }
        return text
    }

    var body: some View {
        ErrorMessageLayout(message: message, showRawMessage: $showRawMessage) {
            VStack(alignment: .leading, spacing: 6) {
                Text(title)
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
