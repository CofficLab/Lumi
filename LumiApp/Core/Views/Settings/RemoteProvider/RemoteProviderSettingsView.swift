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
            VStack(alignment: .leading, spacing: DesignTokens.Spacing.xl) {
                // 云端供应商选择器
                providerSelector

                // API Key + 可用模型列表
                RemoteModelSectionView(
                    selectedProvider: selectedProvider,
                    selectedModel: $selectedModel,
                    apiKey: $apiKey,
                    onSelectModel: saveModel
                )

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
    /// 云端供应商选择器
    private var providerSelector: some View {
        VStack(alignment: .leading, spacing: DesignTokens.Spacing.sm) {
            Text("云端 LLM 供应商")
                .font(DesignTokens.Typography.callout)
                .foregroundColor(DesignTokens.Color.semantic.textSecondary)

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

#Preview {
    RemoteProviderSettingsView()
        .inRootView()
}
