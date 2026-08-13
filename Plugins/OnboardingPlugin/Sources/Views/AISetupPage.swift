import KernelLumi
import LumiUI
import SwiftUI

/// A compact first-run provider setup that uses the same provider and Keychain
/// APIs as the settings and retry UIs.
struct AISetupPage: View {
    let kernel: KernelLumi

    @State private var selectedProviderID = ""
    @State private var apiKey = ""
    @State private var saveError: String?
    @State private var didSave = false

    private var manager: (any LLMProviderManaging)? {
        kernel.resolveService((any LLMProviderManaging).self)
    }

    private var providers: [LumiLLMProviderInfo] {
        manager?.allLLMProviders().map { type(of: $0).info } ?? []
    }

    private var selectedProvider: (any LumiLLMProvider)? {
        manager?.llmProvider(id: selectedProviderID)
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 18) {
            PageHeader(
                icon: "key.fill",
                gradient: [.orange, .pink],
                title: OnboardingPageLocalization.string("Configure AI"),
                subtitle: OnboardingPageLocalization.string("Add a provider API key to start your first conversation. You can also do this later in Settings.")
            )

            if providers.isEmpty {
                Text(OnboardingPageLocalization.string("No providers are available yet. You can configure one later in Settings."))
                    .foregroundStyle(.secondary)
            } else {
                Picker(OnboardingPageLocalization.string("Provider"), selection: $selectedProviderID) {
                    ForEach(providers) { provider in
                        Text(provider.displayName).tag(provider.id)
                    }
                }
                .pickerStyle(.menu)
                .onChange(of: selectedProviderID) { _, _ in
                    apiKey = selectedProvider?.getApiKey() ?? ""
                    didSave = selectedProvider?.apiKeyDiagnostic() == .configured
                    saveError = nil
                }

                if let provider = selectedProvider, let info = providers.first(where: { $0.id == selectedProviderID }) {
                    Text(info.description)
                        .font(.subheadline)
                        .foregroundStyle(.secondary)

                    AppInputField(
                        LocalizedStringKey(OnboardingPageLocalization.string("API Key")),
                        text: $apiKey,
                        fieldType: .secure
                    )

                    HStack(spacing: 10) {
                        Button(OnboardingPageLocalization.string("Save API Key")) { save(provider) }
                            .buttonStyle(.borderedProminent)
                            .disabled(apiKey.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)

                        Link(OnboardingPageLocalization.string("Get a key"), destination: info.websiteURL)
                            .font(.subheadline)

                        if didSave {
                            Label(OnboardingPageLocalization.string("Saved"), systemImage: "checkmark.circle.fill")
                                .foregroundStyle(.green)
                                .font(.subheadline)
                        }
                    }
                }
            }

            if let saveError {
                Text(saveError)
                    .font(.caption)
                    .foregroundStyle(.red)
                    .textSelection(.enabled)
            }

            Spacer(minLength: 0)
        }
        .onAppear {
            guard selectedProviderID.isEmpty else { return }
            selectedProviderID = manager?.selectedProviderID ?? providers.first?.id ?? ""
            apiKey = selectedProvider?.getApiKey() ?? ""
            didSave = selectedProvider?.apiKeyDiagnostic() == .configured
        }
    }

    private func save(_ provider: any LumiLLMProvider) {
        do {
            try provider.saveAPIKey(apiKey)
            apiKey = provider.getApiKey()
            manager?.selectProvider(id: type(of: provider).info.id)
            didSave = true
            saveError = nil
        } catch {
            didSave = false
            saveError = error.localizedDescription
        }
    }
}
