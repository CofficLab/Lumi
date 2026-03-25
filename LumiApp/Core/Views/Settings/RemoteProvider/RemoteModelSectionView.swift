import SwiftUI

/// 远程供应商模型区块：API Key 配置 + 可用模型列表（带性能指标）
struct RemoteModelSectionView: View {
    let selectedProvider: LLMProviderInfo?
    @Binding var selectedModel: String
    @Binding var apiKey: String
    let onSelectModel: () -> Void
    
    /// 模型性能统计数据
    @State private var detailedStats: [String: ModelPerformanceStats] = [:]
    
    /// 环境对象用于获取性能统计
    @EnvironmentObject private var chatHistoryVM: ChatHistoryVM

    var body: some View {
        VStack(alignment: .leading, spacing: DesignTokens.Spacing.md) {
            apiKeySection
            modelSection
        }
        .onAppear {
            loadLatencyStats()
        }
    }

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

    private var modelSection: some View {
        VStack(alignment: .leading, spacing: DesignTokens.Spacing.md) {
            Text("可用模型")
                .font(DesignTokens.Typography.callout)
                .foregroundColor(DesignTokens.Color.semantic.textSecondary)

            VStack(spacing: DesignTokens.Spacing.xs) {
                let models = selectedProvider?.availableModels ?? []
                ForEach(models, id: \.self) { model in
                    let stats = findStat(for: model)
                    ModelRow(
                        model: model,
                        isDefault: selectedModel == model,
                        isSelected: selectedModel == model,
                        performanceStats: stats
                    ) {
                        selectedModel = model
                        onSelectModel()
                    }
                    .transition(.opacity.combined(with: .move(edge: .top)))
                }
            }
            .animation(.easeInOut(duration: 0.22), value: selectedProvider?.id ?? "")
        }
    }
    
    /// 加载性能统计数据
    private func loadLatencyStats() {
        detailedStats = chatHistoryVM.getModelDetailedStats()
    }
    
    /// 查找指定模型的性能统计
    private func findStat(for modelName: String) -> ModelPerformanceStats? {
        guard let provider = selectedProvider else { return nil }
        let key = "\(provider.id)|\(modelName)"
        return detailedStats[key]
    }
}