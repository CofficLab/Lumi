import os
import SwiftUI
import MagicKit

/// 云端大模型设置视图（仅展示远程/API 供应商）
struct RemoteProviderSettingsView: View, SuperLog {
    nonisolated static let emoji = "☁️"
    nonisolated static let verbose = true

    // MARK: - State

    /// 当前选中的云端供应商 ID
    @State private var selectedProviderId: String = ""

    /// API Key 输入
    @State private var apiKey: String = ""

    /// 选中的模型
    @State private var selectedModel: String = ""

    /// 是否正在加载设置（加载期间禁止 onChange(of: apiKey) 触发保存，避免竞态写入）
    @State private var isLoadingSettings: Bool = false

    // MARK: - Environment

    @EnvironmentObject private var registry: LLMProviderRegistry

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
        HStack(alignment: .top, spacing: AppUI.Spacing.lg) {
            // 云端供应商列表（固定宽度）
            cloudProviderCard
                .frame(maxWidth: 320, alignment: .topLeading)

            ScrollView {
                VStack(alignment: .leading, spacing: AppUI.Spacing.lg) {
                    // 配置卡片（API Key + 模型列表）
                    if selectedProvider != nil {
                        configurationCard
                    }

                    Spacer(minLength: 0)
                }
                .padding(.horizontal, AppUI.Spacing.lg)
            }
        }
        .padding(AppUI.Spacing.lg)
        .onAppear(perform: onAppear)
        .onChange(of: selectedProviderId) {
            if Self.verbose {
                AppLogger.core.info("\(Self.t)供应商切换 \(r("newId=\(selectedProviderId)"))")
            }
            loadSettings()
            saveSelectedProviderId(selectedProviderId)
        }
        .onChange(of: apiKey) {
            if Self.verbose {
                AppLogger.core.info("\(Self.t)apiKey 变化，isLoadingSettings=\(isLoadingSettings)，长度=\(apiKey.count)")
            }
            saveApiKey()
        }
    }
}

// MARK: - View

extension RemoteProviderSettingsView {
    /// 云端供应商卡片（固定）
    private var cloudProviderCard: some View {
        GlassCard {
            VStack(alignment: .leading, spacing: AppUI.Spacing.md) {
                GlassSectionHeader(
                    icon: "cloud.fill",
                    title: "云端 LLM 供应商",
                    subtitle: "选择你想使用的 AI 服务提供商"
                )

                GlassDivider()

                providerList
            }
        }
    }

    /// 供应商纵向列表（适配大量供应商）
    private var providerList: some View {
        ScrollView {
            LazyVStack(spacing: AppUI.Spacing.xs) {
                ForEach(remoteProviders) { provider in
                    ProviderButton(
                        provider: provider,
                        isSelected: selectedProviderId == provider.id
                    ) {
                        withAnimation(.easeInOut(duration: 0.2)) {
                            selectedProviderId = provider.id
                        }
                    }
                    .frame(maxWidth: .infinity, alignment: .leading)
                }
            }
            .padding(.vertical, AppUI.Spacing.xs)
        }
    }

    /// 配置卡片
    private var configurationCard: some View {
        GlassCard {
            VStack(alignment: .leading, spacing: AppUI.Spacing.xl) {
                // API Key 区块
                apiKeySection

                // 模型列表区块
                modelSection
            }
        }
    }

    /// API Key 配置区块
    private var apiKeySection: some View {
        VStack(alignment: .leading, spacing: AppUI.Spacing.md) {
            GlassSectionHeader(
                icon: "key.fill",
                title: "API 密钥",
                subtitle: "配置你的访问凭证"
            )

            GlassDivider()

            GlassRow {
                HStack(spacing: AppUI.Spacing.md) {
                    Image(systemName: "lock.fill")
                        .foregroundColor(AppUI.Color.semantic.warning)

                    TextField("输入 API Key", text: $apiKey)
                        .textFieldStyle(.plain)
                        .textContentType(.password)
                        .font(AppUI.Typography.body)
                        .foregroundColor(AppUI.Color.semantic.textPrimary)

                    Spacer()

                    if !apiKey.isEmpty {
                        Image(systemName: "checkmark.circle.fill")
                            .foregroundColor(AppUI.Color.semantic.success)
                    }
                }
            }
        }
    }

