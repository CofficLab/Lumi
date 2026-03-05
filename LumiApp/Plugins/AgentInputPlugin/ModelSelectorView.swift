import MagicKit
import OSLog
import SwiftUI

/// 模型选择器视图
/// 允许用户从所有已注册的供应商和模型中选择
struct ModelSelectorView: View, SuperLog {
    /// 日志标识 emoji
    nonisolated static let emoji = "🌐"
    /// 是否输出详细日志
    nonisolated static let verbose = false

    /// 环境对象：用于关闭当前视图
    @Environment(\.dismiss) private var dismiss

    /// 智能体提供者
    @EnvironmentObject var agentProvider: AgentProvider

    /// 供应商注册表：提供所有可用的模型供应商信息
    private let registry = ProviderRegistry.shared

    var body: some View {
        VStack(spacing: 0) {
            // Header
            HStack {
                Text("Select Model")
                    .font(.headline)
                Spacer()
                Button(action: { dismiss() }) {
                    Image(systemName: "xmark.circle.fill")
                        .foregroundColor(.secondary)
                }
                .buttonStyle(.plain)
            }
            .padding()
            .background(Color(nsColor: .controlBackgroundColor))

            Divider()

            // List of Providers and Models
            List {
                ForEach(registry.allProviders()) { provider in
                    Section(header: sectionHeader(for: provider)) {
                        ForEach(provider.availableModels, id: \.self) { model in
                            Button(action: {
                                selectModel(providerId: provider.id, model: model)
                            }) {
                                HStack {
                                    VStack(alignment: .leading) {
                                        Text(model)
                                            .font(.body)
                                        if isDefaultModel(providerId: provider.id, model: model) {
                                            Text("Default")
                                                .font(.caption)
                                                .foregroundColor(.secondary)
                                        }
                                    }

                                    Spacer()

                                    if isSelected(providerId: provider.id, model: model) {
                                        Image(systemName: "checkmark")
                                            .foregroundColor(.accentColor)
                                    }
                                }
                                .padding(.vertical, 4)
                                .contentShape(Rectangle())
                            }
                            .buttonStyle(.plain)
                        }
                    }
                }
            }
            .listStyle(.sidebar)
        }
        .frame(width: 350, height: 400)
        .background(DesignTokens.Material.glass)
    }
}

// MARK: - View

extension ModelSelectorView {
    /// 构建供应商分组头部视图
    /// - Parameter provider: 供应商信息
    /// - Returns: 包含供应商图标和名称的头部视图
    @ViewBuilder
    private func sectionHeader(for provider: ProviderInfo) -> some View {
        HStack {
            Image(systemName: provider.iconName)
                .foregroundColor(.secondary)
            Text(provider.displayName)
                .font(.headline)
                .foregroundColor(.primary)
            Spacer()
        }
        .padding(.vertical, 4)
    }
}

// MARK: - Action

extension ModelSelectorView {
    /// 选择模型并保存到项目配置
    /// - Parameters:
    ///   - providerId: 供应商 ID
    ///   - model: 模型名称
    private func selectModel(providerId: String, model: String) {
        agentProvider.setSelectedProviderId(providerId)
        agentProvider.setSelectedModel(model)

        // 保存到当前项目配置
        agentProvider.saveCurrentProjectConfig()

        dismiss()
    }
}

// MARK: - Helper

extension ModelSelectorView {
    /// 检查模型是否为当前选中状态
    /// - Parameters:
    ///   - providerId: 供应商 ID
    ///   - model: 模型名称
    /// - Returns: 是否为当前选中的模型
    private func isSelected(providerId: String, model: String) -> Bool {
        return agentProvider.selectedProviderId == providerId && agentProvider.currentModel == model
    }

    /// 检查模型是否为供应商的默认模型
    /// - Parameters:
    ///   - providerId: 供应商 ID
    ///   - model: 模型名称
    /// - Returns: 是否为默认模型
    private func isDefaultModel(providerId: String, model: String) -> Bool {
        guard let providerType = registry.providerType(forId: providerId) else {
            return false
        }
        return model == providerType.defaultModel
    }
}

// MARK: - Preview

#Preview("ModelSelector") {
    ModelSelectorView()
        .inRootView()
}
