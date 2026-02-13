import SwiftUI

/// 开发助手设置视图
/// 采用 macOS 系统设置风格，左侧为供应商选择，右侧为详细配置
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
        NavigationSplitView {
            // 左侧：供应商列表
            providerSidebar
        } detail: {
            // 右侧：详细配置
            providerDetailView
        }
        .navigationSplitViewColumnWidth(min: 180, ideal: 220)
        .onAppear {
            loadSettings()
        }
        .onChange(of: selectedProviderId) { _, _ in
            loadSettings()
        }
    }

    // MARK: - View Components

    /// 供应商侧边栏
    private var providerSidebar: some View {
        List(selection: $selectedProviderId) {
            Section("LLM 供应商") {
                ForEach(registry.allProviders()) { provider in
                    ProviderRow(
                        provider: provider,
                        isSelected: selectedProviderId == provider.id
                    )
                    .tag(provider.id)
                }
            }
        }
        .listStyle(.sidebar)
        .navigationTitle("开发助手")
    }

    /// 供应商详细配置视图
    private var providerDetailView: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: DesignTokens.Spacing.lg) {
                // 供应商头部信息
                providerHeader

                Divider()

                // API Key 配置
                apiKeySection

                Divider()

                // 模型选择
                modelSection

                Spacer()
            }
            .padding(DesignTokens.Spacing.lg)
        }
        .navigationTitle(selectedProvider?.displayName ?? "设置")
    }

    /// 供应商头部信息
    private var providerHeader: some View {
        HStack(spacing: DesignTokens.Spacing.md) {
            // 供应商图标
            Image(systemName: selectedProvider?.iconName ?? "dot.square")
                .font(.system(size: 32))
                .foregroundStyle(
                    LinearGradient(
                        colors: [DesignTokens.Color.semantic.primary, DesignTokens.Color.semantic.primarySecondary],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    )
                )
                .frame(width: 48, height: 48)
                .background(
                    RoundedRectangle(cornerRadius: 12)
                        .fill(DesignTokens.Color.semantic.primary.opacity(0.1))
                )

            VStack(alignment: .leading, spacing: 4) {
                // 供应商名称
                Text(selectedProvider?.displayName ?? "未知供应商")
                    .font(DesignTokens.Typography.title3)
                    .foregroundColor(DesignTokens.Color.semantic.textPrimary)

                // 供应商描述
                Text(selectedProvider?.description ?? "")
                    .font(DesignTokens.Typography.subheadline)
                    .foregroundColor(DesignTokens.Color.semantic.textSecondary)
            }

            Spacer()
        }
        .padding(.bottom, DesignTokens.Spacing.sm)
    }

    /// API Key 配置区域
    private var apiKeySection: some View {
        VStack(alignment: .leading, spacing: DesignTokens.Spacing.md) {
            // 区域标题
            Text("API 密钥")
                .font(DesignTokens.Typography.callout)
                .foregroundColor(DesignTokens.Color.semantic.textPrimary)

            // API Key 输入框
            HStack(spacing: DesignTokens.Spacing.sm) {
                Group {
                    if showApiKey {
                        TextField("输入 API Key", text: $apiKey)
                            .textFieldStyle(.plain)
                    } else {
                        TextField("输入 API Key", text: $apiKey)
                            .textFieldStyle(.plain)
                            .textContentType(.password)
                            .onSubmit {
                                saveApiKey()
                            }
                    }
                }
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
            // 区域标题
            Text("可用模型")
                .font(DesignTokens.Typography.callout)
                .foregroundColor(DesignTokens.Color.semantic.textPrimary)

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

// MARK: - Provider Row

/// 供应商列表行
private struct ProviderRow: View {
    let provider: ProviderInfo
    let isSelected: Bool

    var body: some View {
        HStack(spacing: DesignTokens.Spacing.sm) {
            // 供应商图标
            Image(systemName: provider.iconName)
                .font(.system(size: 14, weight: .medium))
                .foregroundStyle(
                    isSelected
                        ? AnyShapeStyle(
                            LinearGradient(
                                colors: [DesignTokens.Color.semantic.primary, DesignTokens.Color.semantic.primarySecondary],
                                startPoint: .topLeading,
                                endPoint: .bottomTrailing
                            )
                        )
                        : AnyShapeStyle(DesignTokens.Color.semantic.textSecondary)
                )
                .frame(width: 24)

            // 供应商名称
            Text(provider.displayName)
                .font(DesignTokens.Typography.body)
                .foregroundColor(isSelected ? DesignTokens.Color.semantic.textPrimary : DesignTokens.Color.semantic.textSecondary)

            Spacer()
        }
        .padding(.vertical, DesignTokens.Spacing.xs)
        .contentShape(Rectangle())
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
        .frame(width: 700, height: 500)
}

#Preview("App") {
    ContentLayout()
        .hideSidebar()
        .withNavigation(DevAssistantPlugin.navigationId)
        .inRootView()
        .withDebugBar()
}
