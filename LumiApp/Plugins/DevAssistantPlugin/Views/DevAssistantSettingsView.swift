import SwiftUI

/// 开发助手设置视图
/// 采用扁平化设计，避免嵌套侧边栏
struct DevAssistantSettingsView: View {
    // MARK: - State

    /// 当前选中的供应商 ID
    @State private var selectedProviderId: String = "anthropic"

    /// API Key 输入
    @State private var apiKey: String = ""

    /// 选中的模型
    @State private var selectedModel: String = ""

    /// 是否显示 API Key
    @State private var showApiKey: Bool = false

    /// 项目配置列表
    @State private var projectConfigs: [ProjectConfig] = []

    /// 选中的项目配置
    @State private var selectedProjectConfig: ProjectConfig?

    // MARK: - Environment

    /// 当前配色方案
    @Environment(\.colorScheme) private var colorScheme

    // MARK: - Dependencies

    private let registry = ProviderRegistry.shared
    private let configStore = ProjectConfigStore.shared

    // MARK: - Computed Properties

    /// 当前选中的供应商信息
    private var selectedProvider: ProviderInfo? {
        registry.allProviders().first(where: { $0.id == selectedProviderId })
    }

    /// 当前供应商类型
    private var selectedProviderType: (any LLMProviderProtocol.Type)? {
        registry.providerType(forId: selectedProviderId)
    }