    /// 模型列表区块
    private var modelSection: some View {
        VStack(alignment: .leading, spacing: AppUI.Spacing.md) {
            GlassSectionHeader(
                icon: "cpu.fill",
                title: "可用模型",
                subtitle: "点击某个模型可设为默认"
            )

            GlassDivider()

            VStack(spacing: 0) {
                let models = selectedProvider?.availableModels ?? []
                ForEach(models, id: \.self) { model in
                    let capabilities = selectedProvider?.modelCapabilities[model]
                    RemoteModelRow(
                        model: model,
                        isDefault: selectedModel == model,
                        supportsVision: capabilities?.supportsVision,
                        supportsTools: capabilities?.supportsTools,
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

// MARK: - Actions

extension RemoteProviderSettingsView {
    /// 加载当前供应商的设置信息（API Key 和选中的模型）
    private func loadSettings() {
        guard let providerType = selectedProviderType else { return }
        let providerId = selectedProviderId
        isLoadingSettings = true
        let hasKey = APIKeyStore.shared.string(forKey: providerType.apiKeyStorageKey) != nil
        apiKey = APIKeyStore.shared.string(forKey: providerType.apiKeyStorageKey) ?? ""
        if Self.verbose {
            AppLogger.core.info("\(Self.t)加载设置 \(r("provider=\(providerId)"))，apiKey 已配置=\(hasKey)")
        }
        loadSelectedModel()
        // 延迟重置标志位，确保 onChange(of: apiKey) 不会在加载期间触发保存
        DispatchQueue.main.async {
            self.isLoadingSettings = false
        }
    }

    /// 保存 API Key 到 Keychain
    private func saveApiKey() {
        guard !isLoadingSettings else {
            if Self.verbose {
                AppLogger.core.info("\(Self.t)跳过保存（正在加载中）")
            }
            return
        }
        guard let providerType = selectedProviderType else { return }
        let providerId = selectedProviderId
        let keyLength = apiKey.count
        if Self.verbose {
            AppLogger.core.info("\(Self.t)保存 API Key \(r("provider=\(providerId)"))，长度=\(keyLength)")
        }
        APIKeyStore.shared.set(apiKey, forKey: providerType.apiKeyStorageKey)
    }

    /// 保存选中的模型到持久化存储
    private func saveModel() {
        guard selectedProviderId.isNotEmpty else { return }
        if Self.verbose {
            AppLogger.core.info("\(Self.t)保存模型 \(r("provider=\(selectedProviderId), model=\(selectedModel)"))")
        }
        AppSettingStore.saveRemoteProviderModel(providerId: selectedProviderId, modelId: selectedModel)
    }

    /// 保存选中的云端供应商 ID 到持久化存储
    private func saveSelectedProviderId(_ id: String) {
        if Self.verbose {
            AppLogger.core.info("\(Self.t)保存选中供应商 \(r("id=\(id)"))")
        }
        AppSettingStore.saveSelectedRemoteProviderId(id)
    }

    /// 加载上次选中的云端供应商 ID
    private func loadSelectedProviderId() {
        if let savedId = AppSettingStore.loadSelectedRemoteProviderId(),
           remoteProviders.contains(where: { $0.id == savedId }) {
            selectedProviderId = savedId
            if Self.verbose {
                AppLogger.core.info("\(Self.t)恢复选中供应商 \(r("id=\(savedId)"))")
            }
        } else if let firstProvider = remoteProviders.first {
            selectedProviderId = firstProvider.id
            if Self.verbose {
                AppLogger.core.info("\(Self.t)使用首个供应商 \(r("id=\(firstProvider.id)"))")
            }
        }
    }

    /// 加载当前选中的模型
    /// 优先级：用户配置 > 供应商默认 > 第一个可用模型
    private func loadSelectedModel() {
        guard selectedProviderId.isNotEmpty else { return }

        // 1. 优先使用用户配置的模型
        if let savedModel = AppSettingStore.loadRemoteProviderModel(providerId: selectedProviderId),
           selectedProvider?.availableModels.contains(savedModel) == true {
            selectedModel = savedModel
            if Self.verbose {
                AppLogger.core.info("\(Self.t)加载用户配置模型 \(r("model=\(savedModel)"))")
            }
        }
        // 2. 如果用户未配置，使用供应商默认模型
        else if let defaultModel = selectedProvider?.defaultModel {
            selectedModel = defaultModel
            if Self.verbose {
                AppLogger.core.info("\(Self.t)使用供应商默认模型 \(r("model=\(defaultModel)"))")
            }
        }
        // 3. 如果没有默认模型，使用第一个可用模型
        else if let firstModel = selectedProvider?.availableModels.first {
            selectedModel = firstModel
            if Self.verbose {
                AppLogger.core.info("\(Self.t)使用首个可用模型 \(r("model=\(firstModel)"))")
            }
        }
    }
}

// MARK: - Lifecycle

extension RemoteProviderSettingsView {
    /// 视图出现时的事件处理 - 加载仅云端供应商的设置
    func onAppear() {
        if Self.verbose {
            AppLogger.core.info("\(Self.a)")
        }
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
        .inRootView()
}
