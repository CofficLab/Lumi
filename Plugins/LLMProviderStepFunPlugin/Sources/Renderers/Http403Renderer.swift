import LLMKit
import LumiCoreMessage
import LumiKernel
import LumiUI
import SwiftUI

enum Http403Renderer {
    private static let pluginOrder = 93 // StepFunPlugin.order

    static let item = LumiMessageRendererItem(
        id: "stepfun-http-403",
        order: pluginOrder + 220,
        canRender: { message in
            StepFunRenderKind.matchesHttp(statusCode: 403, message: message)
        },
        render: { message, showRawMessage in
            Http403View(message: message, showRawMessage: showRawMessage)
        }
    )
}

struct Http403View: View {
    @LumiTheme private var theme

    let message: LumiChatMessage
    @Binding var showRawMessage: Bool

    @State private var apiKey: String = ""
    @State private var isApiKeyVisible = false

    var body: some View {
        ErrorMessageLayout(message: message, showRawMessage: $showRawMessage) {
            VStack(alignment: .leading, spacing: 10) {
                Text(LumiPluginLocalization.string("StepFun API access forbidden", bundle: .module))
                    .font(.appCallout)
                    .fontWeight(.semibold)
                    .foregroundColor(theme.textPrimary)

                Text(LumiPluginLocalization.string("Your API Key may not have the required permissions. Please check your account settings.", bundle: .module))
                    .font(.appCaption)
                    .foregroundColor(theme.textSecondary)

                if let url = URL(string: StepFunProvider.apiKeyHelpURL ?? "") {
                    Link(destination: url) {
                        Label(
                            LumiPluginLocalization.string("Check StepFun Account Settings", bundle: .module),
                            systemImage: "arrow.up.right.square"
                        )
                        .font(.appCaption)
                    }
                    .buttonStyle(.plain)
                    .foregroundColor(theme.primary)
                }

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
