import LumiCoreKit
import LLMKit
import LumiUI
import SwiftUI

enum ApiKeyIssue {
    case missing
    case invalid
}

struct ApiKeyMissingView: View {
    @LumiTheme private var theme

    let message: LumiChatMessage
    var issue: ApiKeyIssue = .missing
    @Binding var showRawMessage: Bool

    @State private var apiKey: String = ""
    @State private var isApiKeyVisible = false

    private var title: String {
        switch issue {
        case .missing:
            LumiPluginLocalization.string("Aliyun API Key required", bundle: .module)
        case .invalid:
            LumiPluginLocalization.string("Aliyun API Key invalid or expired", bundle: .module)
        }
    }

    private var subtitle: String {
        switch issue {
        case .missing:
            LumiPluginLocalization.string("Configure your Aliyun API Key below, then resend your message.", bundle: .module)
        case .invalid:
            LumiPluginLocalization.string("Use a Coding Plan API Key (sk-sp-...) from Model Studio. Update it below, then resend your message.", bundle: .module)
        }
    }

    var body: some View {
        ErrorMessageLayout(message: message, showRawMessage: $showRawMessage) {
            VStack(alignment: .leading, spacing: 10) {
                Text(title)
                    .font(.appCallout)
                    .fontWeight(.semibold)
                    .foregroundColor(theme.textPrimary)

                Text(subtitle)
                    .font(.appCaption)
                    .foregroundColor(theme.textSecondary)

                if let url = URL(string: AliyunProvider.apiKeyHelpURL ?? "") {
                    Link(destination: url) {
                        Label(
                            LumiPluginLocalization.string("Get API Key on Aliyun Model Studio", bundle: .module),
                            systemImage: "arrow.up.right.square"
                        )
                        .font(.appCaption)
                    }
                    .buttonStyle(.plain)
                    .foregroundColor(theme.primary)
                }

                HStack(alignment: .center, spacing: 8) {
                    AppInputField(
                        LocalizedStringKey(LumiPluginLocalization.string("Enter Aliyun API Key", bundle: .module)),
                        text: Binding(
                            get: { apiKey },
                            set: { newValue in
                                apiKey = newValue
                                LumiAPIKeyTools.set(newValue, storageKey: AliyunProvider.info._apiKeyStorageKey)
                            }
                        ),
                        fieldType: isApiKeyVisible ? .plain : .secure
                    )

                    AppIconButton(
                        systemImage: isApiKeyVisible ? "eye.slash" : "eye",
                        tint: isApiKeyVisible ? theme.textPrimary : theme.textSecondary,
                        size: .regular,
                        isActive: isApiKeyVisible
                    ) {
                        isApiKeyVisible.toggle()
                    }
                    .help(
                        isApiKeyVisible
                            ? LumiPluginLocalization.string("Hide API Key", bundle: .module)
                            : LumiPluginLocalization.string("Show API Key", bundle: .module)
                    )
                }
            }
        }
        .onAppear {
            apiKey = LumiAPIKeyTools.get(storageKey: AliyunProvider.info._apiKeyStorageKey)
        }
    }
}
