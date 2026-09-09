import KitLLM
import LumiUI
import ProviderLLMManager
import SwiftUI

/// AI 模型配置引导页 —— 首次启动时引导用户选择 LLM 供应商并填写 API Key。
struct AISetupPage: View {
    let manager: (any LLMManaging)?
    @LumiTheme private var theme
    @State private var selectedProviderID = ""
    @State private var apiKey = ""
    @State private var didSave = false

    private var providers: [any SuperLLMProvider] { manager?.allProviders() ?? [] }

    private var selectedProvider: (any SuperLLMProvider)? {
        manager?.provider(id: selectedProviderID)
    }

    var body: some View {
        VStack(alignment: .leading, spacing: DesignTokens.Spacing.lg) {
            Image(systemName: "brain.head.profile")
                .font(.system(size: 54))
                .foregroundStyle(theme.primary)
                .frame(maxWidth: .infinity)
            Text(LumiPluginLocalization.string("Set up your AI provider", bundle: .module))
                .font(DesignTokens.Typography.title2)
            Text(LumiPluginLocalization.string("Add a provider and choose a model in Settings. You can return here at any time from General Settings.", bundle: .module))
                .font(DesignTokens.Typography.body)
                .multilineTextAlignment(.center)
                .foregroundStyle(theme.textSecondary)

            if providers.isEmpty {
                ContentUnavailableView(
                    LumiPluginLocalization.string("No providers available", bundle: .module),
                    systemImage: "network.slash",
                    description: Text(LumiPluginLocalization.string("You can configure a provider later in Settings.", bundle: .module))
                )
            } else {
                Picker(LumiPluginLocalization.string("Provider", bundle: .module), selection: $selectedProviderID) {
                    ForEach(providers, id: \.providerID) { provider in
                        Text(provider.providerInfo.displayName).tag(provider.providerID)
                    }
                }

                if let provider = selectedProvider {
                    Text(provider.providerInfo.description)
                        .font(DesignTokens.Typography.subheadline)
                        .foregroundStyle(theme.textSecondary)

                    if provider.providerInfo.isLocal {
                        Label(LumiPluginLocalization.string("This local provider does not require an API key.", bundle: .module), systemImage: "checkmark.circle")
                            .font(DesignTokens.Typography.subheadline)
                            .foregroundStyle(theme.textSecondary)
                    } else {
                        AppInputField(
                            LocalizedStringKey(LumiPluginLocalization.string("API Key", bundle: .module)),
                            text: $apiKey,
                            fieldType: .secure
                        )
                        if let website = provider.providerInfo.websiteURL {
                            Link(LumiPluginLocalization.string("Get a key", bundle: .module), destination: website)
                                .font(DesignTokens.Typography.subheadline)
                        }
                    }

                    AppButton(
                        LumiPluginLocalization.string(
                            provider.providerInfo.isLocal ? "Use Provider" : "Save API Key",
                            bundle: .module
                        ),
                        style: .primary,
                        action: {
                            provider.setApiKey(apiKey)
                            manager?.select(providerID: provider.providerID, model: nil)
                            apiKey = provider.getApiKey()
                            didSave = true
                        }
                    )
                    .disabled(!provider.providerInfo.isLocal && apiKey.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)

                    if didSave {
                        Label(LumiPluginLocalization.string("Saved", bundle: .module), systemImage: "checkmark.circle.fill")
                            .font(DesignTokens.Typography.subheadline)
                            .foregroundStyle(theme.success)
                    }
                }
            }
        }
        .frame(maxWidth: 460)
        .padding(.vertical, DesignTokens.Spacing.xxl - 4)
        .onAppear { synchronizeSelection() }
        .onChange(of: selectedProviderID) { _, _ in
            apiKey = selectedProvider?.getApiKey() ?? ""
            didSave = selectedProvider?.hasApiKey() ?? false
        }
    }

    private func synchronizeSelection() {
        guard selectedProviderID.isEmpty else { return }
        selectedProviderID = manager?.selectedProviderID ?? providers.first?.providerID ?? ""
        apiKey = selectedProvider?.getApiKey() ?? ""
        didSave = selectedProvider?.hasApiKey() ?? false
    }
}
