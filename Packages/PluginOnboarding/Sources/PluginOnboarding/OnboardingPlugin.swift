import KernelCore
import KitLLM
import ProviderLLMManager
import ProviderOnboarding
import SwiftUI

/// First-run V2 onboarding contribution.
///
/// The host owns presentation so the same pages work in every V2 app; this
/// plugin owns only the user-facing welcome and AI setup content.
@MainActor
public final class OnboardingPlugin: SuperPlugin {
    public let id = "com.coffic.lumi.plugin.onboarding"
    public let order = 10
    public let metadata = PluginMetadata(
        id: "com.coffic.lumi.plugin.onboarding",
        name: "Onboarding",
        description: "First-run welcome and AI setup guide.",
        category: .system,
        stage: .stable,
        policy: .alwaysOn
    )

    public init() {}

    public func onBoot(kernel: KernelCoreContainer) throws {
        kernel.resolveProvider((any OnboardingProviding).self)?.register(
            OnboardingPageItem(id: "onboarding-welcome") { WelcomePage() }
        )
        kernel.resolveProvider((any OnboardingProviding).self)?.register(
            OnboardingPageItem(id: "onboarding-ai-setup") {
                AISetupPage(manager: kernel.resolveProvider((any LLMManaging).self))
            }
        )
    }

    public func onShutdown(kernel: KernelCoreContainer) throws {
        let onboarding = kernel.resolveProvider((any OnboardingProviding).self)
        onboarding?.unregister(id: "onboarding-welcome")
        onboarding?.unregister(id: "onboarding-ai-setup")
    }
}

private struct WelcomePage: View {
    var body: some View {
        VStack(spacing: 22) {
            Image(systemName: "sparkles")
                .font(.system(size: 56, weight: .semibold))
                .foregroundStyle(.tint)
            VStack(spacing: 8) {
                Text(LumiPluginLocalization.string("Welcome to Lumi", bundle: .module)).font(.largeTitle.weight(.bold))
                Text(LumiPluginLocalization.string("Your local workspace for focused AI conversations, projects, and tools.", bundle: .module))
                    .multilineTextAlignment(.center)
                    .foregroundStyle(.secondary)
            }
            VStack(alignment: .leading, spacing: 12) {
                feature("bubble.left.and.bubble.right", "Conversations", "Keep context, files, and preferences with every chat.")
                feature("folder", "Projects", "Connect conversations to the project you are working on.")
                feature("wrench.and.screwdriver", "Tools", "Use built-in skills and agent tools when you need them.")
            }
            .padding(18)
            .background(.quaternary, in: RoundedRectangle(cornerRadius: 14, style: .continuous))
        }
        .frame(maxWidth: 520)
        .padding(.vertical, 20)
    }

    private func feature(_ symbol: String, _ title: String, _ detail: String) -> some View {
        HStack(alignment: .top, spacing: 12) {
            Image(systemName: symbol).foregroundStyle(.tint).frame(width: 20)
            VStack(alignment: .leading, spacing: 2) {
                Text(title).font(.headline)
                Text(detail).font(.subheadline).foregroundStyle(.secondary)
            }
        }
    }
}

private struct AISetupPage: View {
    let manager: (any LLMManaging)?
    @State private var selectedProviderID = ""
    @State private var apiKey = ""
    @State private var didSave = false

    private var providers: [any SuperLLMProvider] { manager?.allProviders() ?? [] }

    private var selectedProvider: (any SuperLLMProvider)? {
        manager?.provider(id: selectedProviderID)
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 20) {
            Image(systemName: "brain.head.profile")
                .font(.system(size: 54))
                .foregroundStyle(.tint)
                .frame(maxWidth: .infinity)
            Text(LumiPluginLocalization.string("Set up your AI provider", bundle: .module)).font(.title.weight(.bold))
            Text(LumiPluginLocalization.string("Add a provider and choose a model in Settings. You can return here at any time from General Settings.", bundle: .module))
                .multilineTextAlignment(.center)
                .foregroundStyle(.secondary)

            if providers.isEmpty {
                ContentUnavailableView(
                    "No providers available",
                    systemImage: "network.slash",
                    description: Text(LumiPluginLocalization.string("You can configure a provider later in Settings.", bundle: .module))
                )
            } else {
                Picker(LumiPluginLocalization.string("Provider", bundle: .module), selection: $selectedProviderID) {
                    ForEach(providers, id: \.providerID) { provider in
                        Text(provider.providerInfo.displayName).tag(provider.providerID)
                    }
                }

                if let provider = selectedProvider {
                    Text(provider.providerInfo.description)
                        .font(.subheadline)
                        .foregroundStyle(.secondary)

                    if provider.providerInfo.isLocal {
                        Label(LumiPluginLocalization.string("This local provider does not require an API key.", bundle: .module), systemImage: "checkmark.circle")
                            .foregroundStyle(.secondary)
                    } else {
                        SecureField(LumiPluginLocalization.string("API Key", bundle: .module), text: $apiKey)
                            .textFieldStyle(.roundedBorder)
                        if let website = provider.providerInfo.websiteURL {
                            Link("Get a key", destination: website)
                        }
                    }

                    Button(provider.providerInfo.isLocal ? "Use Provider" : "Save API Key") {
                        provider.setApiKey(apiKey)
                        manager?.select(providerID: provider.providerID, model: nil)
                        apiKey = provider.getApiKey()
                        didSave = true
                    }
                    .buttonStyle(.borderedProminent)
                    .disabled(!provider.providerInfo.isLocal && apiKey.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)

                    if didSave {
                        Label(LumiPluginLocalization.string("Saved", bundle: .module), systemImage: "checkmark.circle.fill")
                            .font(.subheadline)
                            .foregroundStyle(.green)
                    }
                }
            }
        }
        .frame(maxWidth: 460)
        .padding(.vertical, 46)
        .onAppear { synchronizeSelection() }
        .onChange(of: selectedProviderID) { _, _ in
            apiKey = selectedProvider?.getApiKey() ?? ""
            didSave = selectedProvider?.hasApiKey() ?? false
        }
    }

    private func synchronizeSelection() {
        guard selectedProviderID.isEmpty else { return }
        selectedProviderID = manager?.selectedProviderID ?? providers.first?.providerID ?? ""
        apiKey = selectedProvider?.getApiKey() ?? ""
        didSave = selectedProvider?.hasApiKey() ?? false
    }
}