    // MARK: - Body

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: DesignTokens.Spacing.xl) {
                // 全局默认配置
                globalConfigSection

                Divider()

                // 项目配置管理
                projectConfigSection

                Spacer()
            }
            .padding(DesignTokens.Spacing.lg)
        }
        .onAppear {
            loadSettings()
            loadProjectConfigs()
        }
        .onChange(of: selectedProviderId) { _, _ in
            loadSettings()
            saveProjectConfig()
        }
        .onChange(of: selectedModel) { _, _ in
            saveProjectConfig()
        }
        .onChange(of: apiKey) { _, _ in
            // 自动保存 API Key
            saveApiKey()
            saveProjectConfig()
        }
    }

    // MARK: - View Components

    /// 供应商选择器 - 使用分段控制器样式
    private var providerSelector: some View {
        VStack(alignment: .leading, spacing: DesignTokens.Spacing.sm) {
            Text("LLM 供应商")
                .font(DesignTokens.Typography.callout)
                .foregroundColor(DesignTokens.Color.semantic.textSecondary)

            HStack(spacing: DesignTokens.Spacing.sm) {
                ForEach(registry.allProviders()) { provider in
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

    /// 供应商信息卡片
    private var providerInfoCard: some View {
        HStack(spacing: DesignTokens.Spacing.md) {
            // 供应商图标
            Image(systemName: selectedProvider?.iconName ?? "dot.square")
                .font(.system(size: 28))
                .foregroundStyle(
                    LinearGradient(
                        colors: [DesignTokens.Color.semantic.primary, DesignTokens.Color.semantic.primarySecondary],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    )
                )
                .frame(width: 44, height: 44)
                .background(
                    RoundedRectangle(cornerRadius: 10)
                        .fill(DesignTokens.Color.semantic.primary.opacity(0.1))
                )

            VStack(alignment: .leading, spacing: 2) {
                // 供应商名称
                Text(selectedProvider?.displayName ?? "未知供应商")
                    .font(DesignTokens.Typography.callout)
                    .foregroundColor(DesignTokens.Color.semantic.textPrimary)

                // 供应商描述
                Text(selectedProvider?.description ?? "")
                    .font(DesignTokens.Typography.caption1)
                    .foregroundColor(DesignTokens.Color.semantic.textSecondary)
            }

            Spacer()
        }
        .padding(DesignTokens.Spacing.md)
        .background(
            RoundedRectangle(cornerRadius: DesignTokens.Radius.sm)
                .fill(DesignTokens.Material.glass)
                .overlay(
                    RoundedRectangle(cornerRadius: DesignTokens.Radius.sm)
                        .stroke(Color.white.opacity(0.1), lineWidth: 1)
                )
        )
    }

    /// API Key 配置区域
    private var apiKeySection: some View {
        VStack(alignment: .leading, spacing: DesignTokens.Spacing.md) {
            Text("API 密钥")
                .font(DesignTokens.Typography.callout)
                .foregroundColor(DesignTokens.Color.semantic.textSecondary)

            // API Key 输入框
            HStack(spacing: DesignTokens.Spacing.sm) {
                TextField("输入 API Key", text: $apiKey)
                    .textFieldStyle(.plain)
                    .textContentType(.password)
                    .font(DesignTokens.Typography.body)
                    .padding(DesignTokens.Spacing.sm)
                    .background(
                        RoundedRectangle(cornerRadius: DesignTokens.Radius.sm)
                            .fill(DesignTokens.Material.glass)
                            .overlay(
                                RoundedRectangle(cornerRadius: DesignTokens.Radius.sm)
                                    .stroke(Color.white.opacity(0.1), lineWidth: 1)
                            )
                    )

                // 显示/隐藏按钮
                Button(action: { showApiKey.toggle() }) {
                    Image(systemName: showApiKey ? "eye.slash.fill" : "eye.fill")
                        .font(.system(size: 14))
                        .foregroundColor(DesignTokens.Color.semantic.textSecondary)
                }
                .buttonStyle(.plain)
                .frame(width: 32, height: 32)
                .background(
                    RoundedRectangle(cornerRadius: 6)
                        .fill(DesignTokens.Material.glass)
                )
            }

            // 帮助文本
            Text("API Key 将安全存储在系统钥匙串中")
                .font(DesignTokens.Typography.caption1)
                .foregroundColor(DesignTokens.Color.semantic.textTertiary)
        }
    }

    /// 模型选择区域
    private var modelSection: some View {
        VStack(alignment: .leading, spacing: DesignTokens.Spacing.md) {
            Text("可用模型")
                .font(DesignTokens.Typography.callout)
                .foregroundColor(DesignTokens.Color.semantic.textSecondary)

            // 模型列表
            VStack(spacing: DesignTokens.Spacing.xs) {
                if let provider = selectedProvider {
                    ForEach(provider.availableModels, id: \.self) { model in
                        ModelRow(
                            model: model,
                            isDefault: model == provider.defaultModel,
                            isSelected: selectedModel == model
                        ) {
                            selectedModel = model
                            saveModel()
                        }
                    }
                }
            }
        }
    }

    // MARK: - Actions

    /// 加载设置
    private func loadSettings() {
        guard let providerType = selectedProviderType else {
            return
        }

        // 加载 API Key
        apiKey = UserDefaults.standard.string(forKey: providerType.apiKeyStorageKey) ?? ""

        // 加载选中的模型
        selectedModel = UserDefaults.standard.string(forKey: providerType.modelStorageKey)
            ?? providerType.defaultModel
    }

    /// 保存 API Key
    private func saveApiKey() {
        guard let providerType = selectedProviderType else {
            return
        }
        UserDefaults.standard.set(apiKey, forKey: providerType.apiKeyStorageKey)
    }

    /// 保存模型选择
    private func saveModel() {
        guard let providerType = selectedProviderType else {
            return
        }
        UserDefaults.standard.set(selectedModel, forKey: providerType.modelStorageKey)
    }

    /// 加载项目配置列表
    private func loadProjectConfigs() {
        projectConfigs = configStore.getAllConfigs()
    }

    /// 保存项目配置
    private func saveProjectConfig() {
        guard let projectConfig = selectedProjectConfig else {
            return
        }

        var updated = projectConfig
        updated.providerId = selectedProviderId
        updated.model = selectedModel

        configStore.saveConfig(updated)
        loadProjectConfigs()
    }

    /// 选择项目配置
    private func selectProjectConfig(_ config: ProjectConfig) {
        selectedProjectConfig = config
        selectedProviderId = config.providerId
        selectedModel = config.model
        loadSettings()
    }
}

// MARK: - View Components

extension DevAssistantSettingsView {
    /// 全局默认配置区域
    private var globalConfigSection: some View {
        VStack(alignment: .leading, spacing: DesignTokens.Spacing.lg) {
            Text("全局默认配置")
                .font(DesignTokens.Typography.callout)
                .foregroundColor(DesignTokens.Color.semantic.textSecondary)

            // 供应商选择器
            providerSelector

            // 供应商信息卡片
            providerInfoCard

            // API Key 配置
            apiKeySection

            // 模型选择
            modelSection
        }
    }

    /// 项目配置管理区域
    private var projectConfigSection: some View {
        VStack(alignment: .leading, spacing: DesignTokens.Spacing.lg) {
            Text("项目配置")
                .font(DesignTokens.Typography.callout)
                .foregroundColor(DesignTokens.Color.semantic.textSecondary)

            if projectConfigs.isEmpty {
                // 空状态
                VStack(spacing: DesignTokens.Spacing.md) {
                    Image(systemName: "folder.badge.questionmark")
                        .font(.system(size: 40))
                        .foregroundColor(DesignTokens.Color.semantic.textTertiary)
                    Text("暂无项目配置")
                        .font(DesignTokens.Typography.body)
                        .foregroundColor(DesignTokens.Color.semantic.textSecondary)
                    Text("打开项目后将自动创建配置")
                        .font(DesignTokens.Typography.caption1)
                        .foregroundColor(DesignTokens.Color.semantic.textTertiary)
                }
                .frame(maxWidth: .infinity)
                .padding(DesignTokens.Spacing.xl)
                .background(
                    RoundedRectangle(cornerRadius: DesignTokens.Radius.md)
                        .fill(Color.white.opacity(0.05))
                )
            } else {
                // 项目列表
                VStack(spacing: DesignTokens.Spacing.sm) {
                    ForEach(projectConfigs) { config in
                        ProjectConfigRow(
                            config: config,
                            isSelected: selectedProjectConfig?.id == config.id,
                            registry: registry
                        ) {
                            withAnimation(.easeInOut(duration: 0.2)) {
                                selectProjectConfig(config)
                            }
                        }
                    }
                }
            }
        }
    }
}

// MARK: - Provider Button

/// 供应商选择按钮
private struct ProviderButton: View {
    let provider: ProviderInfo
    let isSelected: Bool
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            HStack(spacing: 6) {
                Image(systemName: provider.iconName)
                    .font(.system(size: 12, weight: .medium))
                Text(provider.displayName)
                    .font(DesignTokens.Typography.caption1)
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 6)
            .background(
                RoundedRectangle(cornerRadius: 6)
                    .fill(isSelected ? DesignTokens.Color.semantic.primary : Color.white.opacity(0.05))
            )
            .foregroundColor(isSelected ? .white : DesignTokens.Color.semantic.textSecondary)
        }
        .buttonStyle(.plain)
    }
}

// MARK: - Model Row

/// 模型选择行
private struct ModelRow: View {
    let model: String
    let isDefault: Bool
    let isSelected: Bool
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            HStack(spacing: DesignTokens.Spacing.sm) {
                // 选择指示器
                Image(systemName: isSelected ? "checkmark.circle.fill" : "circle")
                    .font(.system(size: 18))
                    .foregroundColor(isSelected ? DesignTokens.Color.semantic.primary : DesignTokens.Color.semantic.textTertiary)

                // 模型名称
                Text(model)
                    .font(DesignTokens.Typography.body)
                    .foregroundColor(DesignTokens.Color.semantic.textPrimary)

                Spacer()

                // 默认标记
                if isDefault {
                    Text("默认")
                        .font(DesignTokens.Typography.caption2)
                        .fontWeight(.medium)
                        .padding(.horizontal, 8)
                        .padding(.vertical, 4)
                        .background(
                            RoundedRectangle(cornerRadius: 4)
                                .fill(DesignTokens.Color.semantic.primary.opacity(0.15))
                        )
                        .foregroundColor(DesignTokens.Color.semantic.primary)
                }
            }
            .padding(DesignTokens.Spacing.sm)
            .background(
                RoundedRectangle(cornerRadius: DesignTokens.Radius.sm)
                    .fill(isSelected ? DesignTokens.Color.semantic.primary.opacity(0.08) : Color.white.opacity(0.05))
                    .overlay(
                        RoundedRectangle(cornerRadius: DesignTokens.Radius.sm)
                            .stroke(
                                isSelected ? DesignTokens.Color.semantic.primary : Color.white.opacity(0.1),
                                lineWidth: isSelected ? 1.5 : 1
                            )
                    )
            )
        }
        .buttonStyle(.plain)
    }
}

