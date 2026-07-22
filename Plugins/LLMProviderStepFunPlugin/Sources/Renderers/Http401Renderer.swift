import LLMKit
import LumiKernel
import LumiKernel
import LumiUI
import SwiftUI

enum Http401Renderer {
    private static let pluginOrder = 93 // StepFunPlugin.order

    static let item = LumiMessageRendererItem(
        id: "stepfun-http-401",
        order: pluginOrder + 210,
        canRender: { message in
            StepFunRenderKind.matchesHttp(statusCode: 401, message: message)
        },
        render: { message, showRawMessage in
            Http401View(message: message, showRawMessage: showRawMessage)
        }
    )
}

struct Http401View: View {
    @LumiTheme private var theme

    let message: LumiChatMessage
    @Binding var showRawMessage: Bool

    @State private var apiKey: String = ""
    @State private var isApiKeyVisible = false

    var body: some View {
        ErrorMessageLayout(message: message, showRawMessage: $showRawMessage) {
            VStack(alignment: .leading, spacing: 10) {
                Text(LumiPluginLocalization.string("StepFun API Key invalid or expired", bundle: .module))
                    .font(.appCallout)
                    .fontWeight(.semibold)
                    .foregroundColor(theme.textPrimary)

                Text(LumiPluginLocalization.string("Please check your API Key and try again.", bundle: .module))
                    .font(.appCaption)
                    .foregroundColor(theme.textSecondary)

                HStack(alignment: .center, spacing: 8) {
                    AppInputField(
                        LocalizedStringKey(LumiPluginLocalization.string("Enter StepFun API Key", bundle: .module)),
                        text: Binding(
                            get: { apiKey },
                            set: { newValue in
                                apiKey = newValue
                                LumiAPIKeyTools.set(newValue, storageKey: StepFunProvider.info._apiKeyStorageKey)
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
            apiKey = LumiAPIKeyTools.get(storageKey: StepFunProvider.info._apiKeyStorageKey)
        }
    }
}
