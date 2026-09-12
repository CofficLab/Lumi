import KitLLM
import LumiUI
import PluginLLMProviderSettings
import SwiftUI

/// AI 模型配置引导页 —— 首次启动时引导用户选择 LLM 供应商并填写 API Key。
///
/// View 只依赖 `AISetupViewModel`，不直接持有 `LLMManaging` 或 Store。
struct AISetupPage: View {
    @LumiTheme private var theme
    @ObservedObject private var viewModel: AISetupViewModel

    @State private var isProviderPickerPresented = false
    @State private var isCustomProviderEditorPresented = false

    init(viewModel: AISetupViewModel) {
        self.viewModel = viewModel
    }

    var body: some View {
        VStack(spacing: DesignTokens.Spacing.lg) {
            if viewModel.providers.isEmpty {
                AppEmptyState(
                    icon: "network.slash",
                    title: LumiPluginLocalization.string("No providers available", bundle: .module),
                    description: LumiPluginLocalization.string("You can configure a provider later in Settings.", bundle: .module)
                )
                .frame(maxWidth: .infinity)
                .frame(height: 180)
            } else {
                if let provider = viewModel.selectedProvider {
                    providerDetailCard(provider)
                }
            }

            Text(LumiPluginLocalization.string("You can also configure providers anytime in Settings > Cloud Providers.", bundle: .module))
                .font(DesignTokens.Typography.caption1)
                .foregroundStyle(theme.textSecondary)
                .multilineTextAlignment(.center)
        }
        .frame(maxWidth: 460)
        .padding(.vertical, DesignTokens.Spacing.xxl - 4)
        .onAppear { viewModel.synchronizeSelection() }
        .sheet(isPresented: $isCustomProviderEditorPresented) {
            if let editor = viewModel.makeCustomProviderEditor() {
                editor
                    .frame(width: 560, height: 620)
            }
        }
    }

    // MARK: - Sections

    private func providerDetailCard(_ provider: any SuperLLMProvider) -> some View {
        AppCard(style: .subtle) {
            VStack(alignment: .leading, spacing: DesignTokens.Spacing.md) {
                HStack(alignment: .top) {
                    ProviderSelectView(
                        providers: viewModel.providers,
                        selectedProviderID: $viewModel.selectedProviderID,
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
                        text: $viewModel.apiKey,
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
                            viewModel.saveAPIKey()
                        }
                    )
                    .disabled(!provider.providerInfo.isLocal && viewModel.apiKey.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)

                    Spacer()

                    if viewModel.didSave {
                        Label(LumiPluginLocalization.string("Saved", bundle: .module), systemImage: "checkmark.circle.fill")
                            .font(DesignTokens.Typography.caption1)
                            .foregroundStyle(theme.success)
                    }
                }
            }
        }
        .overlay(alignment: .topTrailing) {
            if viewModel.customProviderEditorAvailable {
                AppButton(
                    "添加供应商",
                    systemImage: "plus",
                    style: .tonal,
                    size: .small
                ) {
                    isCustomProviderEditorPresented = true
                }
                .offset(x: 12, y: -12)
            }
        }
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
