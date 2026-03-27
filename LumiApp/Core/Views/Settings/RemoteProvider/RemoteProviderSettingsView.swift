import SwiftUI

/// 云端大模型设置视图（仅展示远程/API 供应商）
struct RemoteProviderSettingsView: View {
    // MARK: - State

    /// 当前选中的云端供应商 ID
    @State private var selectedProviderId: String = ""

    /// API Key 输入
    @State private var apiKey: String = ""

    /// 选中的模型
    @State private var selectedModel: String = ""

    // MARK: - Environment

    @EnvironmentObject private var registry: LLMProviderRegistry

    // MARK: - Constants

    private static let selectedRemoteProviderKey = "RemoteProviderSettingsView.selectedProviderId"

    // MARK: - Computed

    /// 所有云端供应商（排除本地供应商）
    private var remoteProviders: [LLMProviderInfo] {
        registry
            .allProviders()
            .filter { info in
                (registry.createProvider(id: info.id) as? any SuperLocalLLMProvider) == nil
            }
    }

    /// 当前选中的供应商信息（仅在云端供应商列表中查找）
    private var selectedProvider: LLMProviderInfo? {
        remoteProviders.first(where: { $0.id == selectedProviderId })
    }

    /// 当前供应商类型
    private var selectedProviderType: (any SuperLLMProvider.Type)? {
        registry.providerType(forId: selectedProviderId)
    }

    // MARK: - Body

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: DesignTokens.Spacing.lg) {
                // 供应商选择器卡片
                providerSelectorCard

                // 配置卡片（API Key + 模型列表）
                configurationCard

                Spacer()
            }
            .padding(DesignTokens.Spacing.lg)
        }
        .onAppear(perform: onAppear)
        .onChange(of: selectedProviderId) { _, newValue in
            loadSettings()
            saveSelectedProviderId(newValue)
        }
        .onChange(of: apiKey) { _, _ in
            saveApiKey()
        }
    }
}

// MARK: - View

extension RemoteProviderSettingsView {
    /// 供应商选择器卡片
    private var providerSelectorCard: some View {
        GlassCard {
            VStack(alignment: .leading, spacing: DesignTokens.Spacing.md) {
                GlassSectionHeader(
                    icon: "cloud.fill",
                    title: "云端 LLM 供应商",
                    subtitle: "选择你想使用的 AI 服务提供商"
                )

                GlassDivider()

                HStack(spacing: DesignTokens.Spacing.sm) {
                    ForEach(remoteProviders) { provider in
                        ProviderButton(
                            provider: provider,
                            isSelected: selectedProviderId == provider.id
                        ) {
                            withAnimation(.easeInOut(duration: 0.2)) {
                                selectedProviderId = provider.id
                            }
                        }
                    }
                }
            }
        }
    }

    /// 配置卡片
    private var configurationCard: some View {
        GlassCard {
            VStack(alignment: .leading, spacing: DesignTokens.Spacing.xl) {
                // API Key 区块
                apiKeySection

                // 模型列表区块
                modelSection
            }
        }
    }

    /// API Key 配置区块
    private var apiKeySection: some View {
        VStack(alignment: .leading, spacing: DesignTokens.Spacing.md) {
            GlassSectionHeader(
                icon: "key.fill",
                title: "API 密钥",
                subtitle: "配置你的访问凭证"
            )

            GlassDivider()

            GlassRow {
                HStack(spacing: DesignTokens.Spacing.md) {
                    Image(systemName: "lock.fill")
                        .foregroundColor(DesignTokens.Color.semantic.warning)

                    TextField("输入 API Key", text: $apiKey)
                        .textFieldStyle(.plain)
                        .textContentType(.password)
                        .font(DesignTokens.Typography.body)
                        .foregroundColor(DesignTokens.Color.semantic.textPrimary)

                    Spacer()

                    if !apiKey.isEmpty {
                        Image(systemName: "checkmark.circle.fill")
                            .foregroundColor(DesignTokens.Color.semantic.success)
                    }
                }
            }
        }
    }

    /// 模型列表区块
    private var modelSection: some View {
        VStack(alignment: .leading, spacing: DesignTokens.Spacing.md) {
            GlassSectionHeader(
                icon: "cpu.fill",
                title: "可用模型",
                subtitle: "选择一个模型进行对话"
            )

            GlassDivider()

            VStack(spacing: 0) {
                let models = selectedProvider?.availableModels ?? []
                ForEach(models, id: \.self) { model in
                    RemoteModelRow(
                        model: model,
                        isSelected: selectedModel == model,
                        provider: selectedProvider,
                        onTap: {
                            withAnimation(.easeInOut(duration: 0.2)) {
                                selectedModel = model
                                saveModel()
                            }
                        }
                    )

                    if model != models.last {
                        GlassDivider()
                    }
                }
                .transition(.opacity.combined(with: .move(edge: .top)))
            }
            .animation(.easeInOut(duration: 0.22), value: selectedProvider?.id ?? "")
        }
    }
}

