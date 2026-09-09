import Foundation
import KernelCore
import KitSuperLog
import LumiUI
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
    private var onboardingProvider: DefaultOnboardingProviding?
    private var seenStore: OnboardingSeenStore?

    public init() {}

    public func onBoot(kernel: KernelCoreContainer) throws {
        guard let rootView = kernel.resolveProvider((any RootViewProviding).self) else {
            throw KernelCoreError.providerNotRegistered(type: (any RootViewProviding).self)
        }
        guard let storage = kernel.resolveProvider((any StorageProviding).self) else {
            throw KernelCoreError.providerNotRegistered(type: (any StorageProviding).self)
        }

        let store = OnboardingSeenStore(directory: storage.pluginDataDirectory(for: id))
        let provider = DefaultOnboardingProviding(onReplay: { [weak store] in
            store?.reset()
        })
        try kernel.registerProvider((any OnboardingProviding).self, provider)

        onboardingProvider = provider
        seenStore = store

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

        if !store.hasSeen {
            provider.show()
        }
    }

    public func onShutdown(kernel: KernelCoreContainer) throws {
        if let rootView = kernel.resolveProvider((any RootViewProviding).self) {
            rootView.removeOverlays(ids: [Self.overlayID])
        }
        onboardingProvider?.dismiss()
        kernel.unregisterProvider((any OnboardingProviding).self)
        onboardingProvider = nil
        seenStore = nil
    }

    public func onUnregister(kernel: KernelCoreContainer) throws {}
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
    let provider: DefaultOnboardingProviding
    let content: AnyView
    let finish: @MainActor () -> Void
    @State private var pageIndex = 0
    @State private var isPresented = false
    @State private var pageCount = 0
    @State private var observerHandle: (any OnboardingObserverHandle)?

    var body: some View {
        ZStack {
            content

            if isPresented, pageCount > 0 {
                Color.black.opacity(0.22)
                    .ignoresSafeArea()
                OnboardingCard(
                    pages: provider.allPages,
                    index: $pageIndex,
                    finish: finish
                )
            }
        }
        .onAppear {
            guard observerHandle == nil else { return }
            isPresented = provider.isPresented
            pageCount = provider.allPages.count
            observerHandle = provider.addObserver { event in
                switch event {
                case .pagesChanged:
                    pageCount = provider.allPages.count
                case let .presentationChanged(presented):
                    isPresented = presented
                    if presented {
                        pageIndex = 0
                    }
                }
            }
        }
        .onDisappear {
            observerHandle?.cancel()
            observerHandle = nil
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
