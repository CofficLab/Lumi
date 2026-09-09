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
    @State private var isProviderPickerPresented = false

    private var providers: [any SuperLLMProvider] {
        Self.cloudServiceProviders(from: manager?.allProviders() ?? [])
    }

    private var selectedProvider: (any SuperLLMProvider)? {
        providers.first { $0.providerID == selectedProviderID }
    }

    static func cloudServiceProviders(from providers: [any SuperLLMProvider]) -> [any SuperLLMProvider] {
        providers.filter { $0.providerInfo.providerType == .cloudService }
    }

    var body: some View {
        VStack(spacing: DesignTokens.Spacing.lg) {
            if providers.isEmpty {
                AppEmptyState(
                    icon: "network.slash",
                    title: LumiPluginLocalization.string("No providers available", bundle: .module),
                    description: LumiPluginLocalization.string("You can configure a provider later in Settings.", bundle: .module)
                )
                .frame(maxWidth: .infinity)
                .frame(height: 180)
            } else {
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

    private func providerDetailCard(_ provider: any SuperLLMProvider) -> some View {
        AppCard(style: .subtle) {
            VStack(alignment: .leading, spacing: DesignTokens.Spacing.md) {
                HStack(alignment: .top) {
                    ProviderSelectView(
                        providers: providers,
                        selectedProviderID: $selectedProviderID,
                        isPresented: $isProviderPickerPresented
                    )

                    Spacer()

                    if !provider.providerInfo.isLocal,
                       let website = provider.providerInfo.websiteURL {
                        Link(LumiPluginLocalization.string("Get a key", bundle: .module), destination: website)
                            .font(DesignTokens.Typography.caption1)
                    }
                }

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
                }

                HStack {
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
    }

    private func synchronizeSelection() {
        guard selectedProviderID.isEmpty else { return }
        let managerSelection = manager?.selectedProviderID
        selectedProviderID = providers.first(where: { $0.providerID == managerSelection })?.providerID
            ?? providers.first?.providerID
            ?? ""
        apiKey = selectedProvider?.getApiKey() ?? ""
        didSave = selectedProvider?.hasApiKey() ?? false
    }
}

/// Onboarding 中的供应商选择器，沿用 Projects 工具栏的紧凑按钮 + popover 交互。
private struct ProviderSelectView: View {
    @LumiTheme private var theme

    let providers: [any SuperLLMProvider]
    @Binding var selectedProviderID: String
    @Binding var isPresented: Bool

    private var selectedProvider: (any SuperLLMProvider)? {
        providers.first { $0.providerID == selectedProviderID }
    }

    var body: some View {
        Button {
            isPresented.toggle()
        } label: {
            HStack(spacing: 6) {
                Image(systemName: "cloud")
                    .font(.system(size: 12, weight: .semibold))

                Text(
                    selectedProvider?.providerInfo.displayName
                        ?? LumiPluginLocalization.string("Provider", bundle: .module)
                )
                .font(.system(size: 13, weight: .medium))
                .lineLimit(1)

                Image(systemName: isPresented ? "chevron.up" : "chevron.down")
                    .font(.system(size: 9, weight: .bold))
                    .foregroundStyle(theme.textSecondary)
            }
            .foregroundStyle(theme.textPrimary)
            .padding(.horizontal, 10)
            .padding(.vertical, 6)
            .appSurface(
                style: isPresented ? .listRowHover : .listRow,
                cornerRadius: 6,
                borderColor: isPresented ? theme.appHoverBorder : nil
            )
        }
        .buttonStyle(.plain)
        .popover(isPresented: $isPresented, arrowEdge: .bottom) {
            ProviderSelectPopover(
                providers: providers,
                selectedProviderID: $selectedProviderID,
                isPresented: $isPresented
            )
        }
        .accessibilityLabel(LumiPluginLocalization.string("Provider", bundle: .module))
    }
}

private struct ProviderSelectPopover: View {
    @LumiTheme private var theme

    let providers: [any SuperLLMProvider]
    @Binding var selectedProviderID: String
    @Binding var isPresented: Bool

    var body: some View {
        ScrollView {
            LazyVStack(spacing: 4) {
                ForEach(providers.indices, id: \.self) { index in
                    providerRow(providers[index])
                }
            }
            .padding(8)
        }
        .frame(width: 280)
        .frame(maxHeight: 320)
        .background(theme.background)
    }

    private func providerRow(_ provider: any SuperLLMProvider) -> some View {
        AppListRow(
            isSelected: provider.providerID == selectedProviderID,
            action: {
                selectedProviderID = provider.providerID
                isPresented = false
            }
        ) {
            HStack(spacing: 10) {
                Image(systemName: provider.providerInfo.providerType.systemImage)
                    .font(.system(size: 13, weight: .semibold))
                    .foregroundStyle(provider.providerID == selectedProviderID ? theme.primary : theme.textSecondary)
                    .frame(width: 24, height: 24)
                    .background(Color.primary.opacity(0.06), in: RoundedRectangle(cornerRadius: 6))

                Text(provider.providerInfo.displayName)
                    .font(.system(size: 13, weight: .medium))
                    .lineLimit(1)

                Spacer()

                if provider.providerID == selectedProviderID {
                    Image(systemName: "checkmark")
                        .font(.system(size: 11, weight: .semibold))
                        .foregroundStyle(theme.primary)
                }
            }
        }
    }
}
