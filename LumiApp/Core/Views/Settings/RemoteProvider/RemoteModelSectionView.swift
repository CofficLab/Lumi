import SwiftUI

/// 远程供应商模型区块：API Key 配置 + 可用模型列表
struct RemoteModelSectionView: View {
    let selectedProvider: LLMProviderInfo?
    @Binding var selectedModel: String
    @Binding var apiKey: String
    let onSelectModel: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: AppUI.Spacing.md) {
            apiKeySection
            modelSection
        }
    }

    private var apiKeySection: some View {
        VStack(alignment: .leading, spacing: AppUI.Spacing.md) {
            Text("API 密钥")
                .font(AppUI.Typography.callout)
                .foregroundColor(AppUI.Color.semantic.textSecondary)

            TextField("输入 API Key", text: $apiKey)
                .textFieldStyle(.plain)
                .textContentType(.password)
                .font(AppUI.Typography.body)
                .padding(AppUI.Spacing.sm)
                .appSurface(
                    style: .glass,
                    cornerRadius: AppUI.Radius.sm,
                    borderColor: Color.white.opacity(0.1),
                    lineWidth: 1
                )
        }
    }

    private var modelSection: some View {
        VStack(alignment: .leading, spacing: AppUI.Spacing.md) {
            Text("可用模型")
                .font(AppUI.Typography.callout)
                .foregroundColor(AppUI.Color.semantic.textSecondary)

            VStack(spacing: AppUI.Spacing.xs) {
                let models = selectedProvider?.availableModels ?? []
                ForEach(models, id: \.self) { model in
                    ModelRow(
                        model: model,
                        isDefault: selectedModel == model,
                        isSelected: selectedModel == model
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
}
