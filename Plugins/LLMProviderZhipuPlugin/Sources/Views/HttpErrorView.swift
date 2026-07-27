import LumiKernel
import LumiKernel
import LumiUI
import SwiftUI

struct HttpErrorView: View {
    @LumiTheme private var theme
    private static let transportDetailsSeparator = "\n\n--- Request / Response Details ---\n"

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
        let raw = ((message.rawErrorDetail?.isEmpty == false) ? message.rawErrorDetail : message.content) ?? ""
        var text = raw.components(separatedBy: Self.transportDetailsSeparator).first ?? raw

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