// MARK: - Project Config Row

/// 项目配置行
private struct ProjectConfigRow: View {
    let config: ProjectConfig
    let isSelected: Bool
    let registry: ProviderRegistry
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            HStack(spacing: DesignTokens.Spacing.md) {
                // 项目图标
                Image(systemName: "folder.fill")
                    .font(.system(size: 16))
                    .foregroundColor(.accentColor)
                    .frame(width: 32, height: 32)
                    .background(
                        RoundedRectangle(cornerRadius: 8)
                            .fill(Color.accentColor.opacity(0.1))
                    )

                VStack(alignment: .leading, spacing: 2) {
                    // 项目名称
                    Text(config.projectName)
                        .font(DesignTokens.Typography.body)
                        .foregroundColor(DesignTokens.Color.semantic.textPrimary)

                    // 项目路径
                    Text(config.projectPath)
                        .font(DesignTokens.Typography.caption1)
                        .foregroundColor(DesignTokens.Color.semantic.textTertiary)
                        .lineLimit(1)
                        .truncationMode(.middle)

                    // 模型信息
                    if let provider = registry.allProviders().first(where: { $0.id == config.providerId }) {
                        HStack(spacing: 4) {
                            Text(provider.displayName)
                                .font(DesignTokens.Typography.caption2)
                                .foregroundColor(DesignTokens.Color.semantic.textSecondary)

                            Text("•")
                                .foregroundColor(DesignTokens.Color.semantic.textTertiary)

                            Text(config.model.isEmpty ? "使用默认" : config.model)
                                .font(DesignTokens.Typography.caption2)
                                .foregroundColor(DesignTokens.Color.semantic.textTertiary)
                        }
                    }
                }

                Spacer()

                // 选中指示器
                if isSelected {
                    Image(systemName: "checkmark.circle.fill")
                        .font(.system(size: 18))
                        .foregroundColor(DesignTokens.Color.semantic.primary)
                }
            }
            .padding(DesignTokens.Spacing.md)
            .background(
                RoundedRectangle(cornerRadius: DesignTokens.Radius.sm)
                    .fill(isSelected ? DesignTokens.Color.semantic.primary.opacity(0.08) : Color.white.opacity(0.05))
                    .overlay(
                        RoundedRectangle(cornerRadius: DesignTokens.Radius.sm)
                            .stroke(
                                isSelected ? DesignTokens.Color.semantic.primary : Color.white.opacity(0.1),
                                lineWidth: isSelected ? 1.5 : 1
                            )
                    )
            )
        }
        .buttonStyle(.plain)
    }
}

// MARK: - Preview

#Preview("Settings") {
    DevAssistantSettingsView()
        .frame(width: 500, height: 600)
}

#Preview("App") {
    ContentLayout()
        .hideSidebar()
        .withNavigation(DevAssistantPlugin.navigationId)
        .inRootView()
        .withDebugBar()
}