// MARK: - Remote Model Row (简化的独立组件)

struct RemoteModelRow: View {
    let model: String
    let isSelected: Bool
    let provider: LLMProviderInfo?
    let onTap: () -> Void

    @Environment(\.colorScheme) private var colorScheme

    var body: some View {
        GlassRow {
            HStack(spacing: DesignTokens.Spacing.md) {
                // 图标
                Image(systemName: isSelected ? "checkmark.circle.fill" : "circle")
                    .foregroundColor(isSelected ? DesignTokens.Color.semantic.primary : DesignTokens.Color.semantic.textTertiary)
                    .font(.system(size: 20))

                // 模型名称
                Text(model)
                    .font(DesignTokens.Typography.body)
                    .foregroundColor(DesignTokens.Color.semantic.textPrimary)

                Spacer()

                // 默认标记
                if let provider = provider, model == provider.defaultModel {
                    Text("默认")
                        .font(DesignTokens.Typography.caption2)
                        .padding(.horizontal, 6)
                        .padding(.vertical, 2)
                        .background(
                            Capsule()
                                .fill(DesignTokens.Color.semantic.primary.opacity(0.2))
                        )
                        .foregroundColor(DesignTokens.Color.semantic.primary)
                }
            }
            .contentShape(Rectangle())
            .onTapGesture {
                onTap()
            }
        }
    }
}

// MARK: - Actions

extension RemoteProviderSettingsView {
    /// 加载当前供应商的设置信息（API Key 和选中的模型）
    private func loadSettings() {
        guard let providerType = selectedProviderType else { return }
        apiKey = APIKeyStore.shared.string(forKey: providerType.apiKeyStorageKey) ?? ""

        // 加载该供应商的默认模型
        loadSelectedModel()
    }

    /// 保存 API Key 到 Keychain
    private func saveApiKey() {
        guard let providerType = selectedProviderType else { return }
        APIKeyStore.shared.set(apiKey, forKey: providerType.apiKeyStorageKey)
    }

    /// 保存选中的模型到持久化存储
    private func saveModel() {
        guard selectedProviderId.isNotEmpty else { return }
        AppSettingStore.saveRemoteProviderModel(providerId: selectedProviderId, modelId: selectedModel)
        print("✅ Saved model: \(selectedModel) for provider: \(selectedProviderId)")
    }

    /// 保存选中的云端供应商 ID 到持久化存储
    private func saveSelectedProviderId(_ id: String) {
        AppSettingStore.saveSelectedRemoteProviderId(id)
    }

    /// 加载上次选中的云端供应商 ID
    private func loadSelectedProviderId() {
        if let savedId = AppSettingStore.loadSelectedRemoteProviderId(),
           remoteProviders.contains(where: { $0.id == savedId }) {
            selectedProviderId = savedId
        } else if let firstProvider = remoteProviders.first {
            // 如果没有保存的 ID 或保存的 ID 无效，选择第一个供应商
            selectedProviderId = firstProvider.id
        }
    }

    /// 加载当前供应商的默认模型
    private func loadSelectedModel() {
        guard selectedProviderId.isNotEmpty else { return }

        if let savedModel = AppSettingStore.loadRemoteProviderModel(providerId: selectedProviderId),
           selectedProvider?.availableModels.contains(savedModel) == true {
            selectedModel = savedModel
        } else if let defaultModel = selectedProvider?.defaultModel {
            // 如果没有保存的模型或保存的模型无效，使用供应商的默认模型
            selectedModel = defaultModel
        } else if let firstModel = selectedProvider?.availableModels.first {
            // 如果没有默认模型，使用第一个可用模型
            selectedModel = firstModel
        }
    }
}

// MARK: - Lifecycle

extension RemoteProviderSettingsView {
    /// 视图出现时的事件处理 - 加载仅云端供应商的设置
    func onAppear() {
        loadSelectedProviderId()
        loadSettings()
    }
}

// MARK: - Preview

#Preview("Remote Provider Settings") {
    RemoteProviderSettingsView()
        .inRootView()
}

#Preview("Remote Provider Settings - Full App") {
    ContentLayout()
        .hideSidebar()
        .inRootView()
}
