import KernelLumi
import KernelLumi
import LumiUI
import SwiftUI

struct ErrorMessageView: View {
    @LumiTheme private var theme

    let message: LumiChatMessage
    let verbosity: LumiResponseVerbosity

    private var isBrief: Bool { verbosity == .brief }

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

    private var httpBodyText: String? {
        guard let body = message.httpBody?.trimmingCharacters(in: .whitespacesAndNewlines),
              !body.isEmpty else {
            return nil
        }
        return body
    }

    var body: some View {
        MessageViewChrome(
            message: message,
            errorTransportDetails: transportDetails,
            verbosity: verbosity
        ) {
            Group {
                if isBrief {
                    Text(summaryText)
                        .font(.appCaption)
                        .foregroundColor(theme.error)
                        .textSelection(.enabled)
                } else {
                    BorderedUtilityContent(tint: theme.error, role: .error) {
                        VStack(alignment: .leading, spacing: 8) {
                            if let httpStatusCode = message.httpStatusCode {
                                Text("HTTP Status Code: \(httpStatusCode)")
                            }

                            Text(summaryText)

                            if let httpBodyText {
                                Text("HTTP Body:\n\(httpBodyText)")
                            }
                        }
                        .font(.appBody)
                        .foregroundColor(theme.error)
                        .textSelection(.enabled)
                    }
                }
            }
        }
    }
}
