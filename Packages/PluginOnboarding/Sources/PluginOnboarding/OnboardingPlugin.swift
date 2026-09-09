import Foundation
import KernelCore
import KitLLM
import KitSuperLog
import LumiUI
import ProviderLLMManager
import ProviderOnboarding
import ProviderRootView
import ProviderStorage
import SwiftUI
import os

/// First-run onboarding contribution.
///
/// The plugin owns the complete onboarding feature: it creates the page
/// provider, contributes the root overlay, and persists completion in its own
/// storage directory. Hosts only need to assemble the root view.
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

    private static let overlayID = "com.coffic.lumi.plugin.onboarding.overlay"
    private static let showNotification = Notification.Name("Onboarding.Show")

    private var onboardingProvider: DefaultOnboardingProviding?
    private var seenStore: OnboardingSeenStore?
    private var showNotificationObserver: NSObjectProtocol?

    public init() {}

    public func onBoot(kernel: KernelCoreContainer) throws {
        guard let rootView = kernel.resolveProvider((any RootViewProviding).self) else {
            throw KernelCoreError.providerNotRegistered(type: (any RootViewProviding).self)
        }
        guard let storage = kernel.resolveProvider((any StorageProviding).self) else {
            throw KernelCoreError.providerNotRegistered(type: (any StorageProviding).self)
        }

        let provider = DefaultOnboardingProviding()
        try kernel.registerProvider((any OnboardingProviding).self, provider)

        let store = OnboardingSeenStore(directory: storage.pluginDataDirectory(for: id))
        onboardingProvider = provider
        seenStore = store

        provider.register(
            OnboardingPageItem(id: "onboarding-welcome") { WelcomePage() }
        )
        provider.register(
            OnboardingPageItem(id: "onboarding-ai-setup") {
                AISetupPage(manager: kernel.resolveProvider((any LLMManaging).self))
            }
        )

        let finish: @MainActor () -> Void = { [weak provider, weak store] in
            store?.markSeen()
            provider?.dismiss()
        }
        rootView.addOverlays([
            RootOverlayItem(id: Self.overlayID, order: Int.max) { content in
                OnboardingOverlay(
                    provider: provider,
                    content: content,
                    finish: finish
                )
            }
        ])

        showNotificationObserver = NotificationCenter.default.addObserver(
            forName: Self.showNotification,
            object: nil,
            queue: .main
        ) { [weak self] notification in
            let shouldReset = notification.userInfo?["reset"] as? Bool == true
            Task { @MainActor [weak self] in
                self?.handleShowNotification(reset: shouldReset)
            }
        }

        if !store.hasSeen {
            provider.show()
        }
    }

    public func onShutdown(kernel: KernelCoreContainer) throws {
        if let rootView = kernel.resolveProvider((any RootViewProviding).self) {
            rootView.removeOverlays(ids: [Self.overlayID])
        }
        removeShowNotificationObserver()
        onboardingProvider?.dismiss()
        onboardingProvider?.unregister(id: "onboarding-welcome")
        onboardingProvider?.unregister(id: "onboarding-ai-setup")
        kernel.unregisterProvider((any OnboardingProviding).self)
        onboardingProvider = nil
        seenStore = nil
    }

    public func onUnregister(kernel: KernelCoreContainer) throws {
        removeShowNotificationObserver()
    }

    private func handleShowNotification(reset: Bool) {
        if reset {
            seenStore?.reset()
        }
        guard let provider = onboardingProvider, !provider.allPages.isEmpty else { return }
        provider.show()
    }

    private func removeShowNotificationObserver() {
        if let showNotificationObserver {
            NotificationCenter.default.removeObserver(showNotificationObserver)
            self.showNotificationObserver = nil
        }
    }
}

@MainActor
final class OnboardingSeenStore {
    private let markerURL: URL

    init(directory: URL) {
        try? FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        markerURL = directory.appendingPathComponent("completed", isDirectory: false)
    }

    var hasSeen: Bool {
        FileManager.default.fileExists(atPath: markerURL.path)
    }

