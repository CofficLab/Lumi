import LumiCoreMessage
import LumiKernel
import LumiUI
import SwiftUI

struct ErrorMessageView: View {
    @LumiTheme private var theme

    let message: LumiChatMessage
    @Binding var showRawMessage: Bool

    private var transportDetails: ResolvedErrorTransportDetails {
        ErrorTransportDetailsResolver.resolve(for: message)
    }

    private var summaryText: String {
        let summary = transportDetails.displaySummary
        if !summary.isEmpty {
            return summary
        }
        return LumiPluginLocalization.string("Request failed.", bundle: .module)
    }

    var body: some View {
        MessageViewChrome(
            message: message,
            showRawMessage: $showRawMessage,
            errorTransportDetails: transportDetails
        ) {
            BorderedUtilityContent(tint: theme.error, role: .error) {
                Text(summaryText)
                    .font(.appBody)
                    .foregroundColor(theme.error)
                    .textSelection(.enabled)
            }
        }
    }
}
