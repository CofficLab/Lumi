import LumiCoreKit
import LumiUI
import SwiftUI

/// 智谱 API Key 未配置时的聊天内配置卡片
struct ApiKeyMissingView: View {
    @LumiUI.LumiTheme private var theme: any LumiUITheme

    let message: ChatMessage
    @Binding var showRawMessage: Bool

    @State private var apiKey: String = ""

    private var titleText: String {
        String(localized: "Zhipu API Key required", bundle: .module)
    }

    private var descriptionText: String {
        String(localized: "Configure your Zhipu API Key below, then resend your message.", bundle: .module)
    }

    private var linkLabel: String {
        String(localized: "Get API Key on Zhipu Open Platform", bundle: .module)
    }

    private var inputPlaceholder: String {
        String(localized: "Enter Zhipu API Key", bundle: .module)
    }

    private var helpURL: URL? {
        guard let urlString = ZhipuProvider.apiKeyHelpURL else { return nil }
        return URL(string: urlString)
    }

    var body: some View {
        ErrorMessageLayout(message: message, showRawMessage: $showRawMessage) {
            VStack(alignment: .leading, spacing: 12) {
                HStack(alignment: .top, spacing: 8) {
                    ErrorIconView(size: 16, weight: .medium)

                    VStack(alignment: .leading, spacing: 4) {
                        Text(titleText)
                            .font(.appCallout)
                            .fontWeight(.semibold)
                            .foregroundColor(theme.textPrimary)

                        Text(descriptionText)
                            .font(.appCaption)
                            .foregroundColor(theme.textSecondary)
                    }
                }

                if let helpURL {
                    Link(destination: helpURL) {
                        HStack(spacing: 6) {
                            Image(systemName: "arrow.up.right.square")
                                .font(.appCaption)
                            Text(linkLabel)
                                .font(.appCaption)
                        }
                        .foregroundColor(theme.primary)
                    }
                    .buttonStyle(.plain)
                }

                AppInputField(
                    LocalizedStringKey(inputPlaceholder),
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
            .padding(.vertical, 10)
            .padding(.horizontal, 12)
        }
        .onAppear {
            apiKey = ZhipuProvider.getApiKey()
        }
        .onChange(of: message.providerId) { _, _ in
            apiKey = ZhipuProvider.getApiKey()
        }
    }
}
