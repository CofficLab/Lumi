import SwiftUI
import LLMKit
import LumiUI

/// 远程供应商模型区块：API Key 配置 + 可用模型列表
struct RemoteModelSectionView: View {
    let selectedProvider: LLMProviderInfo?
    @Binding var selectedModel: String
    @Binding var apiKey: String
    let onSelectModel: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            apiKeySection
            modelSection
        }
    }

    private var apiKeySection: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("API 密钥")
                .font(.system(size: 16, weight: .medium))
                .foregroundColor(Color.adaptive(light: "6B6B7B", dark: "EBEBF5"))

            TextField("输入 API Key", text: $apiKey)
                .textFieldStyle(.plain)
                .textContentType(.password)
                .font(.system(size: 15, weight: .regular))
                .padding(8)
                .appSurface(
                    style: .glass,
                    cornerRadius: 8,
                    borderColor: Color.white.opacity(0.1),
                    lineWidth: 1
                )
        }
    }

    private var modelSection: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("可用模型")
                .font(.system(size: 16, weight: .medium))
                .foregroundColor(Color.adaptive(light: "6B6B7B", dark: "EBEBF5"))

            VStack(spacing: 4) {
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
