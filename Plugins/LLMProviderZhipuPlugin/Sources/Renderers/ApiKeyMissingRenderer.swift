import LLMKit
import LumiCoreMessage
import LumiKernel
import LumiUI
import SwiftUI

enum ApiKeyMissingRenderer {
    static let item = LumiMessageRendererItem(
        id: "zhipu-api-key-missing",
        order: 305,
        canRender: { message in
            ZhipuRenderKind.matchesApiKeyMissing(message)
        },
        render: { message, showRawMessage in
            ApiKeyMissingView(message: message, showRawMessage: showRawMessage)
        }
    )
}

struct ApiKeyMissingView: View {
    @LumiTheme private var theme

    let message: LumiChatMessage
    @Binding var showRawMessage: Bool

    @State private var apiKey: String = ""
    @State private var isApiKeyVisible = false

    var body: some View {
        ErrorMessageLayout(message: message, showRawMessage: $showRawMessage) {
            VStack(alignment: .leading, spacing: 10) {
                Text(LumiPluginLocalization.string("Zhipu API Key required", bundle: .module))
                    .font(.appCallout)
                    .fontWeight(.semibold)
                    .foregroundColor(theme.textPrimary)

                Text(LumiPluginLocalization.string("Configure your Zhipu API Key below, then resend your message.", bundle: .module))
                    .font(.appCaption)
                    .foregroundColor(theme.textSecondary)

                if let url = URL(string: ZhipuProvider.apiKeyHelpURL ?? "") {
                    Link(destination: url) {
                        Label(
                            LumiPluginLocalization.string("Get API Key on Zhipu Open Platform", bundle: .module),
                            systemImage: "arrow.up.right.square"
                        )
                        .font(.appCaption)
                    }
                    .buttonStyle(.plain)
                    .foregroundColor(theme.primary)
                }

                HStack(alignment: .center, spacing: 8) {
                    AppInputField(
                        LocalizedStringKey(LumiPluginLocalization.string("Enter Zhipu API Key", bundle: .module)),
                        text: Binding(
                            get: { apiKey },
                            set: { newValue in
                                apiKey = newValue
                                LumiAPIKeyTools.set(newValue, storageKey: ZhipuProvider.info._apiKeyStorageKey)
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
            apiKey = LumiAPIKeyTools.get(storageKey: ZhipuProvider.info._apiKeyStorageKey)
        }
    }
}
