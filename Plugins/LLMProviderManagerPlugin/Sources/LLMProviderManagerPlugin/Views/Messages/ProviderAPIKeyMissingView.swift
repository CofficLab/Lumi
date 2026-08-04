import LumiKernel
import LumiUI
import SwiftUI

struct ProviderAPIKeyMissingView: View {
    @LumiTheme private var theme

    let message: LumiChatMessage
    let provider: (any LumiLLMProvider)?

    @State private var apiKey: String = ""
    @State private var isAPIKeyVisible = false
    @State private var keyDiagnostic: LumiLLMProviderAPIKeyDiagnostic?
    /// 内联 "Details" 展开状态:取代之前的外部 `@Binding var showRawMessage`,
    /// 因为该状态仅本视图内部消费,无须再由上层 Renderer 持有。
    @State private var isDetailsExpanded = false

    private var providerName: String {
        provider.map { type(of: $0).info.displayName }
            ?? message.rawErrorDetail?.replacingOccurrences(of: "\(LumiLLMProviderAPIKeyMessage.rawErrorPrefix) ", with: "")
            ?? "LLM Provider"
    }

    private var providerWebsiteURL: URL? {
        provider.map { type(of: $0).info.websiteURL }
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack(alignment: .firstTextBaseline, spacing: 8) {
                Image(systemName: "key.fill")
                    .font(.appCallout)
                    .foregroundStyle(theme.primary)

                Text(String(
                    format: LumiPluginLocalization.string("%@ API Key required", bundle: .module),
                    providerName
                ))
                    .font(.appCallout)
                    .fontWeight(.semibold)
                    .foregroundStyle(theme.textPrimary)

                Spacer(minLength: 8)
            }

            Text(LumiPluginLocalization.string("Enter an API Key here, then resend your message.", bundle: .module))
                .font(.appCaption)
                .foregroundStyle(theme.textSecondary)

            if let providerWebsiteURL {
                Link(destination: providerWebsiteURL) {
                    Label(LumiPluginLocalization.string("Open provider website", bundle: .module), systemImage: "arrow.up.right.square")
                        .font(.appCaption)
                }
                .buttonStyle(.plain)
                .foregroundStyle(theme.primary)
            }

            HStack(alignment: .center, spacing: 8) {
                AppInputField(
                    LocalizedStringKey(LumiPluginLocalization.string("Enter API Key", bundle: .module)),
                    text: Binding(
                        get: { apiKey },
                        set: { newValue in
                            apiKey = newValue
                            provider?.setApiKey(newValue)
                        }
                    ),
                    fieldType: isAPIKeyVisible ? .plain : .secure
                )
                .disabled(provider == nil)

                AppIconButton(
                    systemImage: isAPIKeyVisible ? "eye.slash" : "eye",
                    tint: isAPIKeyVisible ? theme.textPrimary : theme.textSecondary,
                    size: .regular,
                    isActive: isAPIKeyVisible
                ) {
                    isAPIKeyVisible.toggle()
                }
                .help(isAPIKeyVisible ? LumiPluginLocalization.string("Hide API Key", bundle: .module) : LumiPluginLocalization.string("Show API Key", bundle: .module))
            }

            if provider == nil {
                Text(LumiPluginLocalization.string("Provider is not registered yet. Open Settings to configure this key.", bundle: .module))
                    .font(.appCaption)
                    .foregroundStyle(theme.textSecondary)
            } else if let keyDiagnostic {
                diagnosticView(keyDiagnostic)
            }

            DisclosureGroup(isExpanded: $isDetailsExpanded) {
                if let raw = message.rawErrorDetail, !raw.isEmpty {
                    Text(raw)
                        .font(.appCaption)
                        .foregroundStyle(theme.textSecondary)
                        .textSelection(.enabled)
                        .padding(.top, 4)
                }
            } label: {
                Text(LumiPluginLocalization.string("Details", bundle: .module))
                    .font(.appCaption)
                    .foregroundStyle(theme.textSecondary)
            }
        }
        .padding(12)
        .background(theme.surface)
        .clipShape(RoundedRectangle(cornerRadius: 8, style: .continuous))
        .overlay {
            RoundedRectangle(cornerRadius: 8, style: .continuous)
                .strokeBorder(theme.divider, lineWidth: 1)
        }
        .onAppear {
            refreshKeyDiagnostic()
        }
    }

    @ViewBuilder
    private func diagnosticView(_ diagnostic: LumiLLMProviderAPIKeyDiagnostic) -> some View {
        switch diagnostic {
        case .configured:
            Text("当前 Keychain 中仍可读取到 API Key。上面的错误是请求当时产生的历史错误，建议直接重试。")
                .font(.appCaption)
                .foregroundStyle(theme.warning)
        case .missing:
            Text("当前 Keychain 中没有找到 API Key。若你确认已经配置，请检查钥匙串访问权限或重新保存一次。")
                .font(.appCaption)
                .foregroundStyle(theme.warning)
        case .inaccessible(let details):
            VStack(alignment: .leading, spacing: 4) {
                Text("当前无法读取 macOS Keychain，Key 本身没有被判定为缺失。")
                    .font(.appCaption)
                    .foregroundStyle(theme.warning)
                Text(details)
                    .font(.appCaption)
                    .foregroundStyle(theme.textSecondary)
                    .textSelection(.enabled)
            }
        }
    }

    private func refreshKeyDiagnostic() {
        guard let provider else {
            apiKey = ""
            keyDiagnostic = nil
            return
        }

        // Use the request's resolver so the UI does not turn a Keychain
        // access error into the misleading "missing" state.
        keyDiagnostic = provider.apiKeyDiagnostic()
        apiKey = provider.getApiKey()
    }
}
