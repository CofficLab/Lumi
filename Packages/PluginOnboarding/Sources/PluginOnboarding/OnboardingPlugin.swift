import KernelCore
import KitLLM
import LumiUI
import ProviderLLMManager
import ProviderOnboarding
import SwiftUI
import KitSuperLog
import os

/// First-run V2 onboarding contribution.
///
/// The host owns presentation so the same pages work in every V2 app; this
/// plugin owns only the user-facing welcome and AI setup content.
@MainActor
public final class OnboardingPlugin: SuperPlugin, SuperLog {
    nonisolated static let logger = Logger(subsystem: "com.coffic.lumi.plugin.onboarding", category: "Onboarding")
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
    @LumiTheme private var theme

    var body: some View {
        VStack(spacing: DesignTokens.Spacing.lg - 2) {
            Image(systemName: "sparkles")
                .font(.system(size: 56, weight: .semibold))
                .foregroundStyle(theme.primary)
            VStack(spacing: DesignTokens.Spacing.sm) {
                Text(LumiPluginLocalization.string("Welcome to Lumi", bundle: .module))
                    .font(DesignTokens.Typography.largeTitle)
                Text(LumiPluginLocalization.string("Your local workspace for focused AI conversations, projects, and tools.", bundle: .module))
                    .font(DesignTokens.Typography.body)
                    .multilineTextAlignment(.center)
                    .foregroundStyle(theme.textSecondary)
            }
            VStack(alignment: .leading, spacing: DesignTokens.Spacing.sm + 4) {
                feature("bubble.left.and.bubble.right", "Conversations", "Keep context, files, and preferences with every chat.")
                feature("folder", "Projects", "Connect conversations to the project you are working on.")
                feature("wrench.and.screwdriver", "Tools", "Use built-in skills and agent tools when you need them.")
            }
            .padding(DesignTokens.Spacing.md + 2)
            .background(
                RoundedRectangle(cornerRadius: DesignTokens.Radius.md - 2, style: .continuous)
                    .fill(theme.textSecondary.opacity(0.06))
            )
        }
        .frame(maxWidth: 520)
        .padding(.vertical, DesignTokens.Spacing.lg)
    }

    private func feature(_ symbol: String, _ title: String, _ detail: String) -> some View {
        HStack(alignment: .top, spacing: DesignTokens.Spacing.sm + 4) {
            Image(systemName: symbol)
                .foregroundStyle(theme.primary)
                .frame(width: 20)
            VStack(alignment: .leading, spacing: 2) {
                Text(title)
                    .font(DesignTokens.Typography.bodyEmphasized)
                Text(detail)
                    .font(DesignTokens.Typography.subheadline)
                    .foregroundStyle(theme.textSecondary)
            }
        }
    }
}

private struct AISetupPage: View {
    let manager: (any LLMManaging)?
    @LumiTheme private var theme
    @State private var selectedProviderID = ""
    @State private var apiKey = ""
    @State private var didSave = false

    private var providers: [any SuperLLMProvider] { manager?.allProviders() ?? [] }

    private var selectedProvider: (any SuperLLMProvider)? {
        manager?.provider(id: selectedProviderID)
    }

    var body: some View {
        VStack(alignment: .leading, spacing: DesignTokens.Spacing.lg) {
            Image(systemName: "brain.head.profile")
                .font(.system(size: 54))
                .foregroundStyle(theme.primary)
                .frame(maxWidth: .infinity)
            Text(LumiPluginLocalization.string("Set up your AI provider", bundle: .module))
                .font(DesignTokens.Typography.title2)
            Text(LumiPluginLocalization.string("Add a provider and choose a model in Settings. You can return here at any time from General Settings.", bundle: .module))
                .font(DesignTokens.Typography.body)
                .multilineTextAlignment(.center)
                .foregroundStyle(theme.textSecondary)

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
                        .font(DesignTokens.Typography.subheadline)
                        .foregroundStyle(theme.textSecondary)

                    if provider.providerInfo.isLocal {
                        Label(LumiPluginLocalization.string("This local provider does not require an API key.", bundle: .module), systemImage: "checkmark.circle")
                            .font(DesignTokens.Typography.subheadline)
                            .foregroundStyle(theme.textSecondary)
                    } else {
                        AppInputField(
                            LocalizedStringKey(LumiPluginLocalization.string("API Key", bundle: .module)),
                            text: $apiKey,
                            fieldType: .secure
                        )
                        if let website = provider.providerInfo.websiteURL {
                            Link(LumiPluginLocalization.string("Get a key", bundle: .module), destination: website)
                                .font(DesignTokens.Typography.subheadline)
                        }
                    }

                    AppButton(
                        provider.providerInfo.isLocal ? "Use Provider" : "Save API Key",
                        style: .primary,
                        action: {
                            provider.setApiKey(apiKey)
                            manager?.select(providerID: provider.providerID, model: nil)
                            apiKey = provider.getApiKey()
                            didSave = true
                        }
                    )
                    .disabled(!provider.providerInfo.isLocal && apiKey.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)

                    if didSave {
                        Label(LumiPluginLocalization.string("Saved", bundle: .module), systemImage: "checkmark.circle.fill")
                            .font(DesignTokens.Typography.subheadline)
                            .foregroundStyle(theme.success)
                    }
                }
            }
        }
        .frame(maxWidth: 460)
        .padding(.vertical, DesignTokens.Spacing.xxl - 4)
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
