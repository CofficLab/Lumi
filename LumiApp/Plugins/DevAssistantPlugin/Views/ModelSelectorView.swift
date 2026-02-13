import SwiftUI

/// 模型选择器视图
///
/// 允许用户从所有已注册的供应商和模型中选择。
struct ModelSelectorView: View {
    @ObservedObject var viewModel: DevAssistantViewModel
    @Environment(\.dismiss) private var dismiss

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

    // MARK: - Section Header

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

    // MARK: - Actions

    private func selectModel(providerId: String, model: String) {
        viewModel.selectedProviderId = providerId
        viewModel.updateSelectedModel(model)
        dismiss()
    }

    // MARK: - Helpers

    private func isSelected(providerId: String, model: String) -> Bool {
        return viewModel.selectedProviderId == providerId && viewModel.currentModel == model
    }

    private func isDefaultModel(providerId: String, model: String) -> Bool {
        guard let providerType = registry.providerType(forId: providerId) else {
            return false
        }
        return model == providerType.defaultModel
    }
}

// MARK: - Preview

#Preview("ModelSelector") {
    ModelSelectorView(viewModel: DevAssistantViewModel())
}

#Preview("App") {
    ContentLayout()
        .hideSidebar()
        .withNavigation(DevAssistantPlugin.navigationId)
        .inRootView()
        .withDebugBar()
}
