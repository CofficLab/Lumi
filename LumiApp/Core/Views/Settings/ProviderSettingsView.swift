import SwiftUI

/// 供应商设置视图 - 配置 LLM 供应商的 API 密钥
struct ProviderSettingsView: View {
    // MARK: - State

    /// 当前选中的供应商 ID
    @State private var selectedProviderId: String = "anthropic"

    /// API Key 输入
    @State private var apiKey: String = ""

    /// 选中的模型
    @State private var selectedModel: String = ""

    // MARK: - Environment

    @Environment(\.colorScheme) private var colorScheme

    // MARK: - Dependencies

    @EnvironmentObject private var registry: ProviderRegistry

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
            saveApiKey()
        }
    }

    // MARK: - View Components

    /// 供应商选择器
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
                Text(selectedProvider?.displayName ?? "未知供应商")
                    .font(DesignTokens.Typography.callout)
                    .foregroundColor(DesignTokens.Color.semantic.textPrimary)

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
        }
    }

    /// 模型选择区域
    private var modelSection: some View {
        VStack(alignment: .leading, spacing: DesignTokens.Spacing.md) {
            Text("可用模型")
                .font(DesignTokens.Typography.callout)
                .foregroundColor(DesignTokens.Color.semantic.textSecondary)

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

    private func loadSettings() {
        guard let providerType = selectedProviderType else { return }

        apiKey = UserDefaults.standard.string(forKey: providerType.apiKeyStorageKey) ?? ""
        selectedModel = UserDefaults.standard.string(forKey: providerType.modelStorageKey)
            ?? providerType.defaultModel
    }

    private func saveApiKey() {
        guard let providerType = selectedProviderType else { return }
        UserDefaults.standard.set(apiKey, forKey: providerType.apiKeyStorageKey)
    }

    private func saveModel() {
        guard let providerType = selectedProviderType else { return }
        UserDefaults.standard.set(selectedModel, forKey: providerType.modelStorageKey)
    }
}

// MARK: - Provider Button

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

private struct ModelRow: View {
    let model: String
    let isDefault: Bool
    let isSelected: Bool
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            HStack(spacing: DesignTokens.Spacing.sm) {
                Image(systemName: isSelected ? "checkmark.circle.fill" : "circle")
                    .font(.system(size: 18))
                    .foregroundColor(isSelected ? DesignTokens.Color.semantic.primary : DesignTokens.Color.semantic.textTertiary)

                Text(model)
                    .font(DesignTokens.Typography.body)
                    .foregroundColor(DesignTokens.Color.semantic.textPrimary)

                Spacer()

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
    ProviderSettingsView()
        .frame(width: 500, height: 600)
        .inRootView()
}
