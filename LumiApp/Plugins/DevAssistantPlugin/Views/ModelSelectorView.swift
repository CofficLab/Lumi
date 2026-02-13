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
            
            // List of Models
            List {
                ForEach(LLMProvider.allCases) { provider in
                    Section(header: Text(provider.rawValue).font(.subheadline).bold()) {
                        ForEach(provider.availableModels, id: \.self) { model in
                            Button(action: {
                                selectModel(provider: provider, model: model)
                            }) {
                                HStack {
                                    VStack(alignment: .leading) {
                                        Text(model)
                                            .font(.body)
                                        if isSelected(provider: provider, model: model) {
                                            Text("Current")
                                                .font(.caption)
                                                .foregroundColor(.secondary)
                                        }
                                    }
                                    
                                    Spacer()
                                    
                                    if isSelected(provider: provider, model: model) {
                                        Image(systemName: "checkmark")
                                            .foregroundColor(.blue)
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
        .frame(width: 300, height: 400)
        .background(DesignTokens.Material.glass)
    }
    
    private func isSelected(provider: LLMProvider, model: String) -> Bool {
        return viewModel.selectedProvider == provider && viewModel.currentModel == model
    }
    
    private func selectModel(provider: LLMProvider, model: String) {
        viewModel.selectedProvider = provider
        viewModel.currentModel = model
        dismiss()
    }
}

#Preview("App") {
    ContentLayout()
        .hideSidebar()
        .hideTabPicker()
        .withNavigation(DevAssistantPlugin.navigationId)
        .inRootView()
        .withDebugBar()
}
