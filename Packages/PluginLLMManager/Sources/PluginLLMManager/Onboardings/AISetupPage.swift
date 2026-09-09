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

    /// `AppSegmentedControl` 使用索引选择，需要一个双向映射。
    private var selectedIndex: Binding<Int> {
        Binding(
            get: { providers.firstIndex(where: { $0.providerID == selectedProviderID }) ?? 0 },
            set: { newIndex in
                guard providers.indices.contains(newIndex) else { return }
                selectedProviderID = providers[newIndex].providerID
            }
        )
    }

    var body: some View {
        VStack(spacing: DesignTokens.Spacing.lg) {
            headerSection

            if providers.isEmpty {
                AppEmptyState(
                    icon: "network.slash",
                    title: LumiPluginLocalization.string("No providers available", bundle: .module),
                    description: LumiPluginLocalization.string("You can configure a provider later in Settings.", bundle: .module)
                )
                .frame(maxWidth: .infinity)
                .frame(height: 180)
            } else {
                AppSegmentedControl(
                    providers.map(\.providerInfo.displayName),
                    selection: selectedIndex
                )

                if let provider = selectedProvider {
                    providerDetailCard(provider)
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

    // MARK: - Sections

    private var headerSection: some View {
        AppCard(style: .subtle) {
            VStack(spacing: DesignTokens.Spacing.sm) {
                Image(systemName: "brain.head.profile")
                    .font(.system(size: 48))
                    .foregroundStyle(theme.primary)
                Text(LumiPluginLocalization.string("Set up your AI provider", bundle: .module))
                    .font(DesignTokens.Typography.title3)
                Text(LumiPluginLocalization.string("Add a provider and choose a model in Settings. You can return here at any time from General Settings.", bundle: .module))
                    .font(DesignTokens.Typography.caption1)
                    .multilineTextAlignment(.center)
                    .foregroundStyle(theme.textSecondary)
            }
            .frame(maxWidth: .infinity)
        }
    }

    private func providerDetailCard(_ provider: any SuperLLMProvider) -> some View {
        AppCard(style: .subtle) {
            VStack(alignment: .leading, spacing: DesignTokens.Spacing.md) {
                AppIdentityRow(
                    title: provider.providerInfo.displayName,
                    metadata: [provider.providerInfo.description]
                )

                Divider()

                if provider.providerInfo.isLocal {
                    Label(
                        LumiPluginLocalization.string("This local provider does not require an API key.", bundle: .module),
                        systemImage: "checkmark.circle"
                    )
                    .font(DesignTokens.Typography.subheadline)
                    .foregroundStyle(theme.success)
                } else {
                    AppInputField(
                        LocalizedStringKey(LumiPluginLocalization.string("API Key", bundle: .module)),
                        text: $apiKey,
                        fieldType: .secure
                    )
                    if let website = provider.providerInfo.websiteURL {
                        Link(LumiPluginLocalization.string("Get a key", bundle: .module), destination: website)
                            .font(DesignTokens.Typography.caption1)
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
                        .font(DesignTokens.Typography.caption1)
                        .foregroundStyle(theme.success)
                }
            }
        }
    }

    private func synchronizeSelection() {
        guard selectedProviderID.isEmpty else { return }
        selectedProviderID = manager?.selectedProviderID ?? providers.first?.providerID ?? ""
        apiKey = selectedProvider?.getApiKey() ?? ""
        didSave = selectedProvider?.hasApiKey() ?? false
    }
}
