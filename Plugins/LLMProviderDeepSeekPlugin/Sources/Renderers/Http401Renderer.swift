import LLMKit
import KernelLumi
import LumiUI
import SwiftUI

enum Http401Renderer {
    private static let pluginOrder = 92 // DeepSeekPlugin.order

    static let item = LumiMessageRendererItem(
        id: "deepseek-http-401",
        order: pluginOrder + 210,
        canRender: { message in
            DeepSeekRenderKind.matchesHttp(statusCode: 401, message: message)
        },
        render: { message, _ in
            Http401View(message: message)
        }
    )
}

struct Http401View: View {
    @LumiTheme private var theme

    let message: LumiChatMessage

    @State private var apiKey: String = ""
    @State private var isApiKeyVisible = false

    var body: some View {
        ErrorMessageLayout(message: message) {
            VStack(alignment: .leading, spacing: 10) {
                Text(LumiPluginLocalization.string("DeepSeek API Key invalid or expired", bundle: .module))
                    .font(.appCallout)
                    .fontWeight(.semibold)
                    .foregroundColor(theme.textPrimary)

                Text(LumiPluginLocalization.string("Please check your API Key and try again.", bundle: .module))
                    .font(.appCaption)
                    .foregroundColor(theme.textSecondary)

                HStack(alignment: .center, spacing: 8) {
                    AppInputField(
                        LocalizedStringKey(LumiPluginLocalization.string("Enter DeepSeek API Key", bundle: .module)),
                        text: Binding(
                            get: { apiKey },
                            set: { newValue in
                                apiKey = newValue
                                DeepSeekPlugin.setApiKey(newValue)
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
            apiKey = DeepSeekPlugin.currentApiKey
        }
    }
}