    func markSeen() {
        do {
            try Data("completed".utf8).write(to: markerURL, options: .atomic)
        } catch {
            OnboardingPlugin.logger.error(
                "Failed to persist onboarding completion: \(error.localizedDescription, privacy: .public)"
            )
        }
    }

    func reset() {
        do {
            try FileManager.default.removeItem(at: markerURL)
        } catch CocoaError.fileNoSuchFile {
            // The marker is already absent.
        } catch {
            OnboardingPlugin.logger.error(
                "Failed to reset onboarding completion: \(error.localizedDescription, privacy: .public)"
            )
        }
    }
}

private struct OnboardingOverlay: View {
    @ObservedObject var provider: DefaultOnboardingProviding
    let content: AnyView
    let finish: @MainActor () -> Void
    @State private var pageIndex = 0

    var body: some View {
        ZStack {
            content

            if provider.isPresented, !provider.allPages.isEmpty {
                Color.black.opacity(0.22)
                    .ignoresSafeArea()
                OnboardingCard(
                    pages: provider.allPages,
                    index: $pageIndex,
                    finish: finish
                )
            }
        }
        .onChange(of: provider.isPresented) { _, isPresented in
            if isPresented {
                pageIndex = 0
            }
        }
    }
}

private struct OnboardingCard: View {
    let pages: [OnboardingPageItem]
    @Binding var index: Int
    let finish: @MainActor () -> Void

    @LumiTheme private var theme

    var body: some View {
        let safeIndex = min(max(index, 0), max(pages.count - 1, 0))
        VStack(spacing: 0) {
            HStack {
                Label(
                    LumiPluginLocalization.string("Getting started", bundle: .module),
                    systemImage: "graduationcap.fill"
                )
                .font(DesignTokens.Typography.bodyEmphasized)
                .foregroundStyle(theme.textSecondary)
                Spacer()
                Text(
                    String(
                        format: LumiPluginLocalization.string("%lld of %lld", bundle: .module),
                        Int64(safeIndex + 1),
                        Int64(pages.count)
                    )
                )
                .font(DesignTokens.Typography.caption1)
                .foregroundStyle(theme.textTertiary)
                AppButton(
                    LumiPluginLocalization.string("Skip", bundle: .module),
                    style: .tonal,
                    size: .small,
                    action: finish
                )
            }
            .padding(.horizontal, DesignTokens.Spacing.lg)
            .padding(.vertical, DesignTokens.Spacing.md + 4)

            Divider()

            if pages.indices.contains(safeIndex) {
                ScrollView {
                    pages[safeIndex].makeView()
                        .padding(DesignTokens.Spacing.xl)
                }
            }

            Divider()

            HStack {
                AppButton(
                    LumiPluginLocalization.string("Back", bundle: .module),
                    systemImage: "chevron.left",
                    style: .ghost,
                    size: .small,
                    action: { index = max(0, safeIndex - 1) }
                )
                .disabled(safeIndex == 0)

                Spacer()

                AppButton(
                    safeIndex == pages.count - 1
                        ? LumiPluginLocalization.string("Finish", bundle: .module)
                        : LumiPluginLocalization.string("Continue", bundle: .module),
                    systemImage: safeIndex == pages.count - 1 ? nil : "chevron.right",
                    style: .primary,
                    action: {
                        if safeIndex == pages.count - 1 {
                            finish()
                        } else {
                            index = safeIndex + 1
                        }
                    }
                )
            }
            .padding(.horizontal, DesignTokens.Spacing.lg)
            .padding(.vertical, DesignTokens.Spacing.md + 4)
        }
        .frame(width: 640, height: 550)
        .background(theme.background)
        .clipShape(RoundedRectangle(cornerRadius: DesignTokens.Radius.lg))
        .shadow(radius: 24)
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
        }
        .frame(maxWidth: 520)
        .padding(.vertical, DesignTokens.Spacing.lg)
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
                    LumiPluginLocalization.string("No providers available", bundle: .module),
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
                        LumiPluginLocalization.string(
                            provider.providerInfo.isLocal ? "Use Provider" : "Save API Key",
                            bundle: .module
                        ),
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
