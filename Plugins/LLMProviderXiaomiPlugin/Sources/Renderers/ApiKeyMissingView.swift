import LLMKit
import LumiKernel
import LumiKernel
import LumiUI
import SwiftUI

/// 「未配置 API Key」时展示的内联配置界面。
///
/// 同时服务于小米 TokenPlan（`xiaomi`）与小米 API（`xiaomi-api`）：根据错误消息的
/// `providerID` 选择对应的 API Key 读写入口与帮助链接，用户填入后即可直接重发消息，
/// 无需跳转到设置页。401 未授权也复用本视图（Key 失效/错误时引导重新填写）。
struct ApiKeyMissingView: View {
    @LumiTheme private var theme

    let message: LumiChatMessage
    @Binding var showRawMessage: Bool

    @State private var apiKey: String = ""
    @State private var isApiKeyVisible = false

    private var providerID: String { message.providerID ?? "" }

    private var displayName: String {
        switch providerID {
        case "xiaomi-api":
            return LumiPluginLocalization.string("Xiaomi API", bundle: .module)
        default:
            return LumiPluginLocalization.string("Xiaomi TokenPlan", bundle: .module)
        }
    }

    private var helpURL: String? {
        switch providerID {
        case "xiaomi-api":
            return XiaomiAPIProvider.apiKeyHelpURL
        default:
            return XiaomiProvider.apiKeyHelpURL
        }
    }

    private var apiKeyStorageKey: String {
        switch providerID {
        case "xiaomi-api":
            return "DevAssistant_ApiKey_XiaomiAPI"
        default:
            return "DevAssistant_ApiKey_Xiaomi"
        }
    }

    var body: some View {
        ErrorMessageLayout(message: message, showRawMessage: $showRawMessage) {
            VStack(alignment: .leading, spacing: 10) {
                Text(String(
                    format: LumiPluginLocalization.string("%@ API Key required", bundle: .module),
                    displayName
                ))
                .font(.appCallout)
                .fontWeight(.semibold)
                .foregroundColor(theme.textPrimary)

                Text(LumiPluginLocalization.string("Configure your Xiaomi API Key below, then resend your message.", bundle: .module))
                    .font(.appCaption)
                    .foregroundColor(theme.textSecondary)

                if let urlString = helpURL, let url = URL(string: urlString) {
                    Link(destination: url) {
                        Label(
                            LumiPluginLocalization.string("Get API Key on Xiaomi MIMO Platform", bundle: .module),
                            systemImage: "arrow.up.right.square"
                        )
                        .font(.appCaption)
                    }
                    .buttonStyle(.plain)
                    .foregroundColor(theme.primary)
                }

                HStack(alignment: .center, spacing: 8) {
                    AppInputField(
                        LocalizedStringKey(LumiPluginLocalization.string("Enter API Key", bundle: .module)),
                        text: Binding(
                            get: { apiKey },
                            set: { newValue in
                                apiKey = newValue
                                LumiAPIKeyTools.set(newValue, storageKey: apiKeyStorageKey)
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
            apiKey = LumiAPIKeyTools.get(storageKey: apiKeyStorageKey)
        }
    }
}