import SwiftUI
import MagicKit

/// 供应商设置视图 - 配置 LLM 供应商的 API 密钥和模型选择
struct ProviderSettingsView: View, SuperLog {
    // MARK: - SuperLog

    nonisolated static let emoji = "⚙️"
    nonisolated static let verbose = false

    // MARK: - State

    /// 当前选中的供应商 ID
    @State private var selectedProviderId: String = "anthropic"
    
    /// API Key 输入
    @State private var apiKey: String = ""
    
    /// 选中的模型
    @State private var selectedModel: String = ""
    
    /// 选中的 Plan（仅对支持 Plan 的供应商生效，例如阿里云）
    @State private var selectedPlanId: String?

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
    private var selectedProviderType: (any SuperLLMProvider.Type)? {
        registry.providerType(forId: selectedProviderId)
    }
    
    /// 当前供应商可用的 Plan 列表
    private var availablePlans: [ProviderPlan] {
        registry.plans(forProviderId: selectedProviderId)
    }

    // MARK: - Body

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: DesignTokens.Spacing.xl) {
                // 供应商选择器
                providerSelector

                // 供应商信息卡片
                providerInfoCard
                
                // Plan 选择（仅对支持 Plan 的供应商显示）
                if !availablePlans.isEmpty {
                    planSection
                }

                // API Key 配置
                apiKeySection

                // 模型选择
                modelSection

                Spacer()
            }
            .padding(DesignTokens.Spacing.lg)
        }
        .onAppear(perform: onAppear)
        .onChange(of: selectedProviderId) { _, _ in
            loadSettings()
        }
        .onChange(of: apiKey) { _, _ in
            saveApiKey()
        }
    }
}

// MARK: - View

extension ProviderSettingsView {
    /// 供应商选择器 - 显示所有可用的 LLM 供应商按钮
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

    /// 供应商信息卡片 - 显示当前选中供应商的图标、名称和描述
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

    /// API Key 配置区域 - 提供文本输入框供用户输入 API 密钥
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

    /// 模型选择区域 - 显示当前供应商支持的所有可用模型
    private var modelSection: some View {
        VStack(alignment: .leading, spacing: DesignTokens.Spacing.md) {
            Text("可用模型")
                .font(DesignTokens.Typography.callout)
                .foregroundColor(DesignTokens.Color.semantic.textSecondary)

            VStack(spacing: DesignTokens.Spacing.xs) {
                let models: [String] = {
                    guard let provider = selectedProvider else { return [] }
                    if let planId = selectedPlanId,
                       let plan = availablePlans.first(where: { $0.id == planId }) {
                        return plan.availableModels
                    } else {
                        return provider.availableModels
                    }
                }()

                ForEach(models, id: \.self) { model in
                    ModelRow(
                        model: model,
                        isDefault: selectedModel == model,
                        isSelected: selectedModel == model
                    ) {
                        selectedModel = model
                        saveModel()
                    }
                }
            }
        }
    }

    /// Plan 选择区域 - 显示当前供应商支持的所有可用 Plan
    private var planSection: some View {
        VStack(alignment: .leading, spacing: DesignTokens.Spacing.md) {
            Text("Plan")
                .font(DesignTokens.Typography.callout)
                .foregroundColor(DesignTokens.Color.semantic.textSecondary)
            
            HStack(spacing: DesignTokens.Spacing.sm) {
                ForEach(availablePlans) { plan in
                    Button {
                        selectedPlanId = plan.id
                        savePlan()
                    } label: {
                        Text(plan.displayName)
                            .font(DesignTokens.Typography.caption1)
                            .padding(.horizontal, 12)
                            .padding(.vertical, 6)
                            .background(
                                RoundedRectangle(cornerRadius: 6)
                                    .fill(selectedPlanId == plan.id ? DesignTokens.Color.semantic.primary : Color.white.opacity(0.05))
                            )
                            .foregroundColor(selectedPlanId == plan.id ? .white : DesignTokens.Color.semantic.textSecondary)
                    }
                    .buttonStyle(.plain)
                }
            }
        }
    }
}

// MARK: - Action

extension ProviderSettingsView {
    /// 加载当前供应商的设置信息（API Key 和选中的模型）
    private func loadSettings() {
        guard let providerType = selectedProviderType else { return }

        apiKey = AppSettingsStore.shared.string(forKey: providerType.apiKeyStorageKey) ?? ""
        selectedModel = AppSettingsStore.shared.string(forKey: providerType.modelStorageKey)
            ?? providerType.defaultModel
        
        // 加载 Plan（仅对支持 Plan 的供应商生效）
        if !providerType.plans.isEmpty {
            let storageKey = "Agent_ProviderPlan_\(providerType.id)"
            let storedPlanId = AppSettingsStore.shared.string(forKey: storageKey)
            selectedPlanId = storedPlanId
        } else {
            selectedPlanId = nil
        }
    }

    /// 保存 API Key 到 UserDefaults
    private func saveApiKey() {
        guard let providerType = selectedProviderType else { return }
        AppSettingsStore.shared.set(apiKey, forKey: providerType.apiKeyStorageKey)
    }

    /// 保存选中的模型到 UserDefaults
    private func saveModel() {
        guard let providerType = selectedProviderType else { return }
        AppSettingsStore.shared.set(selectedModel, forKey: providerType.modelStorageKey)
    }
    
    /// 保存选中的 Plan 到 UserDefaults（仅对支持 Plan 的供应商生效）
    private func savePlan() {
        guard let providerType = selectedProviderType else { return }
        guard let planId = selectedPlanId else { return }
        guard !providerType.plans.isEmpty else { return }

        let storageKey = "Agent_ProviderPlan_\(providerType.id)"
        AppSettingsStore.shared.set(planId, forKey: storageKey)
    }
}

// MARK: - Event Handler

extension ProviderSettingsView {
    /// 视图出现时的事件处理 - 加载供应商设置
    func onAppear() {
        loadSettings()
    }
}

// MARK: - Provider Button

/// 供应商选择按钮组件
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

/// 模型选择行组件 - 支持 hover 效果和选中/默认状态高亮
private struct ModelRow: View {
    let model: String
    let isDefault: Bool
    let isSelected: Bool
    let action: () -> Void

    @State private var isHovered: Bool = false

    var body: some View {
        Button(action: action) {
            HStack(spacing: DesignTokens.Spacing.sm) {
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
                    .fill(isSelected ? DesignTokens.Color.semantic.primary.opacity(0.08) : isDefault ? DesignTokens.Color.semantic.primary.opacity(0.04) : isHovered ? Color.white.opacity(0.08) : Color.white.opacity(0.05))
                    .overlay(
                        RoundedRectangle(cornerRadius: DesignTokens.Radius.sm)
                            .stroke(
                                isSelected ? DesignTokens.Color.semantic.primary : isHovered ? DesignTokens.Color.semantic.primary.opacity(0.5) : isDefault ? DesignTokens.Color.semantic.primary.opacity(0.3) : Color.white.opacity(0.1),
                                lineWidth: isSelected ? 1.5 : 1
                            )
                    )
            )
        }
        .buttonStyle(.plain)
        .onHover { hovering in
            withAnimation(.easeInOut(duration: 0.15)) {
                isHovered = hovering
            }
        }
    }
}

// MARK: - Preview

#Preview("App - Small Screen") {
    ProviderSettingsView()
        .inRootView()
        .frame(width: 500)
        .frame(height: 600)
}

#Preview("App - Big Screen") {
    ProviderSettingsView()
        .inRootView()
        .frame(width: 1200)
        .frame(height: 1200)
}
