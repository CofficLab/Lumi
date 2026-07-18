import LumiCoreKit
import LLMKit
import LumiCoreKit
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
            return LumiPluginLocalization.string("MiniMax HTTP \(statusCode)", bundle: .module)
        }
        return LumiPluginLocalization.string("MiniMax request failed", bundle: .module)
    }

    private var displayText: String {
        let raw = ((message.rawErrorDetail?.isEmpty == false) ? message.rawErrorDetail : message.content) ?? ""
        return raw.components(separatedBy: Self.transportDetailsSeparator).first ?? raw
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