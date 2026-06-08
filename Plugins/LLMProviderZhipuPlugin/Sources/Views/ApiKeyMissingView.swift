import LumiCoreKit
import LumiUI
import SwiftUI

struct ApiKeyMissingView: View {
    @LumiTheme private var theme

    let message: LumiChatMessage
    @Binding var showRawMessage: Bool

    @State private var apiKey: String = ""

    var body: some View {
        ErrorMessageLayout(message: message, showRawMessage: $showRawMessage) {
            VStack(alignment: .leading, spacing: 10) {
                Text(String(localized: "Zhipu API Key required", bundle: .module))
                    .font(.appCallout)
                    .fontWeight(.semibold)
                    .foregroundColor(theme.textPrimary)

                Text(String(localized: "Configure your Zhipu API Key below, then resend your message.", bundle: .module))
                    .font(.appCaption)
                    .foregroundColor(theme.textSecondary)

                if let url = URL(string: ZhipuProvider.apiKeyHelpURL ?? "") {
                    Link(destination: url) {
                        Label(
                            String(localized: "Get API Key on Zhipu Open Platform", bundle: .module),
                            systemImage: "arrow.up.right.square"
                        )
                        .font(.appCaption)
                    }
                    .buttonStyle(.plain)
                    .foregroundColor(theme.primary)
                }

                AppInputField(
                    LocalizedStringKey(String(localized: "Enter Zhipu API Key", bundle: .module)),
                    text: Binding(
                        get: { apiKey },
                        set: { newValue in
                            apiKey = newValue
                            ZhipuProvider.setApiKey(newValue)
                        }
                    ),
                    fieldType: .secure
                )
            }
        }
        .onAppear {
            apiKey = ZhipuProvider.getApiKey()
        }
    }
}
