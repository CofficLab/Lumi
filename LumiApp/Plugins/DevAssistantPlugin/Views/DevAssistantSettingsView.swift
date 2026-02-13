import SwiftUI

struct DevAssistantSettingsView: View {
    @State private var selectedProviderId: String = "anthropic"
    @State private var apiKey: String = ""

    private let registry = ProviderRegistry.shared

    var body: some View {
        VStack(spacing: 0) {
            providerSelector
            Divider()
            settingsForm
        }
        .onAppear {
            loadApiKey()
        }
    }

    private var providerSelector: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 12) {
                ForEach(registry.allProviders()) { provider in
                    Button(action: {
                        selectedProviderId = provider.id
                    }) {
                        HStack(spacing: 6) {
                            Image(systemName: provider.iconName)
                                .font(.system(size: 14))
                            Text(provider.displayName)
                                .font(.caption)
                        }
                        .padding(.vertical, 8)
                        .padding(.horizontal, 12)
                        .background(
                            RoundedRectangle(cornerRadius: 8)
                                .fill(selectedProviderId == provider.id ? Color.accentColor.opacity(0.1) : Color.clear)
                        )
                    }
                    .buttonStyle(.plain)
                    .foregroundColor(selectedProviderId == provider.id ? .accentColor : .secondary)
                }
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 12)
        }
        .background(.ultraThinMaterial)
    }

    private var settingsForm: some View {
        Form {
            Section {
                TextField("API Key", text: $apiKey)
                    .textFieldStyle(.plain)

                if let provider = registry.allProviders().first(where: { $0.id == selectedProviderId }) {
                    Text("Available Models for \(provider.displayName)")
                        .font(.caption)
                        .foregroundColor(.secondary)

                    ForEach(provider.availableModels, id: \.self) { model in
                        HStack {
                            Text(model)
                                .font(.body)

                            Spacer()

                            if model == provider.defaultModel {
                                Text("Default")
                                    .font(.caption2)
                                    .padding(.horizontal, 6)
                                    .padding(.vertical, 2)
                                    .background(Color.accentColor.opacity(0.1))
                                    .foregroundColor(.accentColor)
                                    .cornerRadius(4)
                            }
                        }
                    }
                }
            }
        }
    }

    private func loadApiKey() {
        guard let providerType = registry.providerType(forId: selectedProviderId) else {
            return
        }
        apiKey = UserDefaults.standard.string(forKey: providerType.apiKeyStorageKey) ?? ""
    }
}

#Preview("Settings") {
    DevAssistantSettingsView()
        .frame(width: 400, height: 500)
}

#Preview("App") {
    ContentLayout()
        .hideSidebar()
        .withNavigation(DevAssistantPlugin.navigationId)
        .inRootView()
        .withDebugBar()
}
