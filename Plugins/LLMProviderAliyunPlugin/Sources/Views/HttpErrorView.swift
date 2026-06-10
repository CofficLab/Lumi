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
            return String(localized: "Aliyun HTTP \(statusCode)", bundle: .module)
        }
        return String(localized: "Aliyun request failed", bundle: .module)
    }

    private var displayText: String {
        if let raw = message.rawErrorDetail, !raw.isEmpty {
            return raw
        }
        return message.content
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
