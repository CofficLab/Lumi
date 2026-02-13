import SwiftUI

struct ModelSelectorView: View {
    @ObservedObject var viewModel: DevAssistantViewModel
    @Environment(\.dismiss) private var dismiss
    
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
                ForEach(LLMProvider.allCases) { provider in
                    Section(header: 
                        HStack {
                            Text(provider.rawValue)
                                .font(.headline)
                                .foregroundColor(.primary)
                            Spacer()
                        }
                        .padding(.vertical, 4)
                    ) {
                        ForEach(provider.availableModels, id: \.self) { model in
                            Button(action: {
                                selectModel(provider: provider, model: model)
                            }) {
                                HStack {
                                    VStack(alignment: .leading) {
                                        Text(model)
                                            .font(.body)
                                        if model == provider.defaultModel {
                                            Text("Default")
                                                .font(.caption)
                                                .foregroundColor(.secondary)
                                        }
                                    }
                                    
                                    Spacer()
                                    
                                    if isSelected(provider: provider, model: model) {
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
    
    private func selectModel(provider: LLMProvider, model: String) {
        viewModel.selectedProvider = provider
        viewModel.updateSelectedModel(model, for: provider)
        dismiss()
    }
    
    private func isSelected(provider: LLMProvider, model: String) -> Bool {
        // Check if this is the currently active provider and model
        return viewModel.selectedProvider == provider && viewModel.currentModel == model
    }
}

#Preview("App") {
    ContentLayout()
        .hideSidebar()
        .withNavigation(DevAssistantPlugin.navigationId)
        .inRootView()
        .withDebugBar()
}
