import LumiCoreKit
import LumiUI
import SwiftUI

struct HttpErrorView: View {
    @LumiTheme private var theme

    let message: LumiChatMessage
    let statusCode: Int?
    @Binding var showRawMessage: Bool

    private var title: String {
        if let statusCode {
            return String(format: NSLocalizedString("Zhipu HTTP %lld", bundle: .module, comment: ""), statusCode)
        }
        return NSLocalizedString("Zhipu request failed", bundle: .module, comment: "")
    }

    private var displayText: String {
        guard let raw = message.rawErrorDetail, !raw.isEmpty else {
            return message.content
        }
        // Strip "HTTP <code> " prefix since it's shown in the title
        var text = raw
        if let code = statusCode {
            let prefix = "HTTP \(code) "
            if text.hasPrefix(prefix) {
                text = String(text.dropFirst(prefix.count))
            }
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
