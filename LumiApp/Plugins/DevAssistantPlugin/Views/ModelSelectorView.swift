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
            
            // List of Providers
            List {
                ForEach(LLMProvider.allCases) { provider in
                    Button(action: {
                        selectProvider(provider)
                    }) {
                        HStack {
                            VStack(alignment: .leading) {
                                Text(provider.rawValue)
                                    .font(.body)
                                Text(provider.defaultModel)
                                    .font(.caption)
                                    .foregroundColor(.secondary)
                            }
                            
                            Spacer()
                            
                            if viewModel.selectedProvider == provider {
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
            .listStyle(.sidebar)
        }
        .frame(width: 300, height: 300)
        .background(DesignTokens.Material.glass)
    }
    
    private func selectProvider(_ provider: LLMProvider) {
        viewModel.selectedProvider = provider
        dismiss()
    }
}

#Preview("App") {
    ContentLayout()
        .hideSidebar()
        .withNavigation(DevAssistantPlugin.navigationId)
        .inRootView()
        .withDebugBar()
}
