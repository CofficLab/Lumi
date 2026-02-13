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

    // MARK: - Environment

    /// 当前配色方案
    @Environment(\.colorScheme) private var colorScheme

    // MARK: - Dependencies

    private let registry = ProviderRegistry.shared

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
                // 供应商选择器
                providerSelector

                // 供应商信息卡片
                providerInfoCard

                // API Key 配置
                apiKeySection

                // 模型选择
                modelSection

                Spacer()
            }
            .padding(DesignTokens.Spacing.lg)
        }
        .onAppear {
            loadSettings()
        }
        .onChange(of: selectedProviderId) { _, _ in
            loadSettings()
        }
        .onChange(of: apiKey) { _, _ in
            // 自动保存 API Key
            saveApiKey()
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
