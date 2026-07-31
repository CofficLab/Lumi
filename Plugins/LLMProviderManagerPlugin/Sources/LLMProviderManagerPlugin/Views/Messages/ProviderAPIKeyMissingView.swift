import LumiKernel
import LumiUI
import SwiftUI

struct ProviderAPIKeyMissingView: View {
    @LumiTheme private var theme

    let message: LumiChatMessage
    let provider: (any LumiLLMProvider)?

    @State private var apiKey: String = ""
    @State private var isAPIKeyVisible = false
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

                Text("\(providerName) API Key required")
                    .font(.appCallout)
                    .fontWeight(.semibold)
                    .foregroundStyle(theme.textPrimary)

                Spacer(minLength: 8)
            }

            Text("Enter an API Key here, then resend your message.")
                .font(.appCaption)
                .foregroundStyle(theme.textSecondary)

            if let providerWebsiteURL {
                Link(destination: providerWebsiteURL) {
                    Label("Open provider website", systemImage: "arrow.up.right.square")
                        .font(.appCaption)
                }
                .buttonStyle(.plain)
                .foregroundStyle(theme.primary)
            }

            HStack(alignment: .center, spacing: 8) {
                AppInputField(
                    LocalizedStringKey("Enter API Key"),
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
                .help(isAPIKeyVisible ? "Hide API Key" : "Show API Key")
            }

            if provider == nil {
                Text("Provider is not registered yet. Open Settings to configure this key.")
                    .font(.appCaption)
                    .foregroundStyle(theme.textSecondary)
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
                Text("Details")
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
            apiKey = provider?.getApiKey() ?? ""
        }
    }
}
