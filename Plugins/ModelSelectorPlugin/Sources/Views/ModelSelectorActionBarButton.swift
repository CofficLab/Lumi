import LumiCoreLLMProvider
import LumiKernel
import LumiUI
import SwiftUI

/// Action Bar 上的模型选择按钮
struct ModelSelectorActionBarButton: View {
    @LumiTheme private var theme
    let llmProvider: any LLMProviderManaging

    var body: some View {
        let providers = llmProvider.allLLMProviders()

        HStack(spacing: 6) {
            Image(systemName: "globe")
                .font(.system(size: 13, weight: .medium))
            Text(providerLabel(providers: providers))
                .font(.system(size: 12, weight: .medium))
                .lineLimit(1)
                .truncationMode(.middle)
        }
        .foregroundColor(theme.textSecondary)
        .padding(.horizontal, 10)
        .padding(.vertical, 6)
        .background(
            RoundedRectangle(cornerRadius: 6, style: .continuous)
                .fill(theme.textTertiary.opacity(0.2))
        )
        .accessibilityLabel("Select Model")
    }

    private func providerLabel(providers: [any LumiLLMProvider]) -> String {
        guard let first = providers.first else {
            return "No Provider"
        }
        let info = type(of: first).info
        if let model = info.availableModels.first {
            let displayModel = info.modelDisplayNames[model] ?? model
            return "\(info.displayName) · \(displayModel)"
        }
        return info.displayName
    }
}
