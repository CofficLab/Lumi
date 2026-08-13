import LLMKit
import KernelLumi
import LumiUI
import SwiftUI

struct HttpErrorView: View {
    @LumiTheme private var theme
    private static let transportDetailsSeparator = "\n\n--- Request / Response Details ---\n"

    let message: LumiChatMessage
    let statusCode: Int?

    private var displayText: String {
        let raw = ((message.rawErrorDetail?.isEmpty == false) ? message.rawErrorDetail : message.content) ?? ""
        return raw.components(separatedBy: Self.transportDetailsSeparator).first ?? raw
    }

    private var rawResponse: String? {
        guard let response = message.metadata[LLMTransportMetadata.responseDetails],
              !response.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else {
            return nil
        }
        return response
    }

    var body: some View {
        ErrorMessageLayout(message: message) {
            VStack(alignment: .leading, spacing: 6) {
                if !displayText.isEmpty {
                    Text(displayText)
                        .font(.appBody)
                        .foregroundColor(theme.error)
                        .textSelection(.enabled)
                }

                if let rawResponse {
                    DisclosureGroup {
                        ScrollView([.horizontal, .vertical]) {
                            Text(rawResponse)
                                .font(.system(.caption, design: .monospaced))
                                .foregroundColor(theme.textSecondary)
                                .textSelection(.enabled)
                                .frame(maxWidth: .infinity, alignment: .leading)
                                .padding(8)
                        }
                        .frame(maxHeight: 260)
                        .background(theme.surface.opacity(0.7))
                        .clipShape(RoundedRectangle(cornerRadius: 6))
                    } label: {
                        Label(
                            LumiPluginLocalization.string("Show raw error details", bundle: .module),
                            systemImage: "curlybraces"
                        )
                        .font(.appCaption)
                    }
                    .foregroundColor(theme.textSecondary)
                }
            }
        }
    }
}
